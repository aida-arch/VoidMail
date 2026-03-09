import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects and haptic feedback service.
/// Mirrors SoundService.swift from the reference iOS app.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // ─── Sound Effects ───────────────────────────────────

  /// Plays a send-email sound effect + medium haptic.
  Future<void> playSendSound() async {
    await _playSystemSound();
    await HapticFeedback.mediumImpact();
  }

  /// Plays a receive-notification sound + success haptic.
  Future<void> playReceiveSound() async {
    await _playSystemSound();
    await HapticFeedback.heavyImpact();
  }

  /// Plays a delete/archive sound + light haptic.
  Future<void> playDeleteSound() async {
    await _playSystemSound();
    await HapticFeedback.lightImpact();
  }

  /// Plays a star/favorite toggle sound + soft haptic.
  Future<void> playStarSound() async {
    await _playSystemSound();
    await HapticFeedback.selectionClick();
  }

  /// Plays a refresh/sync sound (no haptic).
  Future<void> playRefreshSound() async {
    await _playSystemSound();
  }

  // ─── Haptic Feedback ─────────────────────────────────

  /// Light tap haptic feedback.
  Future<void> playTapFeedback() async {
    await HapticFeedback.lightImpact();
  }

  /// Success haptic feedback.
  Future<void> playSuccessFeedback() async {
    await HapticFeedback.mediumImpact();
  }

  /// Error haptic feedback.
  Future<void> playErrorFeedback() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection haptic feedback.
  Future<void> playSelectionFeedback() async {
    await HapticFeedback.selectionClick();
  }

  // ─── Internal ────────────────────────────────────────

  Future<void> _playSystemSound() async {
    try {
      // Use system sound via platform channel
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
