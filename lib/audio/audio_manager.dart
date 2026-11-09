import 'package:flutter_tts/flutter_tts.dart';

enum AudioKind { posture, breathing }

class AudioManager {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false, _speaking = false;
  bool _muted = false;
  AudioKind? _current;
  DateTime _busyUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get muted => _muted;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(0.8);
      await _tts.setPitch(0.95);
      _tts.setCompletionHandler(_done);
      _tts.setCancelHandler(_done);
      _tts.setErrorHandler((_) => _done());
    } catch (_) {}
  }

  void _done() {
    _speaking = false;
    _current = null;
  }

  bool get _busy => _speaking && DateTime.now().isBefore(_busyUntil);

  /// true = bola gaya, false = skip hua (mute, ya koi aur awaaz chal rahi hai).
  Future<bool> speak(String text, AudioKind kind) async {
    if (_muted) return false;
    await _init();
    if (_muted) return false;
    if (_busy) {
      // sirf breathing, posture ko beech me kaat sakti hai
      final canInterrupt =
          kind == AudioKind.breathing && _current == AudioKind.posture;
      if (!canInterrupt) return false;
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _speaking = true;
    _current = kind;
    _busyUntil = DateTime.now().add(const Duration(seconds: 8)); // safety
    try {
      await _tts.speak(text);
    } catch (_) {
      _done();
      return false;
    }
    return true;
  }

  Future<void> stop() async {
    _done();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void setMuted(bool value) {
    _muted = value;
    if (value) stop();
  }

  void dispose() => stop();
}