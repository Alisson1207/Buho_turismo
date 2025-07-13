import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<XFile> _imageFiles = [];
  List<Uint8List> _webImages = [];
  List<String> _uploadedImageUrls = [];

  Position? _locationData;
  String? _googleMapsUrl;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _loading = false;

  static const int minWidth = 1024;
  static const int minHeight = 768;

  Future<bool> _checkImageResolution(XFile file) async {
    try {
      Uint8List bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return false;
      return decodedImage.width >= minWidth && decodedImage.height >= minHeight;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isEmpty) return;

    if (pickedFiles.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes subir hasta 5 imágenes.')),
      );
      return;
    }

    List<XFile> validFiles = [];
    List<Uint8List> validWebImages = [];

    for (var file in pickedFiles) {
      bool isValid = await _checkImageResolution(file);
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'La imagen ${file.name} no cumple la resolución mínima de $minWidth x $minHeight px.'),
          ),
        );
        continue; // no agregues esta imagen
      }
      validFiles.add(file);
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        validWebImages.add(bytes);
      }
    }

    if (validFiles.isEmpty) {
      // Ninguna imagen válida seleccionada
      return;
    }

    setState(() {
      _imageFiles = validFiles;
      if (kIsWeb) {
        _webImages = validWebImages;
      }
    });
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa los servicios de ubicación.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicación denegado permanentemente.')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lon = position.longitude;
      final url = Uri.encodeFull('https://www.google.com/maps/search/?api=1&query=$lat,$lon');

      setState(() {
        _locationData = position;
        _googleMapsUrl = url;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }

  Future<void> _openMap() async {
    if (_googleMapsUrl == null) return;
    final uri = Uri.parse(_googleMapsUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  Future<void> _savePlace() async {
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona al menos una imagen.')),
      );
      return;
    }

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa título y descripción.')),
      );
      return;
    }

    if (_locationData == null || _googleMapsUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obtén la ubicación primero.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _uploadedImageUrls = [];
    });

    try {
      final userId = _supabase.auth.currentUser?.id;

      final placeInsert = await _supabase.from('places').insert({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': 'POINT(${_locationData!.longitude} ${_locationData!.latitude})',
        'maps_url': _googleMapsUrl,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final placeId = placeInsert['id'];

      for (int i = 0; i < _imageFiles.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final bytes = await _imageFiles[i].readAsBytes();

        await _supabase.storage
            .from('place-photos')
            .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/jpeg'));

        final publicUrl = _supabase.storage.from('place-photos').getPublicUrl(fileName);

        await _supabase.from('place_images').insert({
          'place_id': placeId,
          'image_url': publicUrl,
        });

        _uploadedImageUrls.add(publicUrl);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sitio agregado correctamente.')),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agregar Sitio',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona hasta 5 imágenes (mínimo 1024 x 768 px)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade900),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFiles.isEmpty
                    ? const Center(
                        child: Icon(Icons.add_photo_alternate, size: 50, color: Colors.blue),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: kIsWeb
                                  ? Image.memory(_webImages[index],
                                      width: 130, height: 160, fit: BoxFit.cover)
                                  : Image.file(
                                      File(_imageFiles[index].path),
                                      width: 130,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descripción',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade900),
                color: Colors.blue.shade50,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _locationData == null
                        ? const Text('Ubicación no obtenida',
                            style: TextStyle(color: Colors.black54))
                        : Text(
                            'Lat: ${_locationData!.latitude.toStringAsFixed(5)}\nLon: ${_locationData!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map),
                    tooltip: 'Abrir en Google Maps',
                    color: _googleMapsUrl != null ? Colors.blue : Colors.grey,
                    onPressed: _googleMapsUrl != null ? _openMap : null,
                  ),
                  ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Ubicación'),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.pressed)) return Colors.white;
                        return const Color(0xFF1A237E);
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return const Color(0xFF1A237E);
                        }
                        return Colors.white;
                      }),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _savePlace,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.pressed)) return Colors.white;
                    return const Color(0xFF0D1361);
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return const Color(0xFF0D1361);
                    }
                    return Colors.white;
                  }),
                  padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16)),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Sitio',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
