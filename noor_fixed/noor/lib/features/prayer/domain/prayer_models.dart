class DailyPrayerTimes {
  final String dateReadable;
  final String hijriFormatted;
  final int hijriDay;
  final int hijriMonthNumber;
  final String hijriMonthNameEn;
  final String hijriMonthNameAr;
  final int hijriYear;
  final List<String> holidays;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String locationLabel;

  const DailyPrayerTimes({
    required this.dateReadable,
    required this.hijriFormatted,
    required this.hijriDay,
    required this.hijriMonthNumber,
    required this.hijriMonthNameEn,
    required this.hijriMonthNameAr,
    required this.hijriYear,
    required this.holidays,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.locationLabel,
  });

  Map<String, DateTime> get fivePrayersAndSunrise => {
        'Fajr': fajr,
        'Sunrise': sunrise,
        'Dhuhr': dhuhr,
        'Asr': asr,
        'Maghrib': maghrib,
        'Isha': isha,
      };

  MapEntry<String, DateTime> nextPrayer(DateTime now) {
    final entries = [
      MapEntry('Fajr', fajr),
      MapEntry('Sunrise', sunrise),
      MapEntry('Dhuhr', dhuhr),
      MapEntry('Asr', asr),
      MapEntry('Maghrib', maghrib),
      MapEntry('Isha', isha),
    ];
    for (final entry in entries) {
      if (entry.value.isAfter(now)) {
        return entry;
      }
    }
    return MapEntry('Fajr', fajr.add(const Duration(days: 1)));
  }
}
