import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('noor_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Generic JSON cache table for offline-first API responses
    await db.execute('''
      CREATE TABLE api_cache (
        cache_key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Quran Bookmarks
    await db.execute('''
      CREATE TABLE quran_bookmarks (
        id TEXT PRIMARY KEY,
        surah_number INTEGER NOT NULL,
        surah_name TEXT NOT NULL,
        ayah_number INTEGER NOT NULL,
        ayah_text TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Favorite Hadiths
    await db.execute('''
      CREATE TABLE hadith_favorites (
        id TEXT PRIMARY KEY,
        collection TEXT NOT NULL,
        hadith_number INTEGER NOT NULL,
        arabic TEXT NOT NULL,
        translation TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Zakat Yearly Records
    await db.execute('''
      CREATE TABLE zakat_records (
        id TEXT PRIMARY KEY,
        date_iso TEXT NOT NULL,
        hijri_date TEXT NOT NULL,
        currency TEXT NOT NULL,
        net_wealth REAL NOT NULL,
        nisab_used REAL NOT NULL,
        zakat_due REAL NOT NULL
      )
    ''');

    // Tasbeeh Daily Stats
    await db.execute('''
      CREATE TABLE tasbeeh_stats (
        date_key TEXT PRIMARY KEY,
        total_count INTEGER NOT NULL
      )
    ''');
  }

  Future<void> putCache(String key, dynamic data) async {
    final db = await instance.database;
    await db.insert(
      'api_cache',
      {
        'cache_key': key,
        'payload': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> getCache(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'api_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['payload'] as String);
    }
    return null;
  }
}
