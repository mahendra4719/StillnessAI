import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  Widget _tile(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastResultProvider);

    final m = ref.watch(lastMeasurementsProvider);
    final ins = ref.watch(lastInsightsProvider);

    const na = 'Not available';
    final closedNote = (last?.eyesClosed ?? false) ? 'Not available (eyes closed)' : na;

    final blinks = (m == null || m.blinkCount == null)
        ? closedNote
        : m.blinkRate == null
            ? '${m.blinkCount} · rate needs more data'
            : '${m.blinkCount} · ${m.blinkRate!.toStringAsFixed(0)} / min';
    final blinkDur = m?.avgBlinkMs == null ? closedNote : '${m!.avgBlinkMs} ms';
    final gaze = m?.gazeStability == null
        ? closedNote
        : '${(m!.gazeStability! * 100).round()}%';
    final head = (m == null || m.alignedSec == null)
        ? na
        : '${m.alignedSec}s aligned · ${m.deviatedSec}s deviated';
    final fixations = (m == null || m.fixationCount == null)
        ? closedNote
        : '${m.fixationCount}${m.avgFixationMs == null ? '' : ' · avg ${m.avgFixationMs} ms'}';
    final saccades = (m == null || m.saccadeCount == null)
        ? closedNote
        : '${m.saccadeCount}';
    final quality = (m == null || last == null || last.trackingQuality == null)
        ? na
        : '${(m.trackingQuality * 100).round()}%';

    return Scaffold(
      appBar: AppBar(title: const Text('Session summary'), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        Text(
          last == null
              ? ''
              : '${(last.actualSec / 60).ceil()} min · ${last.eyesClosed ? 'eyes closed' : 'eyes open'}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 8),
            ),
            alignment: Alignment.center,
            child: const Text('72', style: TextStyle(fontSize: 44, fontFamily: 'serif')),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Visual behaviour pattern'),
            Text(ins?.pattern ?? 'Not enough reliable data',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '${ins?.patternWhy ?? ''} Tracking quality $quality. Describes what the camera saw, not your inner state.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ]),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _tile('Blinks', blinks),
            _tile('Avg blink duration', blinkDur),
            _tile('Gaze stability', gaze),
            _tile('Head posture', head),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Fixations and saccades'),
            MetricRow('Fixations', fixations),
            MetricRow('Saccades', saccades),
          ]),
        ),
        
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Head posture'),
            MetricRow('Time aligned', m?.alignedSec == null ? na : '${m!.alignedSec} s'),
            MetricRow('Slight deviation', m?.slightSec == null ? na : '${m!.slightSec} s'),
            MetricRow('Sustained deviation', m?.deviatedSec == null ? na : '${m!.deviatedSec} s'),
            MetricRow('Reminders given',
                last?.postureReminders == null ? na : '${last!.postureReminders}'),
            if (m?.headUsedSessionMedian ?? false)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No head reference was set, so your typical position in this session was used.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
          ]),
        ),
        
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Attention and cognitive indicators'),
            MetricRow('Attention stability',
                ins?.attention ?? 'Could not be estimated'),
            MetricRow('Visual activity', ins?.cognitive ?? na),
            const SizedBox(height: 8),
            Text(
              '${ins?.attentionNote ?? ''} Indirect behavioural indicators. They cannot measure thoughts or cognitive load.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ]),
        ),
        
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Compared with your baseline'),
            Text(ins?.baselineText ?? 'Not enough history yet.'),
          ]),
        ),
        
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go('/journal'),
              child: const Text('Add journal note'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Done'),
            ),
          ),
        ]),
      ]),
    );
  }
}