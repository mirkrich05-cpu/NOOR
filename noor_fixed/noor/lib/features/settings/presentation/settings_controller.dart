import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../quran/data/quran_repository.dart';
import '../../quran/domain/quran_models.dart';

class AppSettingsState {
  final Locale locale;
  final ThemeMode themeMode;
  final double quranFontSize;
  final bool adhanNotificationsEnabled;

  const AppSettingsState({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    this.quranFontSize = 26.0,
    this.adhanNotificationsEnabled = true,
  });

  AppSettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    double? quranFontSize,
    bool? adhanNotificationsEnabled,
  }) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      quranFontSize: quranFontSize ?? this.quranFontSize,
      adhanNotificationsEnabled:
          adhanNotificationsEnabled ?? this.adhanNotificationsEnabled,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettingsState>((ref) {
  return SettingsController(ref);
});

class SettingsController extends StateNotifier<AppSettingsState> {
  final Ref _ref;

  SettingsController(this._ref) : super(const AppSettingsState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_lang') ?? 'en';
    final isDark = prefs.getBool('app_dark_mode');
    final fontSize = prefs.getDouble('quran_font_size') ?? 26.0;
    final notifs = prefs.getBool('adhan_notifs') ?? true;

    state = state.copyWith(
      locale: Locale(lang),
      themeMode: isDark == null
          ? ThemeMode.system
          : (isDark ? ThemeMode.dark : ThemeMode.light),
      quranFontSize: fontSize,
      adhanNotificationsEnabled: notifs,
    );
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', languageCode);
    state = state.copyWith(locale: Locale(languageCode));
  }

  Future<void> toggleDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_dark_mode', isDark);
    state = state.copyWith(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> setQuranFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('quran_font_size', size);
    state = state.copyWith(quranFontSize: size);
  }

  Future<void> setAdhanNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_notifs', enabled);
    state = state.copyWith(adhanNotificationsEnabled: enabled);
  }

  Future<String> exportBookmarksJson() async {
    final bookmarks = await _ref.read(quranRepositoryProvider).getBookmarks();
    return jsonEncode(bookmarks.map((b) => b.toMap()).toList());
  }

  Future<int> importBookmarksJson(String rawJson) async {
    final List decoded = jsonDecode(rawJson) as List;
    final repo = _ref.read(quranRepositoryProvider);
    int count = 0;
    for (final item in decoded) {
      final b = QuranBookmark.fromMap(item as Map<String, dynamic>);
      await repo.upsertBookmark(b);
      count++;
    }
    return count;
  }
}
