import '../data/models.dart';
import '../vision/measurements.dart';

const int kMinBaselineSessions = 5;
const double kMinQuality = 0.6;

class SessionInsights {
  final String? pattern; // null = not enough reliable data
  final String patternWhy;
  final String? attention; // null = could not be estimated
  final String attentionNote;
  final String? cognitive; // null = not available
  final String baselineText;

  const SessionInsights({
    required this.pattern,
    required this.patternWhy,
    required this.attention,
    required this.attentionNote,
    required this.cognitive,
    required this.baselineText,
  });
}

double? _headVariability(SessionMeasurements m) {
  if (m.alignedSec == null) return null;
  final t = m.alignedSec! + m.slightSec! + m.deviatedSec!;
  if (t == 0) return null;
  return (m.slightSec! * 0.5 + m.deviatedSec!) / t; // 0 = steady, 1 = always deviated
}

// ---------- Pattern (Model 4 aane par ye function replace hoga) ----------
(String?, String) classifyPattern(SessionMeasurements m,
    {required bool eyesClosed}) {
  if (m.trackingQuality < kMinQuality || m.faceVisibleFraction < 0.6) {
    return (null, 'Tracking quality was too low to describe this session.');
  }
  final scores = <double>[];
  final signals = <String>[];
  if (m.gazeStability != null) {
    scores.add(1 - m.gazeStability!);
    signals.add('gaze variation');
  }
  final head = _headVariability(m);
  if (head != null) {
    scores.add(head);
    signals.add('head movement');
  }
  if (scores.isEmpty) {
    return (null, 'No reliable eye or head signals were available.');
  }
  final v = scores.reduce((a, b) => a + b) / scores.length;
  final label = v < 0.25
      ? 'Relatively stable'
      : v < 0.5
          ? 'Moderately variable'
          : 'Highly variable';
  var why = 'Contributing signals: ${signals.join(', ')}.';
  if (eyesClosed) {
    why += ' Eye measurements are unavailable with eyes closed.';
  }
  return (label, why);
}

// ---------- Attention stability (eyes-open only) ----------
(String?, String) attentionStability(SessionMeasurements m,
    {required bool eyesClosed}) {
  if (eyesClosed) {
    return (null, 'Attention stability could not be estimated with eyes closed.');
  }
  if (m.gazeStability == null || m.trackingQuality < kMinQuality) {
    return (null, 'Not enough reliable gaze data in this session.');
  }
  final head = _headVariability(m);
  final score = m.gazeStability! - 0.3 * (head ?? 0);
  final label = score >= 0.6 ? 'Relatively consistent' : 'More variable';
  final note = head == null
      ? 'Based on gaze stability.'
      : 'Based on gaze stability and head movement.';
  return (label, note);
}

// ---------- Cognitive wording (indirect indicator, rules) ----------
String? cognitiveWording(SessionMeasurements m,
    {required bool eyesClosed, required int actualSec}) {
  if (eyesClosed ||
      m.gazeStability == null ||
      m.saccadeCount == null ||
      m.trackingQuality < kMinQuality ||
      actualSec < 60) {
    return null;
  }
  final perMin = m.saccadeCount! / (actualSec / 60);
  if (perMin > 40 || m.gazeStability! < 0.4) {
    return 'Behavioural pattern may indicate increased visual activity.';
  }
  if (perMin > 20) {
    return 'Behavioural pattern may indicate slightly increased visual activity.';
  }
  return 'Behavioural pattern did not show increased visual activity.';
}

// ---------- Baseline (history = is session se PEHLE ke sessions, naye pehle) ----------
String _baselineText(SessionMeasurements m,
    {required bool eyesClosed,
    required int actualSec,
    required List<SessionRecord> history}) {
  final valid = history
      .where((s) =>
          s.eyesClosed == eyesClosed &&
          (s.trackingQuality ?? 0) >= kMinQuality)
      .take(10)
      .toList();
  if (valid.length < kMinBaselineSessions) {
    return 'Not enough history yet (${valid.length} of $kMinBaselineSessions similar valid sessions).';
  }
  final lines = <String>[];

  final gazes = valid.map((s) => s.gazeStability).whereType<double>().toList();
  if (m.gazeStability != null && gazes.length >= kMinBaselineSessions) {
    final avg = gazes.reduce((a, b) => a + b) / gazes.length;
    final diff = m.gazeStability! - avg;
    if (diff > 0.05) {
      lines.add('Your gaze was steadier than your recent average.');
    } else if (diff < -0.05) {
      lines.add('Your gaze was more variable than your recent average.');
    } else {
      lines.add('Your gaze was similar to your recent average.');
    }
  }

  final avgDur =
      valid.map((s) => s.actualSec).reduce((a, b) => a + b) / valid.length;
  if (actualSec > avgDur * 1.15) {
    lines.add('This session was longer than your recent average.');
  } else if (actualSec < avgDur * 0.85) {
    lines.add('This session was shorter than your recent average.');
  }

  return lines.isEmpty
      ? 'This session was similar to your recent average.'
      : lines.join(' ');
}

SessionInsights buildInsights(
  SessionMeasurements m, {
  required bool eyesClosed,
  required int actualSec,
  required List<SessionRecord> history,
}) {
  final (pattern, why) = classifyPattern(m, eyesClosed: eyesClosed);
  final (att, attNote) = attentionStability(m, eyesClosed: eyesClosed);
  return SessionInsights(
    pattern: pattern,
    patternWhy: why,
    attention: att,
    attentionNote: attNote,
    cognitive:
        cognitiveWording(m, eyesClosed: eyesClosed, actualSec: actualSec),
    baselineText: _baselineText(m,
        eyesClosed: eyesClosed, actualSec: actualSec, history: history),
  );
}

// ---------- Recommendations (transparent rules, naye sessions pehle) ----------
String? recommendationFor(List<SessionRecord> all) {
  final recent = all.take(5).toList();
  if (recent.length >= 3) {
    final early =
        recent.where((s) => s.actualSec < s.plannedSec * 0.8).length;
    if (early >= 3) {
      return recent.first.plannedSec >= 600
          ? 'Longer sessions often end early. Try 5 minutes, then build up gradually.'
          : 'Several recent sessions ended early. A shorter session may feel easier.';
    }
  }
  final last3 = all.take(3).toList();
  if (last3.length == 3 &&
      last3.every((s) => (s.postureReminders ?? 0) >= 2)) {
    return 'You received several posture reminders recently. Setting your head reference again in Setup may help.';
  }
  return null;
}