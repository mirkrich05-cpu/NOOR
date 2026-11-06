import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(AppDatabase.instance);
});

class DioClient {
  final Dio _dio;
  final AppDatabase _db;

  DioClient(this._db)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Accept': 'application/json'},
          ),
        );

  /// Performs an offline-first GET request.
  /// If network succeeds, caches response in SQLite.
  /// If offline or request fails, returns cached SQLite payload if available.
  Future<dynamic> getWithCache(
    String url, {
    required String cacheKey,
    Map<String, dynamic>? queryParameters,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _db.getCache(cacheKey);
      if (cached != null) {
        // Refresh silently in background if possible
        _refreshSilently(url, cacheKey, queryParameters);
        return cached;
      }
    }

    try {
      final response = await _dio.get(url, queryParameters: queryParameters);
      if (response.statusCode == 200 && response.data != null) {
        await _db.putCache(cacheKey, response.data);
        return response.data;
      }
    } catch (e) {
      final fallback = await _db.getCache(cacheKey);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<void> _refreshSilently(
    String url,
    String cacheKey,
    Map<String, dynamic>? queryParameters,
  ) async {
    try {
      final response = await _dio.get(url, queryParameters: queryParameters);
      if (response.statusCode == 200 && response.data != null) {
        await _db.putCache(cacheKey, response.data);
      }
    } catch (_) {}
  }

  Dio get rawDio => _dio;
}
