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
  bool _loadingImages = true;

  List<Map<String, dynamic>> _reviews = [];
  Map<int, List<Map<String, dynamic>>> _replies = {};
  bool _loadingReviews = true;

  // Controla qué reseña está en modo responder (mostrar campo)
  Set<int> _replyingReviewIds = {};

  final Map<int, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadReviewsAndReplies();
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
          _loadingImages = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar imágenes: $e')),
      );
    }
  }

  Future<void> _loadReviewsAndReplies() async {
    setState(() {
      _loadingReviews = true;
    });

    final placeId = widget.place['id'];

    try {
      final reviewsResponse = await _supabase
          .from('reviews')
          .select()
          .eq('site_id', placeId)
          .is_('parent_review_id', null)
          .order('created_at', ascending: false);

      if (reviewsResponse != null && reviewsResponse is List) {
        _reviews = List<Map<String, dynamic>>.from(reviewsResponse);
        _replies.clear();
        _replyControllers.clear();

        for (var review in _reviews) {
          final reviewId = review['id'];

          final repliesResponse = await _supabase
              .from('reviews')
              .select()
              .eq('parent_review_id', reviewId)
              .order('created_at', ascending: true);

          _replies[reviewId] = repliesResponse != null
              ? List<Map<String, dynamic>>.from(repliesResponse)
              : [];

          _replyControllers[reviewId] = TextEditingController();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reseñas: $e')),
      );
    }

    setState(() {
      _loadingReviews = false;
    });
  }

  Future<void> _submitReply(int reviewId) async {
    final controller = _replyControllers[reviewId];
    final replyText = controller?.text.trim() ?? '';
    final userId = _supabase.auth.currentUser?.id;
    final placeId = widget.place['id'];

    if (replyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una respuesta antes de enviar')),
      );
      return;
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para responder')),
      );
      return;
    }

    try {
      await _supabase.from('reviews').insert({
        'site_id': placeId,
        'user_id': userId,
        'content': replyText,
        'created_at': DateTime.now().toIso8601String(),
        'author_name': 'Tu Nombre', // ajusta según tu lógica
        'parent_review_id': reviewId,
        'rating': null,
      });

      controller?.clear();

      final updatedRepliesResponse = await _supabase
          .from('reviews')
          .select()
          .eq('parent_review_id', reviewId)
          .order('created_at', ascending: true);

      setState(() {
        _replies[reviewId] = updatedRepliesResponse != null
            ? List<Map<String, dynamic>>.from(updatedRepliesResponse)
            : [];
        _replyingReviewIds.remove(reviewId); // oculta campo después de enviar
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando respuesta: $e')),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      appBar: AppBar(
        title: Text(place['title'] ?? 'Detalle del Sitio'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loadingImages
                ? const Center(child: CircularProgressIndicator())
                : _imageUrls.isEmpty
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
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(place['description'] ?? ''),
            const SizedBox(height: 24),
            _loadingReviews
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reseñas',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_reviews.isEmpty)
                        const Text('No hay reseñas para este sitio.'),
                      ..._reviews.map((review) {
                        final reviewId = review['id'];
                        final repliesForReview = _replies[reviewId] ?? [];
                        final isReplying = _replyingReviewIds.contains(reviewId);

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review['author_name'] ?? 'Anónimo',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(
                                    (review['rating'] ?? 0),
                                    (_) => const Icon(Icons.star,
                                        color: Colors.orange, size: 16),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  review['content'] ?? '',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Publicado: ${review['created_at'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const Divider(height: 16),

                                // Respuestas
                                ...repliesForReview.map((reply) => Padding(
                                      padding: const EdgeInsets.only(
                                          left: 12, bottom: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reply['author_name'] ?? 'Anónimo',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            reply['content'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic),
                                          ),
                                          Text(
                                            'Respondido: ${reply['created_at'] ?? ''}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    )),

                                // Botón para mostrar/ocultar el campo de respuesta
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      if (isReplying) {
                                        _replyingReviewIds.remove(reviewId);
                                      } else {
                                        _replyingReviewIds.add(reviewId);
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    isReplying
                                        ? Icons.close
                                        : Icons.reply,
                                  ),
                                  label: Text(
                                      isReplying ? 'Cancelar' : 'Responder'),
                                ),

                                // Campo para escribir respuesta (solo si está activo)
                                if (isReplying) ...[
                                  TextField(
                                    controller: _replyControllers[reviewId],
                                    decoration: const InputDecoration(
                                      labelText: 'Tu respuesta',
                                      border: OutlineInputBorder(),
                                    ),
                                    minLines: 1,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () => _submitReply(reviewId),
                                      child: const Text('Enviar respuesta'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
