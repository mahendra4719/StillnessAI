import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class NativeFrame {
  final int faceCount;
  final double faceHeightFrac;
  final double? yaw, pitch, roll, reprojErr, closedProb;
  final String eyeState; // open | closed | uncertain
  final double eyeConf;
  final String poseStatus;
  final int inferMs;

  const NativeFrame({
    required this.faceCount,
    required this.faceHeightFrac,
    required this.eyeState,
    required this.eyeConf,
    required this.poseStatus,
    required this.inferMs,
    this.yaw,
    this.pitch,
    this.roll,
    this.reprojErr,
    this.closedProb,
  });

  factory NativeFrame.fromMap(Map m) => NativeFrame(
        faceCount: (m['faceCount'] as num?)?.toInt() ?? 0,
        faceHeightFrac: (m['faceHeightFrac'] as num?)?.toDouble() ?? 0,
        eyeState: (m['eyeState'] as String?) ?? 'uncertain',
        eyeConf: (m['eyeConf'] as num?)?.toDouble() ?? 0,
        poseStatus: (m['poseStatus'] as String?) ?? 'unknown',
        inferMs: (m['inferMs'] as num?)?.toInt() ?? 0,
        yaw: (m['yaw'] as num?)?.toDouble(),
        pitch: (m['pitch'] as num?)?.toDouble(),
        roll: (m['roll'] as num?)?.toDouble(),
        reprojErr: (m['reprojErr'] as num?)?.toDouble(),
        closedProb: (m['closedProb'] as num?)?.toDouble(),
      );
}

class NativeVision {
  static const _ch = MethodChannel('drishti/vision');

  /// null = sab theek, warna error text.
  Future<String?> init({double threshold = 0.53}) async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>(
          'init', {'threshold': threshold});
      if (r != null && r['ok'] == true) return null;
      return (r?['error'] as String?) ?? 'unknown error';
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    }
  }

  Future<NativeFrame?> process(
      CameraImage image, CameraDescription cam, int tMs) async {
    if (image.planes.length != 1) return null; // NV21 hi chahiye
    final p = image.planes.first;
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('process', {
        'bytes': p.bytes,
        'width': image.width,
        'height': image.height,
        'stride': p.bytesPerRow,
        'rotation': cam.sensorOrientation,
        'tMs': tMs,
      });
      if (r == null || r['error'] != null) return null;
      return NativeFrame.fromMap(r);
    } on PlatformException {
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await _ch.invokeMethod('dispose');
    } catch (_) {}
  }
}