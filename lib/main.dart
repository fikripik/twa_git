import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../config/package_config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? pendingUrl;
String? fcmToken;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const String channelAdzan = 'venom_adzan';
const String channelGlobal = 'venom_global';

int notificationId = 0;

enum NotificationType { adzan, global }

class AppLifecycleObserver extends WidgetsBindingObserver {
  static bool isForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isForeground = state == AppLifecycleState.resumed;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await InAppWebViewController.setWebContentsDebuggingEnabled(true);

  // await DownloadService.testIosWrite();

  await Firebase.initializeApp();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  await NotificationService.initFCM();
  await NotificationService.initLocalNotification();
  await NotificationService.handleTerminatedLaunch();
  NotificationService.initForegroundListener();
  NotificationService.schedulePrayerNotifications();
  NotificationService.scheduleDailyRescheduler();

  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  fcmToken = await FirebaseMessaging.instance.getToken();

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final url = message.data['url'];
    if (url != null) {
      pendingUrl = url;

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SplashScreen(initialUrl: pendingUrl)),
        (route) => false,
      );
    }
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    pendingUrl = initialMessage.data['url'];
  }

  final isLoggedIn = await CekAuth.checkToken();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool? isLoggedIn;
  const MyApp({super.key, this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ventour Mobile',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          primary: Colors.yellow.shade700,
          seedColor: Colors.yellow.shade800,
        ),
        focusColor: Colors.yellow.shade600,
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.yellow.shade600),
          ),
          border: OutlineInputBorder(),
        ),
        dialogTheme: DialogThemeData(
          shadowColor: Colors.black54,
        ),
      ),
      home: SplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}
