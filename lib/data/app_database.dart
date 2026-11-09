import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'drishti.db');
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at INTEGER NOT NULL,
          planned_sec INTEGER NOT NULL,
          actual_sec INTEGER NOT NULL,
          eyes_closed INTEGER NOT NULL,
          blink_rate REAL,
          gaze_stability REAL,
          tracking_quality REAL,
          posture_reminders INTEGER,
          pattern TEXT
        )''');
      await d.execute('''
        CREATE TABLE journal(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          mood TEXT NOT NULL,
          note TEXT NOT NULL
        )''');
    });
  }

  Future<int> insertSession(SessionRecord s) async =>
      (await db).insert('sessions', s.toMap());

  Future<List<SessionRecord>> sessions() async {
    final rows = await (await db).query('sessions', orderBy: 'started_at DESC');
    return rows.map(SessionRecord.fromMap).toList();
  }

  Future<int> insertJournal(JournalEntry e) async =>
      (await db).insert('journal', e.toMap());

  Future<List<JournalEntry>> journal() async {
    final rows = await (await db).query('journal', orderBy: 'created_at DESC');
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<void> deleteJournal(int id) async {
    await (await db).delete('journal', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final d = await db;
    await d.delete('sessions');
    await d.delete('journal');
  }
}