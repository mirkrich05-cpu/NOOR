import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/prayer_models.dart';

final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepository(ref.watch(dioClientProvider), AppDatabase.instance);
});

class CityPreset {
  final String name;
  final double latitude;
  final double longitude;
  const CityPreset(this.name, this.latitude, this.longitude);

  static const List<CityPreset> presets = [
    CityPreset('Jerusalem (القدس)', 31.7683, 35.2137),
    CityPreset('Ramallah (رام الله)', 31.9038, 35.2034),
    CityPreset('Gaza (غزة)', 31.5017, 34.4668),
    CityPreset('Makkah (مكة المكرمة)', 21.4225, 39.8262),
    CityPreset('Madinah (المدينة المنورة)', 24.4672, 39.6112),
    CityPreset('Amman (عمّان)', 31.9454, 35.9284),
    CityPreset('Cairo (القاهرة)', 30.0444, 31.2357),
  ];
}

class PrayerRepository {
  final DioClient _client;
  final AppDatabase _db;
  static const MethodChannel _widgetChannel =
      MethodChannel('com.noor.islamic.app/widget');

  PrayerRepository(this._client, this._db);

  static const Map<int, String> _arabicHijriMonths = {
    1: 'محرم',
    2: 'صفر',
    3: 'ربيع الأول',
    4: 'ربيع الآخر',
    5: 'جمادى الأولى',
    6: 'جمادى الآخرة',
    7: 'رجب',
    8: 'شعبان',
    9: 'رمضان',
    10: 'شوال',
    11: 'ذو القعدة',
    12: 'ذو الحجة',
  };

  /// Resolves GPS coordinates or falls back to preset city (default Jerusalem)
  Future<({double lat, double lng, String label})> resolveCoordinates({
    CityPreset? manualCity,
  }) async {
    if (manualCity != null) {
      return (
        lat: manualCity.latitude,
        lng: manualCity.longitude,
        label: manualCity.name,
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
          return (
            lat: pos.latitude,
            lng: pos.longitude,
            label:
                'GPS (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})',
          );
        }
      }
    } catch (_) {}

