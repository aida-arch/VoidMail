import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

/// Deepgram Text-to-Speech Service.
/// Converts email text to audio using Deepgram's TTS API.
/// Mirrors DeepgramService.swift from the reference iOS app.
class DeepgramService extends ChangeNotifier {
  static final DeepgramService _instance = DeepgramService._internal();
  factory DeepgramService() => _instance;
  DeepgramService._internal();

  // Deepgram API key from reference project
  static const String _apiKey = '83ae019a53e7258c6fa87186d521f628dbc7eb2f';
  static const String _baseUrl = 'https://api.deepgram.com/v1/speak';

  bool _isGenerating = false;
  bool _isPlaying = false;
  double _playbackProgress = 0;
  double _audioDuration = 0;
  String? _error;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _progressTimer;
  final Map<String, String> _cachedAudioPaths = {};

  // ─── Getters ─────────────────────────────────────────

  bool get isGenerating => _isGenerating;
  bool get isPlaying => _isPlaying;
  double get playbackProgress => _playbackProgress;
  double get audioDuration => _audioDuration;
  String? get error => _error;

  // ─── Generate Audio from Email ───────────────────────

  /// Generates TTS audio for an email body. Returns the local file path.
  /// Splits long text into chunks to avoid Deepgram's payload size limit.
  Future<String?> generateAudio({
    required String emailId,
    required String text,
    String voice = 'aura-asteria-en',
  }) async {
    // Return cached audio if already generated
    if (_cachedAudioPaths.containsKey(emailId)) {
      return _cachedAudioPaths[emailId];
    }

    _isGenerating = true;
    _error = null;
    notifyListeners();

    if (_apiKey.isEmpty) {
      _error = 'Deepgram API key not configured';
      _isGenerating = false;
      notifyListeners();
      return null;
    }

    try {
      // Trim to reasonable max and split into chunks
      final trimmedText = text.length > 5000 ? text.substring(0, 5000) : text;
      final chunks = _splitIntoChunks(trimmedText, maxLength: 1500);

      final allAudioData = <int>[];

      for (final chunk in chunks) {
        final chunkData = await _fetchTTSAudio(text: chunk, voice: voice);
        if (chunkData != null) {
          allAudioData.addAll(chunkData);
        }
      }

      if (allAudioData.isEmpty) {
        _error = 'Failed to generate audio';
        _isGenerating = false;
        notifyListeners();
        return null;
      }

      // Save combined audio to temp file
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/voidmail_tts_$emailId.mp3';
      final file = File(filePath);
      await file.writeAsBytes(allAudioData);
      _cachedAudioPaths[emailId] = filePath;

      _isGenerating = false;
      notifyListeners();
      return filePath;
    } catch (e) {
      debugPrint('[DeepgramService] generateAudio error: $e');
      _error = 'Failed to generate audio';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  /// Fetch TTS audio for a single text chunk from Deepgram
  Future<List<int>?> _fetchTTSAudio({
    required String text,
    required String voice,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl?model=$voice&encoding=mp3');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('[DeepgramService] Chunk TTS error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[DeepgramService] fetchTTSAudio error: $e');
      return null;
    }
  }

  /// Split text into chunks at sentence boundaries, respecting maxLength
  List<String> _splitIntoChunks(String text, {int maxLength = 1500}) {
    if (text.length <= maxLength) return [text];

    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLength) {
        chunks.add(remaining);
        break;
      }

      final searchRange = remaining.substring(0, maxLength);
      int splitIndex = -1;

      // Find the last sentence-ending punctuation within maxLength
      for (final delimiter in ['. ', '! ', '? ', '.\n', '!\n', '?\n']) {
        final idx = searchRange.lastIndexOf(delimiter);
        if (idx > splitIndex) {
          splitIndex = idx + delimiter.length;
        }
      }

      // If no sentence boundary found, split at last space
      if (splitIndex == -1) {
        final spaceIdx = searchRange.lastIndexOf(' ');
        if (spaceIdx > 0) {
          splitIndex = spaceIdx + 1;
        } else {
          // No space found — hard split
          splitIndex = maxLength;
        }
      }

      final chunk = remaining.substring(0, splitIndex).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      remaining = remaining.substring(splitIndex).trim();
    }

    return chunks;
  }

  // ─── Playback Controls ───────────────────────────────

  /// Play audio from a file path
  Future<void> play(String filePath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
      _isPlaying = true;
      notifyListeners();

      // Get duration
      _audioPlayer.onDurationChanged.listen((duration) {
        _audioDuration = duration.inMilliseconds / 1000.0;
        notifyListeners();
      });

      // Start progress tracking
      _startProgressTracking();

      // Listen for completion
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _playbackProgress = 0;
        _stopProgressTracking();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[DeepgramService] play error: $e');
      _error = 'Failed to play audio';
      notifyListeners();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    _stopProgressTracking();
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    _startProgressTracking();
    notifyListeners();
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _playbackProgress = 0;
    _stopProgressTracking();
    notifyListeners();
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seek(double progress) async {
    final position = Duration(
      milliseconds: (progress * _audioDuration * 1000).toInt(),
    );
    await _audioPlayer.seek(position);
    _playbackProgress = progress;
    notifyListeners();
  }

  // ─── Progress Tracking ───────────────────────────────

  void _startProgressTracking() {
    _stopProgressTracking();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final position = await _audioPlayer.getCurrentPosition();
      if (position != null && _audioDuration > 0) {
        _playbackProgress = position.inMilliseconds / (_audioDuration * 1000);
        notifyListeners();
      }
    });
  }

  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ─── Utilities ───────────────────────────────────────

  /// Format duration in mm:ss
  static String formatDuration(double seconds) {
    final minutes = seconds.toInt() ~/ 60;
    final secs = seconds.toInt() % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Check if audio is cached for an email
  bool hasCachedAudio(String emailId) {
    return _cachedAudioPaths.containsKey(emailId);
  }

  /// Get cached audio path for an email
  String? cachedPath(String emailId) {
    return _cachedAudioPaths[emailId];
  }

  /// Clear all cached audio files
  Future<void> clearCache() async {
    for (final path in _cachedAudioPaths.values) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _cachedAudioPaths.clear();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stopProgressTracking();
    super.dispose();
  }
}
