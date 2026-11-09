import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../audio/audio_manager.dart';
import '../../data/providers.dart';

class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key});
  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final AudioManager _audio;
  late bool spoken;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioManagerProvider);
    _audio.setMuted(false);
    spoken = ref.read(settingsProvider)['breathing'] ?? true;
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _c.addStatusListener((s) {
      if (!spoken) return;
      if (s == AnimationStatus.forward) {
        _audio.speak('Breathe in', AudioKind.breathing);
      } else if (s == AnimationStatus.reverse) {
        _audio.speak('Breathe out', AudioKind.breathing);
      }
    });
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _audio.stop();
    _c.dispose();
    super.dispose();
  }

  void _leave() {
    _audio.stop();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breathing'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _leave),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          const Spacer(),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final inhale = _c.status == AnimationStatus.forward;
              return Container(
                width: 120 + 120 * _c.value,
                height: 120 + 120 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14262A),
                  border: Border.all(color: const Color(0xFF3E8A6A), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(inhale ? 'Inhale' : 'Exhale',
                    style: const TextStyle(fontSize: 26, fontFamily: 'serif')),
              );
            },
          ),
          const Spacer(),
          SwitchListTile(
            title: const Text('Spoken prompts'),
            value: spoken,
            onChanged: (v) {
              setState(() => spoken = v);
              if (!v) _audio.stop();
            },
          ),
          const Text(
            'Breathe comfortably. Never hold your breath or breathe unusually deep. Stop any time.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _leave, child: const Text('Stop'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: _leave, child: const Text('Natural breathing'))),
          ]),
        ]),
      ),
    );
  }
}