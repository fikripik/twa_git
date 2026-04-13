import 'package:twa/config/package_config.dart';

class DownloadNotificationHelper {
  static Future<int> showDownloadStartNotification(String fileName) async {
    return await NotificationService.showDownloadStartNotification(fileName);
  }

  static void updateDownloadProgressNotification(int id, String fileName, int progress) {
    NotificationService.updateDownloadProgressNotification(id, fileName, progress);
  }

  static Future<void> updateDownloadIndeterminateProgressNotification(int id, String fileName, int bytesReceived) async {
    NotificationService.updateIndeterminateProgressNotification(id, fileName, bytesReceived);
  }

  static Future<void> showDownloadCompleteNotification(int id, String fileName, String filePath) async {
    await NotificationService.showDownloadCompleteNotification(id, fileName, filePath);
  }

  static Future<void> showDownloadErrorNotification(int id, String fileName, String error) async {
    await NotificationService.showDownloadErrorNotification(id, fileName, error);
  }
}