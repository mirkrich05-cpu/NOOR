import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';
import '../domain/quran_models.dart';

final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  return QuranRepository(ref.watch(dioClientProvider), AppDatabase.instance);
});

class QuranRepository {
  final DioClient _client;
  final AppDatabase _db;

  QuranRepository(this._client, this._db);

  /// Fetch all 114 Surahs from Al-Quran Cloud API with offline SQLite caching
  /// and bundled asset fallback (`assets/data/surah_index.json`).
  Future<List<SurahSummary>> getAllSurahs() async {
    try {
      final response = await _client.getWithCache(
        'https://api.alquran.cloud/v1/surah',
        cacheKey: 'quran_surah_list_v1',
      );
      final List data = response['data'] as List;
      return data
          .map((item) => SurahSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final raw =
            await rootBundle.loadString('assets/data/surah_index.json');
        final List list = jsonDecode(raw) as List;
        return list
            .map((item) => SurahSummary.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [
          SurahSummary(
            number: 1,
            nameArabic: 'سُورَةُ ٱلْفَاتِحَةِ',
            nameEnglish: 'Al-Faatiha',
            englishNameTranslation: 'The Opening',
            numberOfAyahs: 7,
            revelationType: 'Meccan',
          ),
          SurahSummary(
            number: 2,
            nameArabic: 'سُورَةُ البَقَرَةِ',
            nameEnglish: 'Al-Baqara',
            englishNameTranslation: 'The Cow',
            numberOfAyahs: 286,
            revelationType: 'Medinan',
          ),
          SurahSummary(
            number: 36,
            nameArabic: 'سُورَةُ يسٓ',
            nameEnglish: 'Yaseen',
            englishNameTranslation: 'Yaseen',
            numberOfAyahs: 83,
            revelationType: 'Meccan',
          ),
          SurahSummary(
            number: 67,
            nameArabic: 'سُورَةُ المُلۡكِ',
            nameEnglish: 'Al-Mulk',
            englishNameTranslation: 'The Sovereignty',
            numberOfAyahs: 30,
            revelationType: 'Meccan',
          ),
          SurahSummary(
            number: 112,
            nameArabic: 'سُورَةُ الإِخۡلَاصِ',
            nameEnglish: 'Al-Ikhlaas',
            englishNameTranslation: 'Sincerity',
            numberOfAyahs: 4,
            revelationType: 'Meccan',
          ),
        ];
      }
    }
  }

  /// Fetch a Surah with Uthmani script + selected translation + audio URLs
  Future<List<AyahItem>> getSurahAyahs({
    required int surahNumber,
    String translationEdition = 'en.sahih',
    ReciterOption reciter = const ReciterOption(
      id: 'ar.alafasy',
      nameEn: 'Mishary Rashid Alafasy',
      nameAr: 'مشاري راشد العفاسي',
      everyAyahSubfolder: 'Alafasy_128kbps',
    ),
  }) async {
    final url =
        'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-uthmani,$translationEdition';
    final cacheKey = 'surah_${surahNumber}_$translationEdition';

    final response = await _client.getWithCache(url, cacheKey: cacheKey);
    final List editions = response['data'] as List;
    final uthmaniData = editions[0] as Map<String, dynamic>;
    final transData = editions[1] as Map<String, dynamic>;

    final String surahAr = uthmaniData['name'] as String? ?? '';
    final String surahEn = uthmaniData['englishName'] as String? ?? '';
    final List uthmaniAyahs = uthmaniData['ayahs'] as List;
    final List transAyahs = transData['ayahs'] as List;

    final List<AyahItem> result = [];
    for (int i = 0; i < uthmaniAyahs.length; i++) {
      final u = uthmaniAyahs[i] as Map<String, dynamic>;
      final t = transAyahs[i] as Map<String, dynamic>;
      final int ayahInSurah = u['numberInSurah'] as int;

      final sPad = surahNumber.toString().padLeft(3, '0');
      final aPad = ayahInSurah.toString().padLeft(3, '0');
      final everyAyahUrl =
          'https://everyayah.com/data/${reciter.everyAyahSubfolder}/$sPad$aPad.mp3';

      result.add(
        AyahItem(
          numberInQuran: u['number'] as int,
          numberInSurah: ayahInSurah,
          surahNumber: surahNumber,
          surahNameArabic: surahAr,
          surahNameEnglish: surahEn,
          textUthmani: u['text'] as String,
          translationText: t['text'] as String,
          juz: u['juz'] as int,
          page: u['page'] as int,
          audioUrl: everyAyahUrl,
        ),
      );
    }
    return result;
  }

  /// Fetch Ayahs by Juz (1..30)
  Future<List<AyahItem>> getJuzAyahs(
    int juzNumber, {
    String translationEdition = 'en.sahih',
    ReciterOption reciter = const ReciterOption(
      id: 'ar.alafasy',
      nameEn: 'Mishary Rashid Alafasy',
      nameAr: 'مشاري راشد العفاسي',
      everyAyahSubfolder: 'Alafasy_128kbps',
    ),
  }) async {
    final uthmaniResp = await _client.getWithCache(
      'https://api.alquran.cloud/v1/juz/$juzNumber/quran-uthmani',
      cacheKey: 'juz_${juzNumber}_uthmani',
    );
    final transResp = await _client.getWithCache(
      'https://api.alquran.cloud/v1/juz/$juzNumber/$translationEdition',
      cacheKey: 'juz_${juzNumber}_$translationEdition',
    );

    final List uList = uthmaniResp['data']['ayahs'] as List;
    final List tList = transResp['data']['ayahs'] as List;

    return List.generate(uList.length, (i) {
      final u = uList[i] as Map<String, dynamic>;
      final t = tList[i] as Map<String, dynamic>;
      final surahObj = u['surah'] as Map<String, dynamic>;
      final sNum = surahObj['number'] as int;
      final aNum = u['numberInSurah'] as int;
      final sPad = sNum.toString().padLeft(3, '0');
      final aPad = aNum.toString().padLeft(3, '0');

      return AyahItem(
        numberInQuran: u['number'] as int,
        numberInSurah: aNum,
        surahNumber: sNum,
        surahNameArabic: surahObj['name'] as String,
        surahNameEnglish: surahObj['englishName'] as String,
        textUthmani: u['text'] as String,
        translationText: t['text'] as String,
        juz: u['juz'] as int,
        page: u['page'] as int,
        audioUrl:
            'https://everyayah.com/data/${reciter.everyAyahSubfolder}/$sPad$aPad.mp3',
      );
    });
  }

  /// Fetch Ayahs by Mushaf Page (1..604)
  Future<List<AyahItem>> getPageAyahs(
    int pageNumber, {
    String translationEdition = 'en.sahih',
    ReciterOption reciter = const ReciterOption(
      id: 'ar.alafasy',
      nameEn: 'Mishary Rashid Alafasy',
      nameAr: 'مشاري راشد العفاسي',
      everyAyahSubfolder: 'Alafasy_128kbps',
    ),
  }) async {
    final uthmaniResp = await _client.getWithCache(
      'https://api.alquran.cloud/v1/page/$pageNumber/quran-uthmani',
      cacheKey: 'page_${pageNumber}_uthmani',
    );
    final transResp = await _client.getWithCache(
      'https://api.alquran.cloud/v1/page/$pageNumber/$translationEdition',
      cacheKey: 'page_${pageNumber}_$translationEdition',
    );

    final List uList = uthmaniResp['data']['ayahs'] as List;
    final List tList = transResp['data']['ayahs'] as List;

    return List.generate(uList.length, (i) {
      final u = uList[i] as Map<String, dynamic>;
      final t = tList[i] as Map<String, dynamic>;
      final surahObj = u['surah'] as Map<String, dynamic>;
      final sNum = surahObj['number'] as int;
      final aNum = u['numberInSurah'] as int;
      final sPad = sNum.toString().padLeft(3, '0');
      final aPad = aNum.toString().padLeft(3, '0');

      return AyahItem(
        numberInQuran: u['number'] as int,
        numberInSurah: aNum,
        surahNumber: sNum,
        surahNameArabic: surahObj['name'] as String,
        surahNameEnglish: surahObj['englishName'] as String,
        textUthmani: u['text'] as String,
        translationText: t['text'] as String,
        juz: u['juz'] as int,
        page: u['page'] as int,
        audioUrl:
            'https://everyayah.com/data/${reciter.everyAyahSubfolder}/$sPad$aPad.mp3',
      );
    });
  }

  /// Fetch Tafsir for a specific verse from Quran.com API v4 (e.g. Ibn Kathir 169 or Al-Muyassar 16)
  Future<String> getAyahTafsir({
    required int surahNumber,
    required int ayahNumber,
    int tafsirId = 169, // 169 = Ibn Kathir (English), 16 = Tafsir Muyassar (Arabic)
  }) async {
    final verseKey = '$surahNumber:$ayahNumber';
    final url =
        'https://api.quran.com/api/v4/tafsirs/$tafsirId/by_ayah/$verseKey';
    final response = await _client.getWithCache(
      url,
      cacheKey: 'tafsir_${tafsirId}_$verseKey',
    );
    final rawHtml = response['tafsir']?['text'] as String? ?? '';
    return rawHtml.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Search Quran by keyword (Arabic or English)
  Future<List<Map<String, dynamic>>> searchQuran(
    String query, {
    String edition = 'all',
  }) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final url = 'https://api.alquran.cloud/v1/search/$encoded/all/$edition';
    final response = await _client.getWithCache(
      url,
      cacheKey: 'search_${edition}_$encoded',
    );
    final List matches = response['data']?['matches'] as List? ?? [];
    return matches.cast<Map<String, dynamic>>();
  }

  /// Returns cached audio file path if already downloaded, or null otherwise
  Future<String?> getCachedAudioPathIfExists({
    required ReciterOption reciter,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/quran_audio/${reciter.id}/${surahNumber}_$ayahNumber.mp3';
    if (await File(filePath).exists()) {
      return filePath;
    }
    return null;
  }

  /// Download Ayah MP3 for offline playback
  Future<String> downloadOrGetCachedAudioPath({
    required ReciterOption reciter,
    required int surahNumber,
    required int ayahNumber,
    required String remoteUrl,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/quran_audio/${reciter.id}');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final filePath = '${audioDir.path}/${surahNumber}_$ayahNumber.mp3';
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    await _client.rawDio.download(remoteUrl, filePath);
    return filePath;
  }

  /// Bookmarks CRUD
  Future<List<QuranBookmark>> getBookmarks() async {
    final db = await _db.database;
    final rows = await db.query('quran_bookmarks', orderBy: 'created_at DESC');
    return rows.map((r) => QuranBookmark.fromMap(r)).toList();
  }

  Future<void> upsertBookmark(QuranBookmark bookmark) async {
    final db = await _db.database;
    await db.insert(
      'quran_bookmarks',
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> toggleBookmark(QuranBookmark bookmark) async {
    final db = await _db.database;
    final existing = await db.query(
      'quran_bookmarks',
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
    if (existing.isNotEmpty) {
      await db.delete(
        'quran_bookmarks',
        where: 'id = ?',
        whereArgs: [bookmark.id],
      );
    } else {
      await db.insert(
        'quran_bookmarks',
        bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Save & Load Last-Read Position
  Future<void> saveLastRead({
    required int surahNumber,
    required String surahName,
    required int ayahNumber,
    required int pageNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_surah', surahNumber);
    await prefs.setString('last_read_surah_name', surahName);
    await prefs.setInt('last_read_ayah', ayahNumber);
    await prefs.setInt('last_read_page', pageNumber);
  }

  Future<Map<String, dynamic>?> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt('last_read_surah');
    if (surah == null) return null;
    return {
      'surahNumber': surah,
      'surahName': prefs.getString('last_read_surah_name') ?? 'Al-Faatiha',
      'ayahNumber': prefs.getInt('last_read_ayah') ?? 1,
      'pageNumber': prefs.getInt('last_read_page') ?? 1,
    };
  }
}
