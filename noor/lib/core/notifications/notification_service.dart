import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  /// Requests Android 13+ POST_NOTIFICATIONS and Android 12+ SCHEDULE_EXACT_ALARM permissions
  Future<bool> requestAndroidPermissions() async {
    if (!Platform.isAndroid) return true;

    final notifStatus = await Permission.notification.request();
    final alarmStatus = await Permission.scheduleExactAlarm.request();

    return notifStatus.isGranted &&
        (alarmStatus.isGranted || alarmStatus.isLimited);
  }

  Future<void> scheduleAdhanNotification({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
    required String soundName,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final slug = soundName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final androidDetails = AndroidNotificationDetails(
      'noor_adhan_channel_$slug',
      'Adhan Prayer Notifications ($soundName)',
      channelDescription: 'Exact prayer time Adhan alerts ($soundName)',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      id,
      'Adhan • $prayerName',
      'It is now time for $prayerName prayer (حي على الصلاة)',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleDailyAzkarReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'noor_azkar_daily_channel',
      'Daily Azkar Reminders',
      channelDescription: 'Morning and Evening Azkar reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final now = tz.TZDateTime.now(tz.local);
    var morning = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7, 0);
    if (morning.isBefore(now)) {
      morning = morning.add(const Duration(days: 1));
    }
    var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 30);
    if (evening.isBefore(now)) {
      evening = evening.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      9001,
      'Noor • أذكار الصباح',
      'Keep your tongue moist with the remembrance of Allah.',
      morning,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      9002,
      'Noor • أذكار المساء',
      'Remember Allah in the evening for peace and protection.',
      evening,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleZakatAnniversaryReminder({
    required int id,
    required DateTime scheduledTime,
    required String hijriYearLabel,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'noor_zakat_anniversary_channel',
      'Zakat Hijri Anniversary Reminders',
      channelDescription: 'Yearly Hijri Zakat calculation and payment reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      id,
      'Zakat Hijri Anniversary ($hijriYearLabel)',
      'One lunar Hijri year (Hawl) has passed since your saved Zakat record.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'noor_general_channel',
      'General Reminders',
      channelDescription: 'Daily Azkar and Zakat reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAdhanNotifications() async {
    for (int id = 100; id < 110; id++) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
