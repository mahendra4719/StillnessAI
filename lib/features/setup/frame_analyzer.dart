import 'dart:math';
import 'package:camera/camera.dart';
import '../../vision/native_vision.dart';

class SetupReading {
  final int faceCount;
  final bool faceBigEnough, eyesDetected;
  final double brightness; // 0 to 255
  final double? yaw, pitch, roll;
  final String eyeState;
  final double? closedProb;
  final int inferMs;

  const SetupReading({
    required this.faceCount,
    required this.faceBigEnough,
    required this.eyesDetected,
    required this.brightness,
    this.yaw,
    this.pitch,
    this.roll,
    this.eyeState = 'uncertain',
    this.closedProb,
    this.inferMs = 0,
  });

  bool get faceOk => faceCount == 1 && faceBigEnough;
  bool get lightOk => brightness >= 60 && brightness <= 200;
}

class FrameAnalyzer {
  final NativeVision _vision = NativeVision();
  final DateTime _t0 = DateTime.now();
  bool _busy = false, _ready = false, _failed = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  String? initError;

  Future<SetupReading?> analyze(CameraImage image, CameraDescription cam) async {
    final now = DateTime.now();
    if (_busy || _failed || now.difference(_last).inMilliseconds < 150) {
      return null;
    }
    _busy = true;
    _last = now;
    try {
      if (!_ready) {
        initError = await _vision.init();
        if (initError != null) {
          _failed = true;
          return null;
        }
        _ready = true;
      }
      if (image.planes.length != 1) return null;
      final plane = image.planes.first;
      final brightness = _brightness(plane.bytes, image.width * image.height);
      final f = await _vision.process(
          image, cam, now.difference(_t0).inMilliseconds);
      if (f == null) return null;
      return SetupReading(
        faceCount: f.faceCount,
        faceBigEnough: f.faceHeightFrac >= 0.22,
        eyesDetected: f.closedProb != null,
        brightness: brightness,
        yaw: f.yaw,
        pitch: f.pitch,
        roll: f.roll,
        eyeState: f.eyeState,
        closedProb: f.closedProb,
        inferMs: f.inferMs,
      );
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  // NV21 me pehle width*height bytes brightness (Y) ke hote hain.
  double _brightness(List<int> bytes, int yLen) {
    final n = min(bytes.length, yLen);
    var sum = 0, count = 0;
    for (var i = 0; i < n; i += 37) {
      sum += bytes[i];
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  void dispose() => _vision.dispose();
}