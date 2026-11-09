import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/consent.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  Widget _point(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const Text('Before you begin',
              style: TextStyle(fontSize: 28, fontFamily: 'serif')),
          const SizedBox(height: 6),
          const Text('Drishti uses your front camera during setup and sessions.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _point('When the camera is on',
                  'Only during setup and while a session is running. It turns off when you leave those screens.'),
              _point('What is processed',
                  'Video frames are analysed on this device to measure blinks, gaze and head position. Video and images are never stored or sent anywhere.'),
              _point('What is stored',
                  'Session date, duration, mode and summary numbers (such as blink rate and gaze stability), your journal notes, and your head reference. All of it stays on this phone.'),
              _point('Your control',
                  'You can turn off saving summaries, delete a journal entry, reset your baseline, or delete all data from Settings at any time.'),
              _point('What this app is not',
                  'It describes visible eye and head behaviour. It does not measure consciousness, thoughts, meditation quality or health, and it is not a medical tool.'),
            ]),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              ref.read(prefsProvider).setBool(kConsentKey, true);
              consentNotifier.value = true; // router apne aap Home le jayega
            },
            child: const Text('I understand and agree'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Not now'),
          ),
        ]),
      ),
    );
  }
}