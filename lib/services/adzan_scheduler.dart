import '../config/package_config.dart';
import 'package:timezone/timezone.dart' as tz;

const String adzanChannelId = 'adzan_channel';

class AdzanScheduler {
  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  static Future<void> scheduleDailyAdzan(
    Map<String, DateTime> prayerTimes,
  ) async {
    for (final entry in prayerTimes.entries) {
      final name = entry.key;
      final time = entry.value;

      if (time.isBefore(DateTime.now())) continue;

      await _notif.zonedSchedule(
        id: _id(name),
        title: 'Waktu $name',
        body: 'Telah masuk waktu adzan $name',
        scheduledDate:  tz.TZDateTime.from(time, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            adzanChannelId,
            'Adzan',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('adzan'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
            icon: 'ic_notification_icon',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static int _id(String name) {
    switch (name) {
      case 'Subuh':
        return 101;
      case 'Dzuhur':
        return 102;
      case 'Ashar':
        return 103;
      case 'Maghrib':
        return 104;
      case 'Isya':
        return 105;
      default:
        return 999;
    }
  }
}
