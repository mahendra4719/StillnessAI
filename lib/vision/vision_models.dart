enum EyeState { open, closed, uncertain }

/// Ek frame ka output. Jo cheez reliable nahi hai wo null hoti hai, 0 nahi.
class FrameReading {
  final int tMs; // session ke chalne ka time (pause hata ke), milliseconds
  final bool faceVisible;
  final double trackingQuality; // 0.0 se 1.0
  final EyeState eyeState; // Model 1
  final double eyeConfidence; // 0.0 se 1.0
  final double? gazeX, gazeY; // Model 2, -1.0 se 1.0, aankh band ho to null
  final double? yaw, pitch, roll; // Model 3, degrees, face na dikhe to null

  const FrameReading({
    required this.tMs,
    required this.faceVisible,
    required this.trackingQuality,
    required this.eyeState,
    required this.eyeConfidence,
    this.gazeX,
    this.gazeY,
    this.yaw,
    this.pitch,
    this.roll,
  });
}

/// Camera + models ko chhupane wala interface.
abstract class VisionPipeline {
  Stream<FrameReading> get readings;
  Future<void> start({required bool eyesClosedMode});
  void pause();
  void resume();
  Future<void> stop(); // dobara call karne par kuch nahi bigadna chahiye
}