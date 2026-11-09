import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import 'frame_analyzer.dart';
import '../../shared/debug.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen>
    with WidgetsBindingObserver {
  final _analyzer = FrameAnalyzer();
  final List<HeadReference> _recent = [];
  CameraController? _controller;
  CameraDescription? _camera;
  SetupReading? _reading;
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (_starting || _controller != null) return;
    _starting = true;
    setState(() => _error = null);
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final c = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _controller = c;
      _camera = cam;
      await c.startImageStream(_onFrame);
      if (mounted) setState(() {});
    } on CameraException catch (e) {
      final denied = e.code.toLowerCase().contains('denied');
      if (mounted) {
        setState(() => _error = denied
            ? 'Camera permission is needed to set up. Please allow it and retry.'
            : (kShowDebug
                ? 'Camera problem: ${e.description ?? e.code}'
                : 'The camera could not be started. Please try again.'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the camera.');
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopCamera() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _onFrame(CameraImage img) async {
    final cam = _camera;
    if (cam == null) return;
    final r = await _analyzer.analyze(img, cam);
    
    if (_analyzer.initError != null && _error == null && mounted) {
      setState(() => _error = kShowDebug
                                        ? 'Vision engine failed: ${_analyzer.initError}'
                                        : 'Could not start the camera analysis. Please close and reopen the app.');
    }

    if (r == null || !mounted) return;
    if (r.faceOk && r.yaw != null) {
      _recent.add(HeadReference(r.yaw!, r.pitch!, r.roll!));
      if (_recent.length > 8) _recent.removeAt(0);
    } else {
      _recent.clear();
    }
    setState(() => _reading = r);
  }

  // App background me jaye to camera band, wapas aaye to chalu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
      _recent.clear();
      if (mounted) setState(() => _reading = null);
    } else if (state == AppLifecycleState.resumed && _error == null) {
      _initCamera();
    }
  }

  void _setReference() {
    if (_recent.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Keep your face visible and steady, then try again.')));
      return;
    }
    double avg(double Function(HeadReference r) f) =>
        _recent.map(f).reduce((a, b) => a + b) / _recent.length;
    ref.read(headReferenceProvider.notifier).set(HeadReference(
          avg((r) => r.yaw),
          avg((r) => r.pitch),
          avg((r) => r.roll),
        ));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Head reference saved')));
  }

  Future<void> _continue() async {
    await _stopCamera(); // camera chhodo, Session screen ise khud kholegi
    if (mounted) context.go('/session');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _analyzer.dispose();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  Widget _preview() {
    final c = _controller;
    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF14262A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A5256)),
      ),
      child: (c == null || !c.value.isInitialized)
          ? const Center(
              child: Icon(Icons.face_outlined, size: 96, color: AppColors.accent))
          : FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.previewSize!.height,
                height: c.value.previewSize!.width,
                child: CameraPreview(c),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    final eyesClosedMode = ref.watch(sessionConfigProvider).eyesClosed;
    final headRef = ref.watch(headReferenceProvider);

    String faceText;
    Color? faceColor = AppColors.accent;
    if (r == null) {
      faceText = 'Looking…';
    } else if (r.faceCount == 0) {
      faceText = 'Not detected';
    } else if (r.faceCount > 1) {
      faceText = 'More than one face';
    } else if (!r.faceBigEnough) {
      faceText = 'Move a bit closer';
    } else {
      faceText = 'Good';
      faceColor = AppColors.good;
    }

    String lightText;
    Color? lightColor = AppColors.accent;
    if (r == null) {
      lightText = 'Checking…';
    } else if (r.brightness < 60) {
      lightText = 'Too dark';
    } else if (r.brightness > 200) {
      lightText = 'Too bright';
    } else {
      lightText = 'Good';
      lightColor = AppColors.good;
    }

    String eyesText;
    Color? eyesColor = AppColors.accent;
    if (eyesClosedMode) {
      eyesText = 'Not needed (eyes closed mode)';
      eyesColor = AppColors.muted;
    } else if (r == null || r.faceCount != 1) {
      eyesText = 'Checking…';
    } else if (r.eyesDetected) {
      eyesText = 'Good';
      eyesColor = AppColors.good;
    } else {
      eyesText = 'Not detected. Check glasses glare';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your phone'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Place it at a steady, comfortable angle.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        _preview(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_error!),
              if (_analyzer.initError == null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _initCamera,
                  child: const Text('Retry'),
                ),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 14),
        AppCard(
          child: Column(children: [
            MetricRow('Face visible', faceText, color: faceColor),
            MetricRow('Lighting', lightText, color: lightColor),
            MetricRow('Eyes trackable', eyesText, color: eyesColor),
            MetricRow('Head reference', headRef == null ? 'Not set' : 'Set',
                color: headRef == null ? AppColors.accent : AppColors.good),
          ]),
        ),
        
        if (kShowDebug && _reading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'DEBUG eye=${_reading!.eyeState} closedP=${_reading!.closedProb?.toStringAsFixed(2)} '
              'yaw=${_reading!.yaw?.toStringAsFixed(1)} pitch=${_reading!.pitch?.toStringAsFixed(1)} '
              'roll=${_reading!.roll?.toStringAsFixed(1)} ${_reading!.inferMs}ms',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ),

        const Text(
          'Sit comfortably and look at the phone naturally, then tap the button. Posture reminders compare your head with this position.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (r?.faceOk ?? false) ? _setReference : null,
            child: Text(headRef == null
                ? 'Set head reference'
                : 'Update head reference'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Camera is on only during setup and sessions. Video is processed on this device and never stored.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _controller == null ? null : _continue,
          child: const Text('Continue'),
        ),
      ]),
    );
  }
}