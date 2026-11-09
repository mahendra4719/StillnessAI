import 'package:flutter/material.dart';
import '../app/theme.dart';

class HeatmapCalendar extends StatelessWidget {
  final Map<DateTime, int> minutes;
  final int weeks;
  const HeatmapCalendar({super.key, required this.minutes, this.weeks = 17});

  static const _colors = [
    Color(0xFF1E3236), Color(0xFF2B5B4C), Color(0xFF3E8A6A),
    Color(0xFF66BC8C), Color(0xFFA8E6B8),
  ];
  Color _c(int m) => _colors[m == 0 ? 0 : m < 10 ? 1 : m < 20 ? 2 : m < 35 ? 3 : 4];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = DateTime(today.year, today.month, today.day - (today.weekday % 7));
    final start = DateTime(sunday.year, sunday.month, sunday.day - 7 * (weeks - 1));
    return LayoutBuilder(builder: (context, box) {
      const gap = 3.0;
      final cell = ((box.maxWidth - (weeks - 1) * gap) / weeks).floorToDouble();
      return Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var w = 0; w < weeks; w++)
              Column(children: [
                for (var d = 0; d < 7; d++) () {
                  final day = DateTime(start.year, start.month, start.day + w * 7 + d);
                  if (day.isAfter(today)) {
                    return SizedBox(width: cell, height: cell + gap);
                  }
                  final m = minutes[day] ?? 0;
                  return Tooltip(
                    message: '${day.day}/${day.month}: $m min',
                    child: Container(
                      margin: const EdgeInsets.only(bottom: gap),
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                          color: _c(m), borderRadius: BorderRadius.circular(3)),
                    ),
                  );
                }(),
              ]),
          ],
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('Less ', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          for (final c in _colors)
            Container(
              margin: const EdgeInsets.only(right: 3),
              width: 14, height: 14,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
          const Text(' More', style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
      ]);
    });
  }
}