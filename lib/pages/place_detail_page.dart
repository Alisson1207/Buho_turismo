import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceDetailPage extends StatefulWidget {
  final Map<String, dynamic> place;
  final String role;

  const PlaceDetailPage({super.key, required this.place, required this.role});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<String> _imageUrls = [];
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;

  final TextEditingController _newReviewController = TextEditingController();
  int _newReviewRating = 5;

  String? _mapsUrl;
  String? _coordsText;
  bool _isOwner = false;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadReviews();
    _loadLocationData();
    _checkOwnership();
  }

  @override
  void dispose() {
    _newReviewController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _checkOwnership() {
    final currentUser = _supabase.auth.currentUser;
    final ownerId = widget.place['user_id'];
    if (currentUser != null && currentUser.id == ownerId) {
      setState(() {
        _isOwner = true;
      });
    }
  }

  void _loadLocationData() {
    _mapsUrl = widget.place['maps_url'] as String?;
    final locationRaw = widget.place['location'] as String?;
    if (locationRaw != null &&
        locationRaw.startsWith('POINT(') &&
        locationRaw.endsWith(')')) {
      final coords = locationRaw.substring(6, locationRaw.length - 1).split(' ');
      if (coords.length == 2) {
        final lon = coords[0];
        final lat = coords[1];
        _coordsText = 'Lat: $lat, Lon: $lon';
        if (_mapsUrl == null) {
          _mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
        }
      }
    }
  }

  Future<void> _openMap() async {
    if (_mapsUrl == null) return;
    final uri = Uri.parse(_mapsUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  Future<void> _loadImages() async {
    final placeId = widget.place['id'];
    try {
      final List<dynamic> data = await _supabase
          .from('place_images')
          .select('image_url')
          .eq('place_id', placeId);

      setState(() {
        _imageUrls = List<String>.from(data.map((e) => e['image_url']));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar imágenes: $e')),
      );
    }
  }

  Future<void> _loadReviews() async {
    final placeId = widget.place['id'];
    setState(() => _reviewsLoading = true);
    try {
      final List<dynamic> data = await _supabase
          .from('reviews')
          .select()
          .eq('site_id', placeId)
          .order('created_at', ascending: true);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data);
        _reviewsLoading = false;
      });
    } catch (e) {
      setState(() => _reviewsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reseñas: $e')),
      );
    }
  }

  Future<void> _addReview({
    required dynamic siteId,
    required String content,
    required int rating,
    String? parentId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('reviews').insert({
        'site_id': siteId,
        'user_id': user.id,
        'author_name': user.email ?? 'Usuario',
        'content': content,
        'rating': rating,
        'parent_review_id': parentId,
        'created_at': DateTime.now().toIso8601String(),
      });
      _newReviewController.clear();
      await _loadReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reseña enviada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar reseña: $e')),
      );
    }
  }

  Future<void> _editReview(int id, String newContent, int newRating) async {
    try {
      await _supabase
          .from('reviews')
          .update({'content': newContent, 'rating': newRating})
          .eq('id', id);
      await _loadReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reseña actualizada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al editar reseña: $e')),
      );
    }
  }

  Future<void> _deleteReview(int id) async {
    try {
      await _supabase.from('reviews').delete().eq('id', id);
      await _loadReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reseña eliminada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar reseña: $e')),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> review) {
    final TextEditingController editController =
        TextEditingController(text: review['content']);
    int rating = review['rating'] ?? 5;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Editar reseña'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Tu reseña'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Calificación:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: rating,
                      items: List.generate(5, (index) => index + 1)
                          .map((val) => DropdownMenuItem(
                                value: val,
                                child: Text(val.toString()),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => rating = val);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('Guardar'),
                onPressed: () async {
                  final newContent = editController.text.trim();
                  if (newContent.isNotEmpty) {
                    await _editReview(review['id'], newContent, rating);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReplyDialog({required String parentReviewId}) {
    final TextEditingController replyController = TextEditingController();
    int replyRating = 5;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder reseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: replyController,
              decoration: const InputDecoration(hintText: 'Escribe tu respuesta'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Calificación:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: replyRating,
                  items: List.generate(5, (index) => index + 1).map((val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text(val.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => replyRating = val);
                    }
                  },
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = replyController.text.trim();
              if (content.isNotEmpty) {
                await _addReview(
                  siteId: widget.place['id'],
                  content: content,
                  rating: replyRating,
                  parentId: parentReviewId,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlace() async {
    try {
      await _supabase.from('places').delete().eq('id', widget.place['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sitio eliminado correctamente.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar sitio: $e')),
      );
    }
  }

  void _editPlace() {
    final TextEditingController titleCtrl =
        TextEditingController(text: widget.place['title']);
    final TextEditingController descCtrl =
        TextEditingController(text: widget.place['description']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar sitio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              try {
                await _supabase.from('places').update({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                }).eq('id', widget.place['id']);
                Navigator.pop(context);
                setState(() {
                  widget.place['title'] = titleCtrl.text.trim();
                  widget.place['description'] = descCtrl.text.trim();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sitio actualizado.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al editar sitio: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating) {
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 18);
        }
      }),
    );
  }

  Widget _buildReviewItem(
      Map<String, dynamic> review, List<Map<String, dynamic>> allReviews) {
    final replies =
        allReviews.where((r) => r['parent_review_id'] == review['id']).toList();
    final user = _supabase.auth.currentUser;
    final isOwnReview = user != null && review['user_id'] == user.id;
    final rating = review['rating'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review['author_name'] ?? 'Anónimo',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(review['content']),
            const SizedBox(height: 8),
            _buildStars(rating),
            if (widget.role == 'publicador')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isOwnReview) ...[
                    TextButton(
                      child: const Text('Editar'),
                      onPressed: () => _showEditDialog(review),
                    ),
                    TextButton(
                      child: const Text('Eliminar'),
                      onPressed: () => _deleteReview(review['id']),
                    ),
                  ],
                  TextButton(
                    child: const Text('Responder'),
                    onPressed: () =>
                        _showReplyDialog(parentReviewId: review['id'].toString()),
                  ),
                ],
              ),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children:
                      replies.map((r) => _buildReviewItem(r, allReviews)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _previousImage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _nextImage() {
    if (_currentPage < _imageUrls.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          place['title'] ?? 'Detalle del Sitio',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white), // flecha volver blanca
        actions: _isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar sitio',
                  onPressed: _editPlace,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar sitio',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar eliminación'),
                        content: const Text('¿Deseas eliminar este sitio?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await _deletePlace();
                  },
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_imageUrls.isEmpty)
                    const Text('No hay imágenes disponibles')
                  else
                    SizedBox(
                      height: 280,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _imageUrls.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _imageUrls[index],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image, size: 50),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Flechas izquierda/derecha
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 4,
                            child: Center(
                              child: IconButton(
                                iconSize: 36,
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
                                onPressed: _currentPage > 0 ? _previousImage : null,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 4,
                            child: Center(
                              child: IconButton(
                                iconSize: 36,
                                icon: const Icon(Icons.arrow_forward_ios, color: Colors.black54),
                                onPressed: _currentPage < _imageUrls.length - 1 ? _nextImage : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    place['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    place['description'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (_coordsText != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _coordsText!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.map),
                          color: Colors.blue.shade700,
                          tooltip: 'Abrir ubicación en Google Maps',
                          onPressed: _mapsUrl != null ? _openMap : null,
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (widget.role == 'publicador') ...[
                    Text(
                      'Escribe una nueva reseña:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newReviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: 'Tu opinión...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Calificación:'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _newReviewRating,
                          items: List.generate(5, (index) => index + 1).map((val) {
                            return DropdownMenuItem<int>(
                              value: val,
                              child: Text(val.toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _newReviewRating = val;
                              });
                            }
                          },
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            final content = _newReviewController.text.trim();
                            if (content.isEmpty) return;

                            await _addReview(
                              siteId: widget.place['id'],
                              content: content,
                              rating: _newReviewRating,
                            );
                          },
                          child: const Text('Enviar reseña'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  _reviewsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reseñas:',
                                style: Theme.of(context).textTheme.titleMedium),
                            if (_reviews.isEmpty)
                              const Text('No hay reseñas aún.'),
                            ..._reviews
                                .where((r) => r['parent_review_id'] == null)
                                .map((review) => _buildReviewItem(review, _reviews))
                                .toList(),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}
