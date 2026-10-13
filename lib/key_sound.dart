import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Calculator key click sound.
///
/// Plays a short tactile click on every key press. The user can mute it
/// from the speaker toggle in the calculator header; the choice persists.
class KeySound {
  static const _kEnabled = 'key_sound_enabled';
  static final AudioPlayer _player = AudioPlayer();
  static bool enabled = true;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_kEnabled) ?? true;
      _ready = true;
    } catch (_) {
      // Headless/test environments: stay silent.
    }
  }

  static Future<void> setEnabled(bool v) async {
    enabled = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, v);
    } catch (_) {}
  }

  /// Fire-and-forget: never throws, never blocks the UI thread.
  static Future<void> click() async {
    if (!enabled || !_ready) return;
    try {
      await _player.play(AssetSource('sounds/key_click.wav'));
    } catch (_) {
      // No audio backend (e.g. widget tests): stay silent.
    }
  }
}
