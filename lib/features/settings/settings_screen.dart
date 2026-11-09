import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets.dart';
import '../../app/consent.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    Widget sw(String title, String key) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          value: s[key] ?? true,
          onChanged: (v) => notifier.set(key, v),
        );

    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Settings', style: TextStyle(fontSize: 28, fontFamily: 'serif')),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Audio feedback'),
          sw('Gentle posture reminders', 'posture'),
          sw('Spoken breathing prompts', 'breathing'),
          const MetricRow('Reminder cooldown', '2 min'),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Camera and privacy'),
          sw('Save session summaries', 'saveSummaries'),
          const MetricRow('Camera', 'Active only in sessions'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(headReferenceProvider.notifier).clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Head reference cleared')));
                },
                child: const Text('Reset head ref.'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Recalibrate gaze'))),
          ]),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Your data'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final ok = await confirmDialog(context, 'Delete all data?',
                    'This removes all sessions, journal entries and your head reference from this device.');
                if (ok) {
                  await deleteAllData(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data deleted')));
                  }
                }
              },
              child: const Text('Delete all data'),
            ),
          ),
        ]),
      ),

      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Privacy'),
          const Text(
            'The camera is used only during setup and sessions. Video is analysed on this device and never stored. Only summary numbers, journal notes and your head reference are saved, on this phone.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final ok = await confirmDialog(context, 'Withdraw consent?',
                    'All your data will be deleted and the app will ask for consent again.');
                if (ok) {
                  await deleteAllData(ref);
                  await ref.read(prefsProvider).remove(kConsentKey);
                  consentNotifier.value = false; // consent screen khul jayegi
                }
              },
              child: const Text('Withdraw consent and delete data'),
            ),
          ),
        ]),
      ),

      const Text(
        'This app measures visible eye and head behaviour. It does not measure consciousness, thoughts or meditation quality.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ]);
  }
}