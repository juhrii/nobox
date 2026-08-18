import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// =====================================================================
// FITUR: Authenticated Avatar Widget
// FILE: lib/presentation/widgets/authenticated_avatar.dart
// FUNGSI: Menampilkan foto profil dari server NoBox yang membutuhkan
//         header Authorization (Bearer Token) untuk bisa diakses.
//         Menggantikan CachedNetworkImage biasa yang tidak bisa mengirim token.
// =====================================================================

/// Custom FileService yang mengirimkan Bearer Token ke setiap request gambar.
class AuthFileService extends FileService {
  final String token;
  AuthFileService(this.token);

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final mergedHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      ...?headers,
    };
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri);
    request.headers.addAll(mergedHeaders);
    final streamedResponse = await request.send();
    return HttpGetResponse(streamedResponse);
  }
}

/// Custom CacheManager yang menggunakan AuthFileService.
class AuthenticatedCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'authenticatedCache';

  AuthenticatedCacheManager(String token)
      : super(Config(
          key,
          fileService: AuthFileService(token),
        ));
}

/// Widget foto profil yang secara otomatis menambahkan token Auth.
/// Digunakan untuk menampilkan avatar kontak dari server NoBox yang terproteksi.
class AuthenticatedAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isGroup;

  const AuthenticatedAvatar({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.isGroup = false,
  });

  @override
  State<AuthenticatedAvatar> createState() => _AuthenticatedAvatarState();
}

class _AuthenticatedAvatarState extends State<AuthenticatedAvatar> {
  static const _storage = FlutterSecureStorage();
  AuthenticatedCacheManager? _cacheManager;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCacheManager();
  }

  Future<void> _initCacheManager() async {
    final token = await _storage.read(key: 'auth_token') ?? '';
    if (mounted) {
      setState(() {
        _cacheManager = AuthenticatedCacheManager(token);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      widget.isGroup ? Icons.groups : Icons.person,
      color: Colors.grey.shade600,
      size: widget.size * 0.58,
    );

    final emptyAvatar = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: Colors.grey.shade300,
        child: iconWidget,
      ),
    );

    if (_isLoading || _cacheManager == null) return emptyAvatar;
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return emptyAvatar;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        cacheManager: _cacheManager,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: widget.size,
          height: widget.size,
          color: Colors.grey.shade300,
          child: iconWidget,
        ),
        errorWidget: (context, url, error) {
          debugPrint('AuthenticatedAvatar Error for $url: $error');
          return Container(
            width: widget.size,
            height: widget.size,
            color: Colors.grey.shade300,
            child: iconWidget,
          );
        },
      ),
    );
  }
}
