import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/quran/domain/quran_models.dart';
import 'package:noor/features/prayer/domain/prayer_models.dart';

void main() {
  group('Noor Domain & Calculation Tests', () {
    test('SurahSummary parses Al-Quran Cloud JSON properly', () {
      final json = {
        'number': 1,
        'name': 'سُورَةُ ٱلْفَاتِحَةِ',
        'englishName': 'Al-Faatiha',
        'englishNameTranslation': 'The Opening',
        'numberOfAyahs': 7,
        'revelationType': 'Meccan',
      };
      final surah = SurahSummary.fromJson(json);
      expect(surah.number, 1);
      expect(surah.nameEnglish, 'Al-Faatiha');
      expect(surah.numberOfAyahs, 7);
    });

    test('DailyPrayerTimes nextPrayer selects upcoming prayer accurately', () {
      final base = DateTime(2026, 10, 23);
      final times = DailyPrayerTimes(
        dateReadable: '23 Oct 2026',
        hijriFormatted: '12 Jumada al-Ula 1448 AH',
        hijriDay: 12,
        hijriMonthNumber: 5,
        hijriMonthNameEn: 'Jumada al-Ula',
        hijriMonthNameAr: 'جمادى الأولى',
        hijriYear: 1448,
        holidays: const [],
        fajr: base.add(const Duration(hours: 5)),
        sunrise: base.add(const Duration(hours: 6, minutes: 20)),
        dhuhr: base.add(const Duration(hours: 12, minutes: 10)),
        asr: base.add(const Duration(hours: 15, minutes: 25)),
        maghrib: base.add(const Duration(hours: 17, minutes: 55)),
        isha: base.add(const Duration(hours: 19, minutes: 15)),
        locationLabel: 'Jerusalem',
      );

      final nextAtNoon =
          times.nextPrayer(base.add(const Duration(hours: 12, minutes: 0)));
      expect(nextAtNoon.key, 'Dhuhr');
    });
  });
}
