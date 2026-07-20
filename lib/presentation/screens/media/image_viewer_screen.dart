import 'package:flutter/material.dart';
import 'dart:io';

// =====================================================================
// FITUR: Penampil Gambar Tunggal
// FILE: lib/presentation/screens/media/image_viewer_screen.dart
// BARIS AWAL: 7 (setelah komentar ini)
// FUNGSI: Menampilkan satu gambar secara layar penuh (fullscreen) dengan dukungan zoom dan caption.
// =====================================================================
class ImageViewerScreen extends StatelessWidget {
  final String? imageUrl;
  final String? caption;

  const ImageViewerScreen({Key? key, required this.imageUrl, this.caption}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Image Viewer'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: InteractiveViewer(
                child: (imageUrl != null && imageUrl!.startsWith('http'))
                    ? Image.network(
                        imageUrl!,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 100,
                        ),
                      )
                    : (imageUrl != null && imageUrl!.isNotEmpty) 
                        ? Image.file(
                            File(imageUrl!),
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 100,
                            ),
                          )
                        : const Icon(Icons.broken_image, color: Colors.white, size: 100),
              ),
            ),
            if (caption != null && caption!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black54,
                width: double.infinity,
                child: Text(
                  caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
