import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../data/format.dart';
import '../../data/providers.dart';
import '../../shared/heatmap_calendar.dart';
import '../../shared/widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int minutes = 10;
  bool eyesClosed = true;
  bool _recDismissed = false;

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastSessionProvider);
    final stats = ref.watch(statsProvider);
    final calendar = ref.watch(minutesPerDayProvider);
    final rec = ref.watch(recommendationProvider);

    return ListView(padding: const EdgeInsets.all(22), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Good evening', style: TextStyle(fontSize: 28, fontFamily: 'serif')),
          SizedBox(height: 4),
          Text('Drishti', style: TextStyle(color: AppColors.muted)),
        ]),
        if (stats.streak > 0) Pill('${stats.streak} day streak'),
      ]),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('New session'),
          Wrap(spacing: 8, children: [
            for (final m in [5, 10, 20])
              ChoiceChip(
                label: Text('$m min'),
                selected: minutes == m,
                onSelected: (_) => setState(() => minutes = m),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Eyes closed'),
              selected: eyesClosed,
              onSelected: (_) => setState(() => eyesClosed = true),
            ),
            ChoiceChip(
              label: const Text('Eyes open'),
              selected: !eyesClosed,
              onSelected: (_) => setState(() => eyesClosed = false),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ref.read(sessionConfigProvider.notifier).set(minutes, eyesClosed);
                context.push('/setup');
              },
              child: const Text('Start session'),
            ),
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel(last == null
              ? 'Last session'
              : 'Last session · ${last.eyesClosed ? 'eyes closed' : 'eyes open'}'),
          if (last == null)
            const Text('No sessions yet.', style: TextStyle(color: AppColors.muted))
          else ...[
            MetricRow('Duration', fmtDuration(last.actualSec)),
            MetricRow('Blink rate',
                last.blinkRate == null ? 'Not available' : '${last.blinkRate!.toStringAsFixed(0)} / min'),
            MetricRow('Gaze stability',
                last.gazeStability == null ? 'Not available' : '${(last.gazeStability! * 100).round()}%'),
            MetricRow('Pattern', last.pattern ?? 'Not available'),
          ],
          const SizedBox(height: 8),
          const Text(
            'Describes visible eye and head behaviour, not your inner state.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ]),
      ),

      if (rec != null && !_recDismissed)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Suggestion'),
            Text(rec),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton(
                  onPressed: () => context.push('/breathing'),
                  child: const Text('Try breathing')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () => setState(() => _recDismissed = true),
                  child: const Text('Dismiss')),
            ]),
          ]),
        ),
        
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Your practice'),
          HeatmapCalendar(minutes: calendar),
        ]),
      ),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.push('/breathing'),
            child: const Text('Breathing'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.go('/journal'),
            child: const Text('Write journal'),
          ),
        ),
      ]),
    ]);
  }
}