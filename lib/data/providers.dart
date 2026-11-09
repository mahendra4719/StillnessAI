import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../vision/measurements.dart';
import '../audio/audio_manager.dart';
import '../analysis/summary_logic.dart';
import 'app_database.dart';
import 'models.dart';


final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

// ---- data ----
final sessionsProvider = FutureProvider.autoDispose<List<SessionRecord>>(
    (ref) => AppDatabase.instance.sessions());

final journalProvider = FutureProvider.autoDispose<List<JournalEntry>>(
    (ref) => AppDatabase.instance.journal());

List<SessionRecord> _sessionList(Ref ref) => ref
    .watch(sessionsProvider)
    .maybeWhen(data: (l) => l, orElse: () => <SessionRecord>[]);

final lastSessionProvider = Provider.autoDispose<SessionRecord?>((ref) {
  final l = _sessionList(ref);
  return l.isEmpty ? null : l.first;
});

final minutesPerDayProvider = Provider.autoDispose<Map<DateTime, int>>((ref) {
  final map = <DateTime, int>{};
  for (final s in _sessionList(ref)) {
    final d = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
    map[d] = (map[d] ?? 0) + (s.actualSec / 60).ceil();
  }
  return map;
});

class Stats {
  final int sessions, totalMin, avgMin, streak;
  const Stats(this.sessions, this.totalMin, this.avgMin, this.streak);
}

final statsProvider = Provider.autoDispose<Stats>((ref) {
  final list = _sessionList(ref);
  final totalSec = list.fold<int>(0, (a, s) => a + s.actualSec);
  final days = list
      .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
      .toSet();
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day);
  if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
  var streak = 0;
  while (days.contains(d)) {
    streak++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  final avg = list.isEmpty ? 0 : (totalSec / 60 / list.length).round();
  return Stats(list.length, totalSec ~/ 60, avg, streak);
});

// ---- session setup (Home -> Session) ----
class SessionConfig {
  final int minutes;
  final bool eyesClosed;
  const SessionConfig(this.minutes, this.eyesClosed);
}

class SessionConfigNotifier extends Notifier<SessionConfig> {
  @override
  SessionConfig build() => const SessionConfig(10, true);
  void set(int minutes, bool eyesClosed) =>
      state = SessionConfig(minutes, eyesClosed);
}

final sessionConfigProvider =
    NotifierProvider<SessionConfigNotifier, SessionConfig>(
        SessionConfigNotifier.new);

// ---- settings (saved in SharedPreferences) ----
class SettingsNotifier extends Notifier<Map<String, bool>> {
  static const keys = ['posture', 'breathing', 'onDevice', 'saveSummaries'];

  @override
  Map<String, bool> build() {
    final p = ref.read(prefsProvider);
    return {for (final k in keys) k: p.getBool(k) ?? true};
  }

  void set(String key, bool value) {
    ref.read(prefsProvider).setBool(key, value);
    state = {...state, key: value};
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Map<String, bool>>(SettingsNotifier.new);

// ---- abhi khatam hua session (Summary ke liye, DB me save ho ya na ho) ----
class LastResultNotifier extends Notifier<SessionRecord?> {
  @override
  SessionRecord? build() => null;
  void set(SessionRecord? r) => state = r;
}

final lastResultProvider =
    NotifierProvider<LastResultNotifier, SessionRecord?>(LastResultNotifier.new);

// ---- head reference (SharedPreferences me save) ----
class HeadReference {
  final double yaw, pitch, roll;
  const HeadReference(this.yaw, this.pitch, this.roll);
}

class HeadReferenceNotifier extends Notifier<HeadReference?> {
  @override
  HeadReference? build() {
    final p = ref.read(prefsProvider);
    final y = p.getDouble('ref_yaw');
    final x = p.getDouble('ref_pitch');
    final z = p.getDouble('ref_roll');
    if (y == null || x == null || z == null) return null;
    return HeadReference(y, x, z);
  }

  void set(HeadReference r) {
    final p = ref.read(prefsProvider);
    p.setDouble('ref_yaw', r.yaw);
    p.setDouble('ref_pitch', r.pitch);
    p.setDouble('ref_roll', r.roll);
    state = r;
  }

  void clear() {
    final p = ref.read(prefsProvider);
    p.remove('ref_yaw');
    p.remove('ref_pitch');
    p.remove('ref_roll');
    state = null;
  }
}

final headReferenceProvider =
    NotifierProvider<HeadReferenceNotifier, HeadReference?>(
        HeadReferenceNotifier.new);

// ---- abhi khatam hue session ki poori measurements (Summary ke liye) ----
class LastMeasurementsNotifier extends Notifier<SessionMeasurements?> {
  @override
  SessionMeasurements? build() => null;
  void set(SessionMeasurements? m) => state = m;
}

final lastMeasurementsProvider =
    NotifierProvider<LastMeasurementsNotifier, SessionMeasurements?>(
        LastMeasurementsNotifier.new);

// ---- ek hi audio manager poore app me ----
final audioManagerProvider = Provider<AudioManager>((ref) {
  final a = AudioManager();
  ref.onDispose(a.dispose);
  return a;
});

// ---- abhi khatam hue session ke insights (Summary ke liye) ----
class LastInsightsNotifier extends Notifier<SessionInsights?> {
  @override
  SessionInsights? build() => null;
  void set(SessionInsights? i) => state = i;
}

final lastInsightsProvider =
    NotifierProvider<LastInsightsNotifier, SessionInsights?>(
        LastInsightsNotifier.new);

// ---- baseline reset: is time se pehle ke sessions baseline me nahi ginte ----
class BaselineSinceNotifier extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).getInt('baseline_since') ?? 0;

  void reset() {
    final now = DateTime.now().millisecondsSinceEpoch;
    ref.read(prefsProvider).setInt('baseline_since', now);
    state = now;
  }
}

final baselineSinceProvider =
    NotifierProvider<BaselineSinceNotifier, int>(BaselineSinceNotifier.new);

// ---- Home ki suggestion ----
final recommendationProvider = Provider.autoDispose<String?>(
    (ref) => recommendationFor(_sessionList(ref)));

// ---- sab kuch delete karne ka ek hi tarika ----
Future<void> deleteAllData(WidgetRef ref) async {
  await AppDatabase.instance.deleteAll();
  ref.read(headReferenceProvider.notifier).clear();
  ref.read(lastResultProvider.notifier).set(null);
  ref.read(lastMeasurementsProvider.notifier).set(null);
  ref.read(lastInsightsProvider.notifier).set(null);
  ref.invalidate(sessionsProvider);
  ref.invalidate(journalProvider);
}