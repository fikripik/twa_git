import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../config/package_config.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static final navigatorKey = GlobalKey<NavigatorState>();

  static int _notificationId = 0;
  static int _radiusNotificationId = 9000;  // ✅ Separate counter for radius notifications

  static const channelAdzanSubuh = 'vm_adzan_global';
  static const channelAdzanLain = 'vm_adzan_lain';
  static const channelGlobal = 'vm_global';
  static const channelRadius = 'radius_alerts';
  static const channelDownload = 'download_channel';

  static Future<void> initFCM() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }  

  static Future<void> initLocalNotification() async {
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification_icon'),
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null) return;

        if (payload == 'reschedule') {
          await _plugin.cancelAll();
          schedulePrayerNotifications();
          scheduleDailyRescheduler();
          return;
        }

        final file = File(payload);
        if (!await file.exists()) return;

        if (response.actionId == 'open_file') {
          await OpenFile.open(file.path);
          return;
        }

        if (response.actionId == 'share_file') {
          final params = ShareParams(
            text: 'Share file from Ventour',
            files: [XFile(file.path)],
          );
          await SharePlus.instance.share(params);
          return;
        }

        final params = ShareParams(
          text: 'Share file from Ventour',
          files: [XFile(file.path)],
        );
        await SharePlus.instance.share(params);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelGlobal,
        'Global Notification',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelAdzanSubuh,
        'Adzan Subuh',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelAdzanLain,
        'Adzan Lain',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'rescheduler',
        'System',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelRadius,
        'Radius Alerts',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
    );
  
  }

  static Future<void> handleTerminatedLaunch() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null) return;
    if (!details.didNotificationLaunchApp) return;

    final payload = details.notificationResponse?.payload;
    if (payload == null) return;

    final file = File(payload);
    if (await file.exists()) {
      await OpenFile.open(file.path);
      return;
    }

    if (payload == 'reschedule') {
      await _plugin.cancelAll();
      schedulePrayerNotifications();
      scheduleDailyRescheduler();
      return;
    }

    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const WebviewScreen()),
    );
  }

  static void initForegroundListener() async {
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

    FirebaseMessaging.onMessage.listen((message) {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'Notifikasi';
      final body = message.notification?.body ?? message.data['body'] ?? '';

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'venom_global',
          'Global Notification',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      );
      _plugin.show(
        id: _notificationId++,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: message.data['url'],
      );
    });
  }

  static Future<void> schedulePrayerNotifications() async {
    final prayerTimes = await PrayerService.fetchPrayerTimesFromApi();
    int id = 100;

    for (final entry in prayerTimes.entries) {
      final time = PrayerService.nextPrayerTime(entry.value);

      final tzTime = tz.TZDateTime.from(time, tz.local);

      final isSubuh =
          entry.key.toLowerCase().contains('subuh') ||
          entry.key.toLowerCase().contains('fajr');

      final androidSound = isSubuh ? 'notification' : 'notification';
      final iosSound = isSubuh ? 'notification.aiff' : 'notification.aiff';
      final channel = isSubuh ? channelAdzanSubuh : channelAdzanLain;
      String daerah = await LocationService.getUserCity();
      String jam = DateFormat('HH:mm').format(tzTime);
      await _plugin.zonedSchedule(
        id: id,
        title: 'Waktu Sholat ${entry.key} Pukul $jam',
        body: 'Sudah masuk waktu sholat ${entry.key} di $daerah',
        scheduledDate: tzTime,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            isSubuh ? 'Adzan Subuh' : 'Adzan',
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound(androidSound),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: iosSound,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      id++;
    }
  }

  static Future<void> scheduleDailyRescheduler() async {
    final now = tz.TZDateTime.now(tz.local);

    final nextMidnight = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      8,
      30,
    );

    await _plugin.zonedSchedule(
      id: 9999,
      title: 'Ventour Mobile',
      body:
          'Jangan lupa cek aktivitas kamu hari ini di aplikasi ya 👋 Siapa tahu ada update penting buat kamu.',
      scheduledDate: nextMidnight,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rescheduler',
          'System',
          importance: Importance.min,
          priority: Priority.min,
          playSound: false,
          enableVibration: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reschedule',
    );
  }

  static Future<void> showGlobal({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: _notificationId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelGlobal,
          'Global',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();

    if (message.data['type'] == 'global') {
      showGlobal(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        payload: message.data['url'],
      );
    }
  }

  static AndroidNotificationDetails _buildAndroidDownloadDetails({
    required String channelId,
    required String channelName,
    int maxProgress = 100,
    int progress = 0,
    bool showProgress = false,
    bool indeterminate = false,
    bool ongoing = false,
    bool autoCancel = true,
    String? icon,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Download notifications',
      importance: showProgress ? Importance.low : Importance.high,
      priority: showProgress ? Priority.low : Priority.high,
      showProgress: showProgress,
      maxProgress: maxProgress,
      progress: progress,
      indeterminate: indeterminate,
      ongoing: ongoing,
      autoCancel: autoCancel,
      icon: icon,
    );
  }

  // Helper method for iOS download notification details
  static DarwinNotificationDetails _buildIOSDownloadDetails() {
    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );
  }

  // Simplified download functions
  static Future<int> showDownloadStartNotification(String fileName) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _plugin.show(
      id: id,
      title: 'Downloading',
      body: fileName,
      notificationDetails: NotificationDetails(
        android: _buildAndroidDownloadDetails(
          channelId: channelDownload,
          channelName: 'Downloads',
          showProgress: true,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: _buildIOSDownloadDetails(),
      ),
    );

    return id;
  }

  static void updateDownloadProgressNotification(
    int id,
    String fileName,
    int progress,
  ) {
    _plugin.show(
      id: id,
      title: 'Downloading $fileName',
      body: '$progress%',
      notificationDetails: NotificationDetails(
        android: _buildAndroidDownloadDetails(
          channelId: channelDownload,
          channelName: 'Downloads',
          showProgress: true,
          progress: progress,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: _buildIOSDownloadDetails(),
      ),
    );
  }

  static void updateIndeterminateProgressNotification(
    int id,
    String fileName,
    int bytesReceived,
  ) {
    final kb = (bytesReceived / 1024).toStringAsFixed(0);

    _plugin.show(
      id: id,
      title: 'Downloading $fileName',
      body: '$kb KB downloaded...',
      notificationDetails: NotificationDetails(
        android: _buildAndroidDownloadDetails(
          channelId: channelDownload,
          channelName: 'Downloads',
          showProgress: true,
          indeterminate: true,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: _buildIOSDownloadDetails(),
      ),
    );
  }

  static Future<void> showDownloadCompleteNotification(
    int id,
    String fileName,
    String filePath,
  ) async {
    await _plugin.show(
      id: id,
      title: 'Download Complete',
      body: '$fileName downloaded successfully',
      notificationDetails: NotificationDetails(
        android: _buildAndroidDownloadDetails(
          channelId: channelDownload,
          channelName: 'Downloads',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      ),
      payload: filePath,
    );
  }

  static Future<void> showDownloadErrorNotification(
    int id,
    String fileName,
    String error,
  ) async {
    await _plugin.show(
      id: id,
      title: 'Download Failed',
      body: '$fileName: $error',
      notificationDetails: NotificationDetails(
        android: _buildAndroidDownloadDetails(
          channelId: channelDownload,
          channelName: 'Downloads',
          icon: 'ic_error',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      ),
    );
  }

  static Future<void> showRadiusViolation({
    required int jamaahId,
    required String jamaahName,
    required String userRole,
  }) async {
    final (title, body) = ('Anda Keluar Zona', '$jamaahName berada di luar kawasan');
    
    debugPrint('✅ Showing notification ID: $notificationId for $jamaahName');

    await _plugin.show(
      id: _radiusNotificationId++,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelRadius,
          'Radius Alerts',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      ),
    );
  }

    static Future<void> showRadiusViolationSummary({
    required int count,
    required String userRole,
  }) async {
    final (title, body) = ('Jamaah Keluar Zona', '$count jamaah telah meninggalkan zona pengawasan');
    
    debugPrint('✅ Showing SUMMARY notification ID: $_radiusNotificationId');
  
    await _plugin.show(
      id: _radiusNotificationId++,
      title: title,
      body: body,
      notificationDetails:
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelRadius,
          'Radius Alerts',
          channelDescription: 'Alerts when jamaah leave supervision radius',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
        ),
      ),
    );
  }
}
