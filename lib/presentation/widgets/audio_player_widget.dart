import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';

// =====================================================================
// FITUR: Komponen Pemutar Audio (Voice Note)
// FILE: lib/presentation/widgets/audio_player_widget.dart
// BARIS AWAL: 9 (setelah komentar ini)
// FUNGSI: Menampilkan pemutar audio khusus untuk Voice Note dalam balon chat, lengkap dengan progress bar.
// =====================================================================
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final String? caption;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.caption,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
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
  }

  @override
  void dispose() {
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
      if (mounted) {
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
    });
  }

  /// Downloads audio from URL to local temp file (cached for replay)
  Future<String> _ensureDownloaded(String url) async {
    // Return cached path if already downloaded
    if (_localFilePath != null && File(_localFilePath!).existsSync()) {
      return _localFilePath!;
    }

    final dir = await getTemporaryDirectory();
    final fileName = url.split('/').last;
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

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
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

  Future<void> _seekTo(double value) async {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio player container
        Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Play button and waveform
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
                      children: [
                        // Progress bar
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: widget.isMe ? Colors.white : AppTheme.primaryColor,
                            inactiveTrackColor: widget.isMe 
                                ? Colors.white.withOpacity(0.3) 
                                : Colors.grey.shade300,
                            thumbColor: widget.isMe ? Colors.white : AppTheme.primaryColor,
                          ),
                          child: Slider(
                            value: _duration.inMilliseconds > 0 
                                ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: _duration.inMilliseconds > 0 ? _seekTo : null,
                          ),
                        ),
                        
                        // Time display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isMe ? Colors.white70 : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isMe ? Colors.white70 : AppTheme.textSecondary,
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
              
              // Audio icon and type indicator
              if (!_isLoading && !_hasError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 14,
                      color: widget.isMe ? Colors.white70 : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Voice Note',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isMe ? Colors.white70 : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              
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