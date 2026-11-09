import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/format.dart';
import '../../data/providers.dart';
import '../../shared/heatmap_calendar.dart';
import '../../shared/widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.accent)),
            Text(l, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final calendar = ref.watch(minutesPerDayProvider);
    final sessions = ref.watch(sessionsProvider).maybeWhen(
          data: (l) => l.take(10).toList(),
          orElse: () => [],
        );

    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('History', style: TextStyle(fontSize: 28, fontFamily: 'serif')),
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Last 17 weeks'),
          HeatmapCalendar(minutes: calendar),
        ]),
      ),
      Row(children: [
        _stat('${stats.sessions}', 'Sessions'),
        _stat(fmtTotal(stats.totalMin), 'Total'),
        _stat('${stats.avgMin} min', 'Average'),
        _stat('${stats.streak}', 'Streak'),
      ]),
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Recent sessions'),
          if (sessions.isEmpty)
            const Text('No sessions yet.', style: TextStyle(color: AppColors.muted)),
          for (final s in sessions)
            MetricRow(
              fmtDate(s.startedAt),
              '${fmtDuration(s.actualSec)} · ${s.eyesClosed ? 'eyes closed' : 'eyes open'}',
            ),
        ]),
      ),
    ]);
  }
}