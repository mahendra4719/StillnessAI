class SessionRecord {
  final int? id;
  final DateTime startedAt;
  final int plannedSec, actualSec;
  final bool eyesClosed;
  final double? blinkRate, gazeStability, trackingQuality; // null = not available
  final int? postureReminders;
  final String? pattern;

  const SessionRecord({
    this.id,
    required this.startedAt,
    required this.plannedSec,
    required this.actualSec,
    required this.eyesClosed,
    this.blinkRate,
    this.gazeStability,
    this.trackingQuality,
    this.postureReminders,
    this.pattern,
  });

  Map<String, Object?> toMap() => {
        'started_at': startedAt.millisecondsSinceEpoch,
        'planned_sec': plannedSec,
        'actual_sec': actualSec,
        'eyes_closed': eyesClosed ? 1 : 0,
        'blink_rate': blinkRate,
        'gaze_stability': gazeStability,
        'tracking_quality': trackingQuality,
        'posture_reminders': postureReminders,
        'pattern': pattern,
      };

  factory SessionRecord.fromMap(Map<String, Object?> m) => SessionRecord(
        id: m['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        plannedSec: m['planned_sec'] as int,
        actualSec: m['actual_sec'] as int,
        eyesClosed: (m['eyes_closed'] as int) == 1,
        blinkRate: (m['blink_rate'] as num?)?.toDouble(),
        gazeStability: (m['gaze_stability'] as num?)?.toDouble(),
        trackingQuality: (m['tracking_quality'] as num?)?.toDouble(),
        postureReminders: m['posture_reminders'] as int?,
        pattern: m['pattern'] as String?,
      );
}

class JournalEntry {
  final int? id;
  final DateTime createdAt;
  final String mood, note;
  const JournalEntry({
    this.id,
    required this.createdAt,
    required this.mood,
    required this.note,
  });

  Map<String, Object?> toMap() => {
        'created_at': createdAt.millisecondsSinceEpoch,
        'mood': mood,
        'note': note,
      };

  factory JournalEntry.fromMap(Map<String, Object?> m) => JournalEntry(
        id: m['id'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        mood: m['mood'] as String,
        note: m['note'] as String,
      );
}