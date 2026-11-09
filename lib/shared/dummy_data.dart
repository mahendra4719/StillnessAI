import 'dart:math';

Map<DateTime, int> dummyMinutes() {
  final r = Random(7);
  final now = DateTime.now();
  final map = <DateTime, int>{};
  for (var i = 0; i < 130; i++) {
    final d = DateTime(now.year, now.month, now.day - i);
    map[d] = [0, 0, 0, 5, 10, 10, 15, 20, 20, 30, 45][r.nextInt(11)];
  }
  return map;
}