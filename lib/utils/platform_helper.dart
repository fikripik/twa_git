import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class PlatformHelper {
  /// Get Android SDK version (returns 0 for non-Android)
  static Future<int> getAndroidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final info = DeviceInfoPlugin();
      final androidInfo = await info.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('Error getting SDK version: $e');
      return 30;
    }
  }
}