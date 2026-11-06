import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';

final zakatRepositoryProvider = Provider<ZakatRepository>((ref) {
  return ZakatRepository(ref.watch(dioClientProvider), AppDatabase.instance);
});

class MetalPrices {
  final double goldGramPrice;
  final double silverGramPrice;
  final String currency;

  const MetalPrices({
    required this.goldGramPrice,
    required this.silverGramPrice,
    required this.currency,
  });
}

class ZakatRepository {
  final DioClient _client;
  final AppDatabase _db;

  ZakatRepository(this._client, this._db);

  static const Map<String, double> _defaultGoldPerGram = {
    'ILS': 315.0,
    'USD': 85.0,
    'EUR': 79.0,
    'JOD': 60.3,
  };

  static const Map<String, double> _defaultSilverPerGram = {
    'ILS': 3.80,
    'USD': 1.02,
    'EUR': 0.95,
    'JOD': 0.72,
  };

  /// Fetches live gold & silver prices per gram from public currency API
  /// (cdn.jsdelivr.net/npm/@fawazahmed0/currency-api) with fallback defaults.
  Future<MetalPrices> fetchLiveMetalPrices(String currency) async {
    final curLower = currency.toLowerCase();
    try {
      final data = await _client.getWithCache(
        'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/xau.json',
        cacheKey: 'metal_xau_$curLower',
      );
      final xauMap = data['xau'] as Map<String, dynamic>?;
      if (xauMap != null && xauMap[curLower] != null) {
        // 1 troy ounce = 31.1034768 grams
        final ouncePrice = (xauMap[curLower] as num).toDouble();
        final goldGram = ouncePrice / 31.1034768;
        final silverGram = goldGram / 80.0;
        return MetalPrices(
          goldGramPrice: goldGram,
          silverGramPrice: silverGram,
          currency: currency,
        );
      }
    } catch (_) {}

    return MetalPrices(
      goldGramPrice: _defaultGoldPerGram[currency] ?? 85.0,
      silverGramPrice: _defaultSilverPerGram[currency] ?? 1.02,
      currency: currency,
    );
  }

  Future<void> saveYearlyZakatRecord({
    required String hijriDate,
    required String currency,
    required double netWealth,
    required double nisabUsed,
    required double zakatDue,
  }) async {
    final db = await _db.database;
    await db.insert(
      'zakat_records',
      {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'date_iso': DateTime.now().toIso8601String(),
        'hijri_date': hijriDate,
        'currency': currency,
        'net_wealth': netWealth,
        'nisab_used': nisabUsed,
        'zakat_due': zakatDue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSavedRecords() async {
    final db = await _db.database;
    return db.query('zakat_records', orderBy: 'date_iso DESC');
  }
}
