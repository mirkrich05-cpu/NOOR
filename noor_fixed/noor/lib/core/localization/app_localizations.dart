import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Noor',
      'home': 'Home',
      'quran': 'Quran',
      'prayer': 'Prayer',
      'azkar': 'Azkar',
      'hadith': 'Hadith',
      'zakat': 'Zakat',
      'settings': 'Settings',
      'next_prayer': 'Next Prayer',
      'verse_of_the_day': 'Verse of the Day',
      'hadith_of_the_day': 'Hadith of the Day',
      'ramadan_mode': 'Ramadan Hub & Khatma Planner',
      'qibla_compass': 'Qibla Compass',
      'tasbeeh': 'Digital Tasbeeh',
      'search_quran': 'Search Quran by word...',
      'surah': 'Surah',
      'juz': 'Juz',
      'page': 'Page',
      'bookmarks': 'Bookmarks',
      'last_read': 'Continue Reading',
      'fajr': 'Fajr',
      'sunrise': 'Sunrise',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
      'zakat_calculator': 'Zakat & Fitr Calculator',
      'nisab_threshold': 'Nisab Threshold',
      'zakat_due': 'Total Zakat Due (2.5%)',
      'language': 'Language',
      'dark_mode': 'Dark Mode',
      'quran_font_size': 'Quran Font Size',
      'adhan_notifications': 'Adhan Notifications',
      'backup_bookmarks': 'Backup / Restore Bookmarks',
    },
    'ar': {
      'app_name': 'نور',
      'home': 'الرئيسية',
      'quran': 'القرآن',
      'prayer': 'الصلاة',
      'azkar': 'الأذكار',
      'hadith': 'الحديث',
      'zakat': 'الزكاة',
      'settings': 'الإعدادات',
      'next_prayer': 'الصلاة القادمة',
      'verse_of_the_day': 'آية اليوم',
      'hadith_of_the_day': 'حديث اليوم',
      'ramadan_mode': 'رمضان وخطة ختم القرآن',
      'qibla_compass': 'بوصلة القبلة',
      'tasbeeh': 'المسبحة الإلكترونية',
      'search_quran': 'ابحث في القرآن الكريم...',
      'surah': 'سورة',
      'juz': 'جزء',
      'page': 'صفحة',
      'bookmarks': 'العلامات المرجعية',
      'last_read': 'متابعة القراءة',
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
      'zakat_calculator': 'حاسبة الزكاة وزكاة الفطر',
      'nisab_threshold': 'حد النصاب',
      'zakat_due': 'مقدار الزكاة الواجبة (2.5%)',
      'language': 'اللغة',
      'dark_mode': 'الوضع الداكن',
      'quran_font_size': 'حجم خط القرآن',
      'adhan_notifications': 'تنبيهات الأذان',
      'backup_bookmarks': 'نسخ واستعادة الفواصل',
    },
  };

  String tr(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
