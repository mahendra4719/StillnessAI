import 'dart:async';
import 'dart:math';
import 'vision_models.dart';

class MockVisionPipeline implements VisionPipeline {
  static const _tickMs = 100; // 10 readings per second
  final _rand = Random();
  final _ctrl = StreamController<FrameReading>.broadcast();
  Timer? _timer;
  bool _running = false, _closedMode = false, _stopped = false;

  int _t = 0;
  int _nextBlinkAt = 3000, _blinkEndAt = -1;
  int _dropoutStart = 40000, _dropoutEnd = -1;
  double _gx = 0, _gy = 0;

  @override
  Stream<FrameReading> get readings => _ctrl.stream;

  @override
  Future<void> start({required bool eyesClosedMode}) async {
    _closedMode = eyesClosedMode;
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _tick());
  }

  @override
  void pause() => _running = false;

  @override
  void resume() => _running = true;

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    await _ctrl.close();
  }

  void _tick() {
    if (!_running || _stopped) return;
    _t += _tickMs;

    // tracking dropout: har ~40 sec me 2 sec ke liye face "gayab"
    if (_t >= _dropoutStart && _dropoutEnd < 0) _dropoutEnd = _t + 2000;
    if (_dropoutEnd > 0 && _t >= _dropoutEnd) {
      _dropoutEnd = -1;
      _dropoutStart = _t + 35000 + _rand.nextInt(10000);
    }
    if (_dropoutEnd > 0) {
      _ctrl.add(FrameReading(
        tMs: _t,
        faceVisible: false,
        trackingQuality: 0.1,
        eyeState: EyeState.uncertain,
        eyeConfidence: 0.2,
      ));
      return;
    }

    // eye state
    EyeState eye;
    double eyeConf;
    if (_closedMode) {
      eye = EyeState.closed; // lambi intentional closure, blink nahi
      eyeConf = 0.9;
    } else {
      if (_blinkEndAt < 0 && _t >= _nextBlinkAt) {
        _blinkEndAt = _t + 200 + _rand.nextInt(200); // blink 200-400 ms
      }
      if (_blinkEndAt > 0 && _t >= _blinkEndAt) {
        _blinkEndAt = -1;
        _nextBlinkAt = _t + 2000 + _rand.nextInt(4000); // ~ 12-20 blinks/min
      }
      eye = _blinkEndAt > 0 ? EyeState.closed : EyeState.open;
      eyeConf = 0.9;
    }

    // gaze: dheeme drift + kabhi kabhi saccade jump
    double? gx, gy;
    if (eye == EyeState.open) {
      _gx += (_rand.nextDouble() - 0.5) * 0.02;
      _gy += (_rand.nextDouble() - 0.5) * 0.02;
      if (_rand.nextDouble() < 0.02) {
        _gx += (_rand.nextDouble() - 0.5) * 0.6;
        _gy += (_rand.nextDouble() - 0.5) * 0.6;
      }
      _gx = _gx.clamp(-1.0, 1.0);
      _gy = _gy.clamp(-1.0, 1.0);
      gx = _gx;
      gy = _gy;
    }

    // head: dheemi hilna + har ~90 sec me 20 sec ka lamba jhukav
    final sec = _t / 1000;
    final lean = (sec % 90) > 70 ? 15.0 : 0.0;
    _ctrl.add(FrameReading(
      tMs: _t,
      faceVisible: true,
      trackingQuality: 0.9,
      eyeState: eye,
      eyeConfidence: eyeConf,
      gazeX: gx,
      gazeY: gy,
      yaw: sin(sec / 5) * 3 + (_rand.nextDouble() - 0.5),
      pitch: sin(sec / 7) * 2 + lean + (_rand.nextDouble() - 0.5),
      roll: sin(sec / 9) * 1.5 + (_rand.nextDouble() - 0.5),
    ));
  }
}