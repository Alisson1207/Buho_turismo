import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<XFile> _imageFiles = [];
  List<Uint8List> _webImages = [];

  Position? _locationData;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _loading = false;

  List<String> _uploadedImageUrls = [];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      if (kIsWeb) {
        _webImages.clear();
        for (var file in pickedFiles) {
          final bytes = await file.readAsBytes();
          _webImages.add(bytes);
        }
      }

      setState(() {
        _imageFiles = pickedFiles;
      });
    }
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
        const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente.')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _locationData = position;
    });
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

    if (_locationData == null) {
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
        'location':
            'POINT(${_locationData!.longitude} ${_locationData!.latitude})',
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final placeId = placeInsert['id'];

      for (int i = 0; i < _imageFiles.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final bytes = await _imageFiles[i].readAsBytes();

        await _supabase.storage
            .from('place-photos')
            .uploadBinary(fileName, bytes,
                fileOptions: FileOptions(contentType: 'image/jpeg'));

        final publicUrl = _supabase.storage.from('place-photos').getPublicUrl(fileName);


        await _supabase.from('place_images').insert({
          'place_id': placeId,
          'image_url': publicUrl,
        });

        _uploadedImageUrls.add(publicUrl);
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sitio agregado correctamente.')),
      );

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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildUploadedImages() {
    if (_uploadedImageUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _uploadedImageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Image.network(
              _uploadedImageUrls[index],
              width: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 50),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Sitio'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade900),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: _imageFiles.isEmpty
                    ? const Center(
                        child: Icon(Icons.camera_alt,
                            size: 50, color: Colors.blue),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: kIsWeb
                                ? Image.memory(_webImages[index], fit: BoxFit.cover)
                                : Image.file(File(_imageFiles[index].path), fit: BoxFit.cover),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _locationData == null
                      ? const Text('Ubicación no obtenida')
                      : Text(
                          'Lat: ${_locationData!.latitude.toStringAsFixed(5)}, '
                          'Lon: ${_locationData!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.location_on),
                  label: const Text('Obtener ubicación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                  ),
                  onPressed: _getLocation,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _savePlace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1361),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Sitio',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _buildUploadedImages(),
          ],
        ),
      ),
    );
  }
}
