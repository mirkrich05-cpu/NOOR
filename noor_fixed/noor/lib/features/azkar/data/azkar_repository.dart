import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/azkar_models.dart';

final azkarRepositoryProvider = Provider<AzkarRepository>((ref) {
  return AzkarRepository(AppDatabase.instance);
});

class AzkarRepository {
  final AppDatabase _db;
  AzkarRepository(this._db);

  /// Loads 100% offline Azkar JSON bundled inside assets/data/azkar.json
  Future<List<DhikrItem>> loadAllAzkar() async {
    final raw = await rootBundle.loadString('assets/data/azkar.json');
    final List decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => DhikrItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getTodayTasbeehCount() async {
    final db = await _db.database;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await db.query(
      'tasbeeh_stats',
      where: 'date_key = ?',
      whereArgs: [todayKey],
    );
    if (rows.isEmpty) return 0;
    return rows.first['total_count'] as int;
  }

  Future<int> incrementTasbeeh() async {
    final db = await _db.database;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final current = await getTodayTasbeehCount();
    final updated = current + 1;
    await db.insert(
      'tasbeeh_stats',
      {'date_key': todayKey, 'total_count': updated},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return updated;
  }
}
