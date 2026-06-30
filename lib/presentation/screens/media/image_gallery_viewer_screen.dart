import 'package:flutter/material.dart';

class ImageGalleryItem {
  final String imageUrl;
  final String? caption;
  final DateTime? timestamp;

  ImageGalleryItem({
    required this.imageUrl,
    this.caption,
    this.timestamp,
  });
}

// =====================================================================
// FITUR: Penampil Galeri Gambar
// FILE: lib/presentation/screens/media/image_gallery_viewer_screen.dart
// BARIS AWAL: 19 (setelah komentar ini)
// FUNGSI: Menampilkan beberapa gambar secara interaktif (bisa digeser/swipe dan di-zoom), dilengkapi dengan caption.
// =====================================================================
class ImageGalleryViewerScreen extends StatefulWidget {
  final List<ImageGalleryItem> images;
  final int initialIndex;

  const ImageGalleryViewerScreen({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ImageGalleryViewerScreen> createState() => _ImageGalleryViewerScreenState();
}

class _ImageGalleryViewerScreenState extends State<ImageGalleryViewerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gallery Viewer'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final item = widget.images[index];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(
                    item.imageUrl,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),
              ),
              if (item.caption != null && item.caption!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  width: double.infinity,
                  child: Text(
                    item.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
