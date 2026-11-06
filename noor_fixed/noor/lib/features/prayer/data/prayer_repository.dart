import 'dart:math' as math;
import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';
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

  adhan.CalculationParameters _mapCalculationMethod(int method) {
    switch (method) {
      case 4:
        return adhan.CalculationMethod.ummAlQura();
      case 5:
        return adhan.CalculationMethod.egyptian();
      case 2:
        return adhan.CalculationMethod.northAmerica();
      case 3:
      default:
        return adhan.CalculationMethod.muslimWorldLeague();
    }
  }

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
  /// If offline with no cache, computes prayer times using `adhan_dart` & `hijri`.
  Future<DailyPrayerTimes> getTodayPrayerTimes({
    required double latitude,
    required double longitude,
    required String locationLabel,
    int method = 4, // 4 = Umm al-Qura, 3 = Muslim World League, 5 = Egyptian
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
      // Pure Offline Fallback using adhan_dart + hijri package
      final coordinates = adhan.Coordinates(latitude, longitude);
      final params = _mapCalculationMethod(method);
      params.madhab =
          school == 1 ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
      final prayerTimes = adhan.PrayerTimes(
        coordinates: coordinates,
        date: now,
        calculationParameters: params,
        precision: true,
      );
      final hDate = HijriCalendar.fromDate(now);

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
        fajr: prayerTimes.fajr!.toLocal(),
        sunrise: prayerTimes.sunrise!.toLocal(),
        dhuhr: prayerTimes.dhuhr!.toLocal(),
        asr: prayerTimes.asr!.toLocal(),
        maghrib: prayerTimes.maghrib!.toLocal(),
        isha: prayerTimes.isha!.toLocal(),
        locationLabel: '$locationLabel (Offline adhan_dart)',
      );

      await _syncWidgetAndNotifications(fallback, adhanSoundName: adhanSoundName);
      return fallback;
    }
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
      await HomeWidget.saveWidgetData<String>(
          'hijri_date', times.hijriFormatted);
      await HomeWidget.saveWidgetData<String>('next_prayer_name', next.key);
      await HomeWidget.saveWidgetData<String>(
          'next_prayer_time', fmt.format(next.value));
      await HomeWidget.saveWidgetData<String>('fajr', fmt.format(times.fajr));
      await HomeWidget.saveWidgetData<String>('dhuhr', fmt.format(times.dhuhr));
      await HomeWidget.saveWidgetData<String>('asr', fmt.format(times.asr));
      await HomeWidget.saveWidgetData<String>(
          'maghrib', fmt.format(times.maghrib));
      await HomeWidget.saveWidgetData<String>('isha', fmt.format(times.isha));
      await HomeWidget.updateWidget(
        name: 'NoorPrayerWidgetProvider',
        androidName: 'NoorPrayerWidgetProvider',
      );
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
