import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../analysis/summary_logic.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/bar_chart.dart';
import '../../shared/widgets.dart';

typedef _Bucket = ({double minutes, double? gaze});

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String view = 'week';

  _Bucket _bucket(List<SessionRecord> all, DateTime start, DateTime end) {
    final inRange = all
        .where((s) =>
            !s.startedAt.isBefore(start) && s.startedAt.isBefore(end))
        .toList();
    final minutes =
        inRange.fold<int>(0, (a, s) => a + s.actualSec) / 60.0;
    final gazes = inRange
        .where((s) =>
            (s.trackingQuality ?? 0) >= kMinQuality && s.gazeStability != null)
        .map((s) => s.gazeStability!)
        .toList();
    final gaze =
        gazes.isEmpty ? null : gazes.reduce((a, b) => a + b) / gazes.length;
    return (minutes: minutes, gaze: gaze);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(sessionsProvider).maybeWhen(
          data: (l) => l,
          orElse: () => <SessionRecord>[],
        );
    final since = ref.watch(baselineSinceProvider);
    final week = view == 'week';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <_Bucket>[];
    final labels = <String>[];
    if (week) {
      for (var i = 6; i >= 0; i--) {
        final s = DateTime(today.year, today.month, today.day - i);
        final e = DateTime(s.year, s.month, s.day + 1);
        buckets.add(_bucket(all, s, e));
        labels.add('MTWTFSS'[s.weekday - 1]);
      }
    } else {
      for (var i = 3; i >= 0; i--) {
        final e = DateTime(today.year, today.month, today.day + 1 - 7 * i);
        final s = DateTime(e.year, e.month, e.day - 7);
        buckets.add(_bucket(all, s, e));
        labels.add('W${4 - i}');
      }
    }
    final maxMin = week ? 60.0 : 300.0;
    final timeValues =
        buckets.map<double?>((b) => (b.minutes / maxMin).clamp(0.0, 1.0)).toList();
    final gazeValues = buckets.map<double?>((b) => b.gaze).toList();

    // baseline
    final valid = all
        .where((s) =>
            s.startedAt.millisecondsSinceEpoch >= since &&
            (s.trackingQuality ?? 0) >= kMinQuality &&
            s.gazeStability != null)
        .take(10)
        .toList();
    final enough = valid.length >= kMinBaselineSessions;
    final avgGaze = enough
        ? valid.map((s) => s.gazeStability!).reduce((a, b) => a + b) /
            valid.length
        : null;
    final avgDur = enough
        ? valid.map((s) => s.actualSec).reduce((a, b) => a + b) /
            valid.length /
            60
        : null;

    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Insights',
          style: TextStyle(fontSize: 28, fontFamily: 'serif')),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'week', label: Text('Week')),
          ButtonSegment(value: 'month', label: Text('Month')),
        ],
        selected: {view},
        onSelectionChanged: (s) => setState(() => view = s.first),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Time meditated'),
          SimpleBarChart(values: timeValues, labels: labels),
          const SizedBox(height: 6),
          Text(
              week
                  ? 'Bar height: minutes per day (full = 60 min).'
                  : 'Bar height: minutes per week (full = 300 min).',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Gaze stability trend (eyes open)'),
          SimpleBarChart(values: gazeValues, labels: labels),
          const SizedBox(height: 6),
          const Text('Empty box = no reliable data, not zero.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel('Your baseline · ${valid.length} valid sessions'),
          if (!enough)
            Text(
              'Not enough history yet. A baseline needs $kMinBaselineSessions valid eyes-open sessions.',
              style: const TextStyle(color: AppColors.muted),
            )
          else ...[
            MetricRow('Typical gaze stability',
                '${(avgGaze! * 100).round()}%'),
            MetricRow('Typical session length',
                '${avgDur!.toStringAsFixed(0)} min'),
          ],
        ]),
      ),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final ok = await confirmDialog(context, 'Reset baseline?',
                  'Your personal reference will be cleared. Past sessions stay in History.');
              if (ok) ref.read(baselineSinceProvider.notifier).reset();
            },
            child: const Text('Reset baseline'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final ok = await confirmDialog(context, 'Delete all data?',
                  'This removes all sessions and journal entries from this device.');
              if (ok) {
                await deleteAllData(ref);
              }
            },
            child: const Text('Delete my data'),
          ),
        ),
      ]),
    ]);
  }
}