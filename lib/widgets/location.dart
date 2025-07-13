import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationInput extends StatefulWidget {
  final Function(double, double, String) onLocationPicked;

  const LocationInput({super.key, required this.onLocationPicked});

  @override
  State<LocationInput> createState() => _LocationInputState();
}

class _LocationInputState extends State<LocationInput> {
  String _locationMessage = 'Ubicación no obtenida';
  String? _googleMapsUrl;
  bool _loading = false;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _loading = true;
      _locationMessage = 'Obteniendo ubicación...';
      _googleMapsUrl = null;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Servicios de ubicación desactivados.';
        _loading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Permiso de ubicación denegado.';
          _loading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage =
            'Permiso de ubicación denegado permanentemente. Actívalo en configuración.';
        _loading = false;
      });
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
        _locationMessage = 'Lat: $lat, Lon: $lon';
        _googleMapsUrl = url;
        _loading = false;
      });

      widget.onLocationPicked(lat, lon, url);
    } catch (e) {
      setState(() {
        _locationMessage = 'Error al obtener ubicación: $e';
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _locationMessage,
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.location_on),
                  color: Colors.blue[800],
                  onPressed: _loading ? null : _getCurrentLocation,
                  tooltip: 'Obtener ubicación actual',
                ),
                IconButton(
                  icon: const Icon(Icons.map),
                  color: _googleMapsUrl != null ? Colors.blue[800] : Colors.grey,
                  onPressed: _googleMapsUrl != null ? _openMap : null,
                  tooltip: 'Abrir en Google Maps',
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
