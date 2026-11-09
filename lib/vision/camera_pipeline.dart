import 'dart:async';

import 'package:camera/camera.dart';

import 'native_vision.dart';
import 'vision_models.dart';

/// Runs the on-device vision engine over live front-camera frames.
class CameraVisionPipeline implements VisionPipeline {
  final NativeVision _vision = NativeVision();
  final StreamController<FrameReading> _controller =
      StreamController<FrameReading>.broadcast();
  CameraController? _cameraController;
  CameraDescription? _camera;
  final Stopwatch _clock = Stopwatch();
  bool _busy = false;
  bool _running = false;
  bool _stopped = false;

  @override
  Stream<FrameReading> get readings => _controller.stream;

  @override
  Future<void> start({required bool eyesClosedMode}) async {
    if (_stopped) throw StateError('Vision pipeline already stopped');
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera is available');
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final error = await _vision.init();
    if (error != null) throw StateError('Vision engine failed: $error');

    final cam = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _cameraController = cam;
    _camera = camera;
    await cam.initialize();
    _running = true;
    _clock.start();
    await cam.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    if (!_running || _busy || _stopped) return;
    _busy = true;
    try {
      final camera = _camera;
      if (camera == null) return;
      final frame = await _vision.process(
        image,
        camera,
        _clock.elapsedMilliseconds,
      );
      if (frame == null || _stopped) return;
      final visible = frame.faceCount == 1;
      final eyeState = !visible
          ? EyeState.uncertain
          : switch (frame.eyeState) {
              'open' => EyeState.open,
              'closed' => EyeState.closed,
              _ => EyeState.uncertain,
            };
      _controller.add(
        FrameReading(
          tMs: _clock.elapsedMilliseconds,
          faceVisible: visible,
          trackingQuality: frame.faceCount == 1 && frame.faceHeightFrac >= 0.22
              ? 0.9
              : 0.1,
          eyeState: eyeState,
          eyeConfidence: frame.eyeConf.clamp(0.0, 1.0).toDouble(),
          yaw: frame.yaw,
          pitch: frame.pitch,
          roll: frame.roll,
        ),
      );
    } catch (_) {
      // Ignore an individual bad frame; the next camera frame can recover.
    } finally {
      _busy = false;
    }
  }

  @override
  void pause() {
    _running = false;
    _clock.stop();
  }

  @override
  void resume() {
    if (_stopped) return;
    _running = true;
    _clock.start();
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _running = false;
    _clock.stop();
    final cam = _cameraController;
    _cameraController = null;
    if (cam != null) {
      try {
        if (cam.value.isStreamingImages) await cam.stopImageStream();
      } catch (_) {}
      try {
        await cam.dispose();
      } catch (_) {}
    }
    await _vision.dispose();
    await _controller.close();
  }
}
