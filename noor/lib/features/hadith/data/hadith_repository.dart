import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';
import '../domain/hadith_models.dart';

final hadithRepositoryProvider = Provider<HadithRepository>((ref) {
  return HadithRepository(ref.watch(dioClientProvider), AppDatabase.instance);
});

class HadithRepository {
  final DioClient _client;
  final AppDatabase _db;

  HadithRepository(this._client, this._db);

  /// Fetches Hadiths from fawazahmed0 jsDelivr CDN API (Section 1) with offline SQLite cache
  /// and falls back to bundled Nawawi 40 JSON if offline.
  Future<List<HadithEntry>> getCollectionHadiths(
    HadithCollectionMeta meta,
  ) async {
    try {
      const baseCdn =
          'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';
      final araUrl = '$baseCdn/${meta.araEdition}/sections/1.json';
      final engUrl = '$baseCdn/${meta.engEdition}/sections/1.json';

      final araData = await _client.getWithCache(
        araUrl,
        cacheKey: 'hadith_${meta.id}_ara_s1',
      );
      final engData = await _client.getWithCache(
        engUrl,
        cacheKey: 'hadith_${meta.id}_eng_s1',
      );

      final List araList = araData['hadiths'] as List? ?? [];
      final List engList = engData['hadiths'] as List? ?? [];
      final count =
          araList.length < engList.length ? araList.length : engList.length;

      return List.generate(count, (i) {
        final a = araList[i] as Map<String, dynamic>;
        final e = engList[i] as Map<String, dynamic>;
        final num = a['hadithnumber'] as int? ?? (i + 1);
        return HadithEntry(
          number: num,
          collectionId: meta.id,
          arabic: a['text'] as String? ?? '',
          translation: e['text'] as String? ?? '',
          reference: '${meta.nameEn} #$num',
        );
      });
    } catch (_) {
      final raw = await rootBundle.loadString('assets/data/hadith_nawawi_40.json');
      final List list = jsonDecode(raw) as List;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return HadithEntry(
          number: m['number'] as int,
          collectionId: meta.id,
          arabic: m['arabic'] as String,
          translation: m['english'] as String,
          reference: m['reference'] as String,
        );
      }).toList();
    }
  }

  Future<void> toggleFavorite(HadithEntry entry) async {
    final db = await _db.database;
    final id = '${entry.collectionId}_${entry.number}';
    final existing = await db.query(
      'hadith_favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (existing.isNotEmpty) {
      await db.delete('hadith_favorites', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.insert(
        'hadith_favorites',
        {
          'id': id,
          'collection': entry.collectionId,
          'hadith_number': entry.number,
          'arabic': entry.arabic,
          'translation': entry.translation,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<HadithEntry>> getFavorites() async {
    final db = await _db.database;
    final rows = await db.query('hadith_favorites', orderBy: 'created_at DESC');
    return rows
        .map(
          (r) => HadithEntry(
            number: r['hadith_number'] as int,
            collectionId: r['collection'] as String,
            arabic: r['arabic'] as String,
            translation: r['translation'] as String,
            reference: '${r['collection']} #${r['hadith_number']}',
          ),
        )
        .toList();
  }
}
