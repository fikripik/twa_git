import '../config/package_config.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  static bool isForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isForeground = state == AppLifecycleState.resumed;
  }
}
