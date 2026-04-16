import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'platform_helper.dart';

class PermissionHelper {
  /// Request all necessary permissions for downloads
  /// Returns true if permissions granted or not required
  static Future<bool> requestDownloadPermissions(BuildContext context) async {
    final sdkInt = await PlatformHelper.getAndroidSdkInt();

    // Request notification permission (Android 13+)
    if (sdkInt >= 33) {
      final notifStatus = await Permission.notification.request();
      final storageStatus = await Permission.manageExternalStorage.request();

      if (!notifStatus.isGranted || !storageStatus.isGranted) {
        debugPrint('Notification permission denied');

        // Show dialog reason notification is needed
        if (context.mounted) {
          final retry = await _showPermissionDialog(context, sdkInt);
          if (retry) {
            await openAppSettings();
          } else {
            return false;
          }
        }
      }
    }

    // Request storage permission (Android < 30)
    if (Platform.isAndroid && sdkInt < 30) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        debugPrint('Storage permission denied (SDK $sdkInt)');

        // Show dialog to user
        if (context.mounted) {
          final retry = await _showStoragePermissionDialog(context, sdkInt);
          if (retry) {
            await openAppSettings();
          }
        }
        return false;
      }
    }

    // For Android 11+ (SDK 30+), no storage permission needed for app-specific dirs
    return true;
  }

  /// Show permission rationale dialog
  static Future<bool> _showPermissionDialog(
    BuildContext context,
    int sdkInt,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Notification permission is required to show download progress and completion. '
          'Would you like to open settings to grant permission?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show storage permission rationale dialog
  static Future<bool> _showStoragePermissionDialog(
    BuildContext context,
    int sdkInt,
  ) async {
    final isForUpload = sdkInt >= 30;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          isForUpload
              ? 'Storage permission is needed to upload files and attach documents later. '
                    'Downloads will still work, but you won\'t be able to upload files.\n\n'
                    'Would you like to open settings to grant permission?'
              : 'Storage permission is needed to save downloads. '
                    'Would you like to open settings to grant permission?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
