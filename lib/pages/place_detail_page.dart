// ...imports
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceDetailPage extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceDetailPage({super.key, required this.place});

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<String> _imageUrls = [];
  bool _loading = true;

  // Reseñas
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;

  final TextEditingController _newReviewController = TextEditingController();
  int _newReviewRating = 5;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadReviews();
  }

  Future<void> _loadImages() async {
    final placeId = widget.place['id'];
    try {
      final response = await _supabase
          .from('place_images')
          .select('image_url')
          .eq('place_id', placeId);

      if (response != null && response is List) {
        setState(() {
          _imageUrls = List<String>.from(response.map((e) => e['image_url']));
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar imágenes: $e')),
      );
    }
  }

  Future<void> _loadReviews() async {
    final placeId = widget.place['id'];
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .eq('site_id', placeId)
          .order('created_at', ascending: true);

      if (response != null && response is List) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response);
          _reviewsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _reviewsLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reseñas: $e')),
      );
    }
  }

  Future<void> _addReview({
    required String siteId, // <- CORREGIDO: antes era int
    required String content,
    required int rating,
    String? parentId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para comentar')),
      );
      return;
    }

    await _supabase.from('reviews').insert({
      'site_id': siteId,
      'user_id': user.id,
      'author_name': user.email ?? 'Usuario',
      'content': content,
      'rating': rating,
      'parent_review_id': parentId,
    });

    _newReviewController.clear();
    await _loadReviews();
    setState(() {});
  }

  @override
  void dispose() {
    _newReviewController.dispose();
    super.dispose();
  }

  Widget _buildReviewItem(Map<String, dynamic> review, List<Map<String, dynamic>> allReviews) {
    final replies = allReviews.where((r) => r['parent_review_id'] == review['id']).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review['author_name'] ?? 'Anonimo', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(review['content']),
            const SizedBox(height: 4),
            Text('⭐ ${review['rating']}', style: const TextStyle(color: Colors.amber)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: const Text('Responder'),
                  onPressed: () {
                    _showReplyDialog(parentReviewId: review['id']);
                  },
                ),
              ],
            ),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: replies.map((r) => _buildReviewItem(r, allReviews)).toList(),
                ),
              ),
          ],
        ),
      ),
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
                      replyRating = val;
                      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      appBar: AppBar(
        title: Text(place['title'] ?? 'Detalle del Sitio'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageUrls.isEmpty
                      ? const Text('No hay imágenes disponibles')
                      : SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  _imageUrls[index],
                                  width: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 50),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 16),
                  Text(
                    place['title'] ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(place['description'] ?? ''),
                  const SizedBox(height: 24),

                  // FORMULARIO de reseña
                  Text('Escribe una nueva reseña:', style: Theme.of(context).textTheme.titleLarge),
                  TextField(
                    controller: _newReviewController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Tu opinión...',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          _newReviewController.clear();
                        },
                        child: const Text('Enviar reseña'),
                      )
                    ],
                  ),

                  const SizedBox(height: 24),
                  _reviewsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reseñas:', style: Theme.of(context).textTheme.titleMedium),
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
