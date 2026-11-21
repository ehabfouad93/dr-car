import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/models.dart';

/// Local scan history (SQLite). Every scan is saved, and always before a clear.
class HistoryRepo {
  Database? _db;

  Future<Database> get _database async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'logan_doctor.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE scans (id INTEGER PRIMARY KEY AUTOINCREMENT, time TEXT NOT NULL, json TEXT NOT NULL)',
      ),
    );
  }

  Future<void> save(ScanResult r) async {
    final db = await _database;
    await db.insert('scans', {'time': r.time.toIso8601String(), 'json': r.toJsonString()});
  }

  Future<List<ScanResult>> all() async {
    final db = await _database;
    final rows = await db.query('scans', orderBy: 'id DESC', limit: 100);
    return rows.map((r) => ScanResult.fromJsonString(r['json'] as String)).toList();
  }
}
