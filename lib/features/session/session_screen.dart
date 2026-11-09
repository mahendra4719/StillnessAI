import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/theme.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import '../../vision/pipeline_factory.dart';
import '../../vision/vision_models.dart';
import '../../vision/measurements.dart';
import '../../audio/audio_manager.dart';
import '../../audio/posture_monitor.dart';
import '../../analysis/summary_logic.dart';
import '../../shared/debug.dart';

const bool kQuickTest = false; // Enable only for a short development run.
const int kMinSaveSec = 5; // isse chhota session save nahi hoga

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});
  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with WidgetsBindingObserver {
  late final int total; // seconds
  late final bool eyesClosed;
  final startedAt = DateTime.now();

  // timing: pause se pehle ka jama hua time + abhi chal raha segment
  int _accMs = 0;
  DateTime? _runStart = DateTime.now();

  bool muted = false, _finished = false, _autoPaused = false;
  int _shownRemaining = 0;
  Timer? _timer;

  late final VisionPipeline _pipeline;
  late final AudioManager _audio;
  late final PostureMonitor _posture;
  late final bool _postureOn;
  bool _reminding = false;
  StreamSubscription<FrameReading>? _sub;
  final List<FrameReading> _readings = []; // step 7 me measurements inhi se niklenge
  FrameReading? _lastReading;


  bool get running => _runStart != null;

  int get _elapsedMs {
    final live = _runStart == null
        ? 0
        : DateTime.now().difference(_runStart!).inMilliseconds;
    return _accMs + live;
  }

  int get _remainingSec =>
      ((total * 1000 - _elapsedMs) / 1000).ceil().clamp(0, total);

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(sessionConfigProvider);
    total = kQuickTest ? 10 : cfg.minutes * 60;
    eyesClosed = cfg.eyesClosed;
    _shownRemaining = total;

    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // session me screen band na ho
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    _audio = ref.read(audioManagerProvider);
    _audio.setMuted(false);
    _postureOn = ref.read(settingsProvider)['posture'] ?? true;
    _posture = PostureMonitor(reference: ref.read(headReferenceProvider));

    _pipeline = createPipeline();
    _sub = _pipeline.readings.listen((r) {
      _readings.add(r);
      _lastReading = r;
      if (_postureOn && !_reminding && _posture.update(r)) _remind(r.tMs);
      if (kShowDebug && _readings.length % 5 == 0 && mounted) setState(() {});
    });
    _pipeline.start(eyesClosedMode: eyesClosed);

    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _finished) return;
      if (_elapsedMs >= total * 1000) {
        _finish();
        return;
      }
      final r = _remainingSec;
      if (r != _shownRemaining) setState(() => _shownRemaining = r);
    });
  }

  // App background me gaya -> pause. Wapas aane par user khud Resume dabata hai.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && running && !_finished) {
      _pause(auto: true);
    }
  }

  void _pause({bool auto = false}) {
    if (!running) return;
    _accMs = _elapsedMs;
    _runStart = null;
    _pipeline.pause();
    _audio.stop();
    _posture.resetRun();
    if (mounted) setState(() => _autoPaused = auto);
  }

  void _resume() {
    if (running) return;
    _runStart = DateTime.now();
    _pipeline.resume();
    setState(() => _autoPaused = false);
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    _sub?.cancel();
    await _pipeline.stop();
    await _audio.stop();

    final actual = (_elapsedMs / 1000).round().clamp(0, total);
    _runStart = null;

    if (actual < kMinSaveSec) {
      if (mounted) context.go('/');
      return;
    }

    final m = computeMeasurements(
      _readings,
      eyesClosedMode: eyesClosed,
      headRef: ref.read(headReferenceProvider),
    );
    ref.read(lastMeasurementsProvider.notifier).set(m);

    final allHistory = await AppDatabase.instance.sessions(); // abhi ka session isme nahi hai
    final since = ref.read(baselineSinceProvider);
    final history = allHistory
        .where((s) => s.startedAt.millisecondsSinceEpoch >= since)
        .toList();
    final insights = buildInsights(
      m,
      eyesClosed: eyesClosed,
      actualSec: actual,
      history: history,
    );
    ref.read(lastInsightsProvider.notifier).set(insights);

    final record = SessionRecord(
      startedAt: startedAt,
      plannedSec: total,
      actualSec: actual,
      eyesClosed: eyesClosed,
      blinkRate: m.blinkRate,
      gazeStability: m.gazeStability,
      trackingQuality: _readings.isEmpty ? null : m.trackingQuality,
      postureReminders: (_postureOn && m.alignedSec != null) ? _posture.count : null,
      pattern: insights.pattern,    //(Model 4) 
    );
    ref.read(lastResultProvider.notifier).set(record);

    final save = ref.read(settingsProvider)['saveSummaries'] ?? true;
    if (save) {
      await AppDatabase.instance.insertSession(record);
      ref.invalidate(sessionsProvider);
    }
    if (mounted) context.go('/summary');
  }

  Future<void> _confirmEnd() async {
    final wasRunning = running;
    _pause();
    final ok = await confirmDialog(
        context, 'End session?', 'The session will stop and your summary will open.');
    if (ok) {
      _finish();
    } else if (wasRunning && mounted) {
      _resume();
    }
  }

  Future<void> _remind(int tMs) async {
    _reminding = true;
    final spoken = await _audio.speak(
        'Gently check your posture.', AudioKind.posture);
    if (spoken) _posture.markReminded(tMs);
    _reminding = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();

    _sub?.cancel();
    _pipeline.stop();
    _audio.stop();
    _audio.setMuted(false);

    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final status = running
        ? 'Session in progress'
        : _autoPaused
            ? 'Paused (app was in the background)'
            : 'Paused';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_finished) _confirmEnd();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3A5256), width: 2),
                  color: const Color(0xFF14262A),
                ),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmt(_shownRemaining),
                      style: const TextStyle(fontSize: 48, fontFamily: 'serif')),
                  const Text('remaining', style: TextStyle(color: AppColors.muted)),
                ]),
              ),
              const SizedBox(height: 20),
              Text(eyesClosed ? 'Eyes closed' : 'Eyes open',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.accent)),
              
              if (kShowDebug && _lastReading != null) ...[
                const SizedBox(height: 10),
                Text(
                  'DEBUG  n=${_readings.length}  eye=${_lastReading!.eyeState.name}  '
                  'face=${_lastReading!.faceVisible}  '
                  'gaze=${_lastReading!.gazeX?.toStringAsFixed(2) ?? "null"}  '
                  'yaw=${_lastReading!.yaw?.toStringAsFixed(1) ?? "null"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],

              const Spacer(),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: running ? _pause : _resume,
                    child: Text(running ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => muted = !muted);
                      _audio.setMuted(muted);
                    },
                    child: Text(muted ? 'Unmute' : 'Mute audio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmEnd,
                    child: const Text('Finish'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}
