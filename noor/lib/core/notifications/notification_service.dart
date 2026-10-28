import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await NotificationService.instance.init();
    if (task == 'daily_azkar_reminder') {
      await NotificationService.instance.showInstantNotification(
        id: 9001,
        title: 'Noor • أذكار الصباح والمساء',
        body: 'Keep your tongue moist with the remembrance of Allah.',
      );
    }
    return Future.value(true);
  });
}

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

    final androidDetails = AndroidNotificationDetails(
      'noor_adhan_channel_$soundName',
      'Adhan Prayer Notifications ($soundName)',
      channelDescription: 'Exact prayer time Adhan alerts',
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

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