    final fallback = CityPreset.presets.first;
    return (
      lat: fallback.latitude,
      lng: fallback.longitude,
      label: fallback.name,
    );
  }

  /// Fetches the entire month from AlAdhan API and caches locally in SQLite.
  /// If offline with no cache, computes prayer times using astronomical solar formulas & `hijri`.
  Future<DailyPrayerTimes> getTodayPrayerTimes({
    required double latitude,
    required double longitude,
    required String locationLabel,
    int method = 4, // 4 = Umm al-Qura, 3 = Muslim World League, 5 = Egyptian, 2 = ISNA
    int school = 0, // 0 = Shafi/Maliki/Hanbali, 1 = Hanafi
    String? adhanSoundName,
  }) async {
    final now = DateTime.now();
    final cacheKey =
        'aladhan_cal_${now.year}_${now.month}_${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}_m${method}_s$school';

    try {
      final response = await _client.getWithCache(
        'https://api.aladhan.com/v1/calendar/${now.year}/${now.month}',
        cacheKey: cacheKey,
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'method': method,
          'school': school,
        },
      );

      final List days = response['data'] as List;
      final todayObj =
          days[(now.day - 1).clamp(0, days.length - 1)] as Map<String, dynamic>;
      final timings = todayObj['timings'] as Map<String, dynamic>;
      final dateObj = todayObj['date'] as Map<String, dynamic>;
      final hijriObj = dateObj['hijri'] as Map<String, dynamic>;
      final hijriMonth = hijriObj['month'] as Map<String, dynamic>;
      final List rawHolidays = hijriObj['holidays'] as List? ?? [];

      DateTime parseTime(String raw) {
        final clean = raw.split(' ').first;
        final parts = clean.split(':');
        return DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }

      final result = DailyPrayerTimes(
        dateReadable: dateObj['readable'] as String? ??
            DateFormat.yMMMMd().format(now),
        hijriFormatted:
            '${hijriObj['day']} ${hijriMonth['en']} ${hijriObj['year']} AH',
        hijriDay: int.tryParse(hijriObj['day'].toString()) ?? 1,
        hijriMonthNumber: hijriMonth['number'] as int? ?? 1,
        hijriMonthNameEn: hijriMonth['en'] as String? ?? '',
        hijriMonthNameAr: hijriMonth['ar'] as String? ?? '',
        hijriYear: int.tryParse(hijriObj['year'].toString()) ?? 1448,
        holidays: rawHolidays.map((e) => e.toString()).toList(),
        fajr: parseTime(timings['Fajr'] as String),
        sunrise: parseTime(timings['Sunrise'] as String),
        dhuhr: parseTime(timings['Dhuhr'] as String),
        asr: parseTime(timings['Asr'] as String),
        maghrib: parseTime(timings['Maghrib'] as String),
        isha: parseTime(timings['Isha'] as String),
        locationLabel: locationLabel,
      );

      await _syncWidgetAndNotifications(result, adhanSoundName: adhanSoundName);
      return result;
    } catch (_) {
      final hDate = HijriCalendar.fromDate(now);
      final solar = _computeOfflineSolarPrayers(
        date: now,
        latitude: latitude,
        longitude: longitude,
        method: method,
        school: school,
      );

      final fallback = DailyPrayerTimes(
        dateReadable: DateFormat.yMMMMd().format(now),
        hijriFormatted:
            '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear} AH',
        hijriDay: hDate.hDay,
        hijriMonthNumber: hDate.hMonth,
        hijriMonthNameEn: hDate.longMonthName,
        hijriMonthNameAr:
            _arabicHijriMonths[hDate.hMonth] ?? hDate.longMonthName,
        hijriYear: hDate.hYear,
        holidays: const [],
        fajr: solar.fajr,
        sunrise: solar.sunrise,
        dhuhr: solar.dhuhr,
        asr: solar.asr,
        maghrib: solar.maghrib,
        isha: solar.isha,
        locationLabel: '$locationLabel (Offline Solar)',
      );

      await _syncWidgetAndNotifications(fallback, adhanSoundName: adhanSoundName);
      return fallback;
    }
  }

  /// Pure Dart astronomical prayer time calculation (Jean Meeus solar position equations)
  ({
    DateTime fajr,
    DateTime sunrise,
    DateTime dhuhr,
    DateTime asr,
    DateTime maghrib,
    DateTime isha,
  }) _computeOfflineSolarPrayers({
    required DateTime date,
    required double latitude,
    required double longitude,
    required int method,
    required int school,
  }) {
    double deg2rad(double d) => d * math.pi / 180.0;
    double rad2deg(double r) => r * 180.0 / math.pi;

    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final gamma = 2.0 * math.pi / 365.0 * (dayOfYear - 1 + 0.5);

    // Equation of time (in minutes) and solar declination (in radians)
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final tzOffsetHours = date.timeZoneOffset.inMinutes / 60.0;
    final dhuhrHours =
        12.0 + tzOffsetHours - (longitude / 15.0) - (eqTime / 60.0);

    final latRad = deg2rad(latitude);

    double hourAngleForDepression(double depressionDeg) {
      final altRad = deg2rad(-depressionDeg);
      final cosH = (math.sin(altRad) - math.sin(latRad) * math.sin(decl)) /
          (math.cos(latRad) * math.cos(decl));
      final clamped = cosH.clamp(-1.0, 1.0);
      return rad2deg(math.acos(clamped)) / 15.0;
    }

    double fajrAngle = 18.5;
    double ishaAngle = 0.0;
    int ishaIntervalMinutes = 90;
    switch (method) {
      case 3: // Muslim World League
        fajrAngle = 18.0;
        ishaAngle = 17.0;
        ishaIntervalMinutes = 0;
        break;
      case 5: // Egyptian General Authority
        fajrAngle = 19.5;
        ishaAngle = 17.5;
        ishaIntervalMinutes = 0;
        break;
      case 2: // ISNA
        fajrAngle = 15.0;
        ishaAngle = 15.0;
        ishaIntervalMinutes = 0;
        break;
      case 4: // Umm al-Qura
      default:
        fajrAngle = 18.5;
        ishaAngle = 0.0;
        ishaIntervalMinutes = 90;
        break;
    }

    final sunriseDiff = hourAngleForDepression(0.833);
    final fajrDiff = hourAngleForDepression(fajrAngle);

    // Asr shadow factor (1 = Shafi, 2 = Hanafi)
    final shadowFactor = school == 1 ? 2.0 : 1.0;
    final asrAltRad = math.atan(
      1.0 / (shadowFactor + math.tan((latRad - decl).abs())),
    );
    final cosAsrH = (math.sin(asrAltRad) - math.sin(latRad) * math.sin(decl)) /
        (math.cos(latRad) * math.cos(decl));
    final asrDiff = rad2deg(math.acos(cosAsrH.clamp(-1.0, 1.0))) / 15.0;

    final fajrHours = dhuhrHours - fajrDiff;
    final sunriseHours = dhuhrHours - sunriseDiff;
    final asrHours = dhuhrHours + asrDiff;
    final maghribHours = dhuhrHours + sunriseDiff;
    final ishaHours = ishaIntervalMinutes > 0
        ? maghribHours + (ishaIntervalMinutes / 60.0)
        : dhuhrHours + hourAngleForDepression(ishaAngle);

    DateTime hoursToDateTime(double h) {
      final totalMinutes = (h * 60.0).round();
      final hours = (totalMinutes ~/ 60).clamp(0, 23);
      final mins = (totalMinutes % 60).clamp(0, 59);
      return DateTime(date.year, date.month, date.day, hours, mins);
    }

    return (
      fajr: hoursToDateTime(fajrHours),
      sunrise: hoursToDateTime(sunriseHours),
      dhuhr: hoursToDateTime(dhuhrHours + (2.0 / 60.0)),
      asr: hoursToDateTime(asrHours),
      maghrib: hoursToDateTime(maghribHours),
      isha: hoursToDateTime(ishaHours),
    );
  }

  /// Calculates accurate Qibla direction bearing in degrees from True North
  double calculateQiblaBearing(double lat, double lng) {
    const kaabaLat = 21.422487 * math.pi / 180.0;
    const kaabaLng = 39.826206 * math.pi / 180.0;
    final phi = lat * math.pi / 180.0;
    final lam = lng * math.pi / 180.0;

    final y = math.sin(kaabaLng - lam);
    final x = math.cos(phi) * math.tan(kaabaLat) -
        math.sin(phi) * math.cos(kaabaLng - lam);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  Future<void> _syncWidgetAndNotifications(
    DailyPrayerTimes times, {
    String? adhanSoundName,
  }) async {
    final fmt = DateFormat('HH:mm');
    final next = times.nextPrayer(DateTime.now());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_hijri_date', times.hijriFormatted);
      await prefs.setString('widget_next_prayer_name', next.key);
      await prefs.setString('widget_next_prayer_time', fmt.format(next.value));
      await prefs.setString('widget_fajr', fmt.format(times.fajr));
      await prefs.setString('widget_dhuhr', fmt.format(times.dhuhr));
      await prefs.setString('widget_asr', fmt.format(times.asr));
      await prefs.setString('widget_maghrib', fmt.format(times.maghrib));
      await prefs.setString('widget_isha', fmt.format(times.isha));
      await _widgetChannel.invokeMethod('updatePrayerWidget');
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final notifsEnabled = prefs.getBool('adhan_notifs') ?? true;
      if (!notifsEnabled) {
        await NotificationService.instance.cancelAdhanNotifications();
        return;
      }
      final sound =
          adhanSoundName ?? prefs.getString('adhan_sound') ?? 'Makkah Adhan';
      int id = 100;
      for (final entry in times.fivePrayersAndSunrise.entries) {
        if (entry.key == 'Sunrise') continue;
        await NotificationService.instance.scheduleAdhanNotification(
          id: id++,
          prayerName: entry.key,
          scheduledTime: entry.value,
          soundName: sound,
        );
      }
    } catch (_) {}
  }
}
