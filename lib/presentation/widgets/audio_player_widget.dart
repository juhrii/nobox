import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';

// =====================================================================
// FITUR: Komponen Pemutar Audio (Voice Note)
// FILE: lib/presentation/widgets/audio_player_widget.dart
// FUNGSI: Menampilkan pemutar audio khusus untuk Voice Note dalam balon chat,
//         lengkap dengan progress bar dan indikator durasi berjalan/total (0:00 / 0:03).
// =====================================================================
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final String? caption;
  final Duration? initialDuration;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.caption,
    this.initialDuration,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  static final Map<String, Duration> _durationCache = {};
  static _AudioPlayerWidgetState? _activePlayer;

  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;
  String? _localFilePath; // Cache downloaded file path

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();

    // 1. Ambil durasi awal dari message model atau cache statis
    if (widget.initialDuration != null && widget.initialDuration! > Duration.zero) {
      _duration = widget.initialDuration!;
      _durationCache[widget.audioUrl] = widget.initialDuration!;
    } else if (_durationCache.containsKey(widget.audioUrl)) {
      _duration = _durationCache[widget.audioUrl]!;
    }

    // 2. Preload durasi di background jika belum diketahui
    if (_duration == Duration.zero) {
      _preloadDuration();
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDuration != null &&
        widget.initialDuration! > Duration.zero &&
        _duration == Duration.zero) {
      setState(() {
        _duration = widget.initialDuration!;
        _durationCache[widget.audioUrl] = widget.initialDuration!;
      });
    }
    if (widget.audioUrl != oldWidget.audioUrl) {
      if (_durationCache.containsKey(widget.audioUrl)) {
        _duration = _durationCache[widget.audioUrl]!;
      } else {
        _duration = widget.initialDuration ?? Duration.zero;
        if (_duration == Duration.zero) {
          _preloadDuration();
        }
      }
    }
  }

  @override
  void dispose() {
    if (_activePlayer == this) {
      _activePlayer = null;
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _position == Duration.zero;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted && duration > Duration.zero) {
        _durationCache[widget.audioUrl] = duration;
        setState(() {
          _duration = duration;
        });
      }
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          _position = position;
          _isLoading = false;
        });
      }
    });

    // Listen to completion
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
      if (_activePlayer == this) {
        _activePlayer = null;
      }
    });
  }

  /// Membaca durasi audio di background tanpa menunggu user menekan tombol play
  Future<void> _preloadDuration() async {
    if (!mounted || widget.audioUrl.isEmpty || _duration > Duration.zero) return;
    try {
      final url = widget.audioUrl;
      // 1. Jika path lokal
      if (!url.startsWith('http')) {
        final file = File(url);
        if (await file.exists()) {
          final tempPlayer = AudioPlayer();
          await tempPlayer.setSource(DeviceFileSource(url));
          final d = await tempPlayer.getDuration();
          await tempPlayer.dispose();
          if (d != null && d > Duration.zero && mounted) {
            _durationCache[url] = d;
            setState(() => _duration = d);
          }
        }
        return;
      }

      // 2. Jika URL remote, cek file di disk cache
      final dir = await getTemporaryDirectory();
      final cleanUrl = url.split('?').first;
      final fileName = cleanUrl.split('/').last;
      final cachedPath = '${dir.path}/audio_cache_$fileName';
      if (File(cachedPath).existsSync()) {
        _localFilePath = cachedPath;
        final tempPlayer = AudioPlayer();
        await tempPlayer.setSource(DeviceFileSource(cachedPath));
        final d = await tempPlayer.getDuration();
        await tempPlayer.dispose();
        if (d != null && d > Duration.zero && mounted) {
          _durationCache[url] = d;
          setState(() => _duration = d);
        }
        return;
      }

      // 3. Download kecil di background agar durasi langsung terbaca
      final localPath = await _ensureDownloaded(url);
      if (!mounted) return;
      final tempPlayer = AudioPlayer();
      await tempPlayer.setSource(DeviceFileSource(localPath));
      final d = await tempPlayer.getDuration();
      await tempPlayer.dispose();
      if (d != null && d > Duration.zero && mounted) {
        _durationCache[url] = d;
        setState(() => _duration = d);
      }
    } catch (e) {
      debugPrint('🔇 Preload duration skipped: $e');
    }
  }

  /// Downloads audio from URL to local temp file (cached for replay)
  Future<String> _ensureDownloaded(String url) async {
    // Return cached path if already downloaded
    if (_localFilePath != null && File(_localFilePath!).existsSync()) {
      return _localFilePath!;
    }

    final dir = await getTemporaryDirectory();
    final cleanUrl = url.split('?').first;
    final fileName = cleanUrl.split('/').last;
    final filePath = '${dir.path}/audio_cache_$fileName';

    // Check if already cached on disk
    if (File(filePath).existsSync()) {
      _localFilePath = filePath;
      return filePath;
    }

    debugPrint('🔊 AudioPlayerWidget: Downloading $url ...');
    final dio = Dio();
    final response = await dio.download(url, filePath);
    if (response.statusCode == 200) {
      _localFilePath = filePath;
      final fileSize = File(filePath).lengthSync();
      debugPrint('🔊 AudioPlayerWidget: Downloaded $fileSize bytes → $filePath');
      return filePath;
    } else {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    } catch (_) {}
  }

  // [ACTION: PLAY_VOICE] - Mengontrol pemutaran dan penjedaan audio
  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        // Hentikan pemutar lain yang sedang aktif agar audio tidak saling bertumpuk
        if (_activePlayer != null && _activePlayer != this) {
          await _activePlayer?._stopPlayback();
        }
        _activePlayer = this;

        setState(() {
          _isLoading = true;
          _hasError = false;
        });

        final audioUrl = widget.audioUrl;

        // Ensure volume is at max
        await _audioPlayer.setVolume(1.0);

        if (audioUrl.startsWith('http')) {
          // Download file first to avoid MPEG4 streaming issues (MOOV atom at end)
          final localPath = await _ensureDownloaded(audioUrl);
          await _audioPlayer.play(DeviceFileSource(localPath));
        } else {
          await _audioPlayer.play(DeviceFileSource(audioUrl));
        }
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _isPlaying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _seekTo(double value) async {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayDuration = _formatDuration(_duration);
    final displayPosition = _formatDuration(_position);
    final durationText = '$displayPosition / $displayDuration';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio player container
        Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.white.withOpacity(0.2)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Play button and waveform/slider
              Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.isMe ? AppTheme.primaryColor : Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              _hasError
                                  ? Icons.error
                                  : (_isPlaying ? Icons.pause : Icons.play_arrow),
                              color: widget.isMe ? AppTheme.primaryColor : Colors.white,
                              size: 24,
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Progress and duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: widget.isMe ? Colors.white : AppTheme.primaryColor,
                            inactiveTrackColor: widget.isMe
                                ? Colors.white.withOpacity(0.3)
                                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            thumbColor: widget.isMe ? Colors.white : AppTheme.primaryColor,
                          ),
                          child: SizedBox(
                            height: 20,
                            child: Slider(
                              value: _duration.inMilliseconds > 0
                                  ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0,
                              onChanged: _duration.inMilliseconds > 0 ? _seekTo : null,
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Time display (0:00 / 0:03) + indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                durationText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isMe
                                      ? Colors.white70
                                      : (isDark ? Colors.grey.shade400 : AppTheme.textSecondary),
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mic,
                                    size: 13,
                                    color: widget.isMe
                                        ? Colors.white70
                                        : (isDark ? Colors.grey.shade400 : AppTheme.textSecondary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isPlaying
                                        ? '-${_formatDuration((_duration - _position).isNegative ? Duration.zero : _duration - _position)}'
                                        : 'Voice Note',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.isMe
                                          ? Colors.white70
                                          : (isDark ? Colors.grey.shade400 : AppTheme.textSecondary),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Error message
              if (_hasError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: widget.isMe ? Colors.white70 : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Failed to load voice note',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isMe ? Colors.white70 : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Caption (if exists)
        if (widget.caption != null && widget.caption!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.caption!,
            style: TextStyle(
              color: widget.isMe ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}