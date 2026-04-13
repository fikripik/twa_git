import 'package:media_scanner/media_scanner.dart';
import '../config/package_config.dart';
import 'package:path/path.dart' as p;

@pragma('vm:entry-point')
class DownloadService {
  static Future<void> startDownload({
    required BuildContext context,
    required String url,
    String? suggestedFilename,
  }) async {
    if (Platform.isIOS) {
      await _downloadIOS(context, url, suggestedFilename);
      return;
    }

    await _downloadAndroid(context, url, suggestedFilename);
  }

  static Future<void> _downloadAndroid(
    BuildContext context,
    String url,
    String? suggestedFilename,
  ) async {
    final hasPermission = await PermissionHelper.requestDownloadPermissions(
      context,
    );
    if (!hasPermission) {
      _showSnackBar(context, 'Permission denied');
      return;
    }

    try {
      final dio = Dio();

      String fileName = suggestedFilename?.trim().isNotEmpty == true
          ? suggestedFilename!
          : url.split('/').last;

      final downloadsDir = Directory("/storage/emulated/0/Download/Ventour");
      await downloadsDir.create(recursive: true);   

      final uniqueFileName = await _resolveDuplicateName(downloadsDir.path, fileName);
      final filePath = p.join(downloadsDir.path, uniqueFileName);
      
      notificationId = await DownloadNotificationHelper.showDownloadStartNotification(uniqueFileName);

      _showLoading(context);

      final response = await dio.download(
        url,
        filePath,
        options: Options(responseType: ResponseType.stream),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100);
            debugPrint('Download progress: $progress%');

            DownloadNotificationHelper.updateDownloadProgressNotification(
              notificationId,
              uniqueFileName,
              progress.toInt(),
            );
          } else {
            DownloadNotificationHelper.updateDownloadIndeterminateProgressNotification(
              notificationId,
              uniqueFileName,
              received, 
            );
          }
        },
      );  

      if (response.statusCode == 200 && await File(filePath).exists()) {
          _scanMedia(filePath);
          await SharePlus.instance.share(ShareParams(files:[XFile(filePath)], text: 'Download file'));
          await NotificationService.plugin.cancel(id: notificationId);
          await DownloadNotificationHelper.showDownloadCompleteNotification(notificationId, uniqueFileName, filePath);
          return;
      }

        await NotificationService.plugin.cancel(id: notificationId);
        await DownloadNotificationHelper.showDownloadErrorNotification(notificationId, uniqueFileName, 'Gagal menyimpan file');
      } catch (e) {
          debugPrint('File copy failed: $e');
          await NotificationService.plugin.cancel(id: notificationId);
          if (context.mounted) {_showSnackBar(context, 'Download gagal : $e');}
      }
    }

  static Future<void> _downloadIOS(
    BuildContext context,
    String url,
    String? suggestedFilename,
  ) async {
    String? tempPath;

    try {
      final dio = Dio();
      final fileName = suggestedFilename?.isNotEmpty == true
          ? suggestedFilename!
          : url.split('/').last.split('?').first;

    final tempDir = await getTemporaryDirectory();
      tempPath = p.join(tempDir.path, fileName);

      await dio.download(url, tempPath);
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Download gagal');
      return;
    }

    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(tempPath)], text: 'Download file'));
    } catch (_) {}
  }

  static void _showLoading(BuildContext context) {
    const Center(child: CircularProgressIndicator(backgroundColor: Color.fromARGB(50, 0, 0, 0)));
  }

  static void _hideLoading(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static Future<void> downloadFile(String url, BuildContext context) async {
    try {
      if (Platform.isIOS) {
        _showLoading(context);
      }

      final dio = Dio();
      final filename = url.split('/').last.split('?').first;

      final tempDir = await getTemporaryDirectory();
      final tempPath = "${tempDir.path}/$filename";

      await dio.download(url, tempPath);

      if (Platform.isAndroid) {
        _scanMedia(tempPath);
      }

      if (Platform.isIOS) {
        _hideLoading(context);

        await SharePlus.instance.share(ShareParams(files:[XFile(tempPath)]));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("File berhasil di-download"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // debugPrint("DOWNLOAD ERROR: $e");
      // debugPrint("STACKTRACE: $s");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download gagal"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> testIosWrite() async {
    if (!Platform.isIOS) return;

    final dir = await getApplicationDocumentsDirectory();
    final ventourDir = Directory('${dir.path}/Ventour');
    await ventourDir.create(recursive: true);
  }

  static Future<String> _resolveDuplicateName(
    String dir,
    String fileName,
  ) async {
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);

    String newName = fileName;
    int i = 1;

    while (await File(p.join(dir, newName)).exists()) {
      newName = '$base($i)$ext';
      i++;
    }

    return newName;
  }

  static bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext);
  }

  @pragma('vm:entry-point')
  static void showDownloadCompleteDialog(String filePath) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isImage = _isImage(filePath);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Platform.isIOS
                  ? 'File tersimpan di Files > On My iPhone > Ventour'
                  : 'File berhasil diunduh',
            ),
            const SizedBox(height: 16),

            // 🔥 1 ROW BUTTONS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                    onPressed: () {
                      Navigator.pop(context);
                      OpenFile.open(filePath);
                    },
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () async {
                      Navigator.pop(context);
                      final params = ShareParams(
                        text: 'Share file from Ventour',
                        files: [XFile(filePath)],
                      );
                      await SharePlus.instance.share(params);
                    },
                  ),

                  if (Platform.isIOS && isImage) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo),
                      label: const Text('Save to Photos'),
                      onPressed: () async {
                        Navigator.pop(context);
                        await ImageGallerySaverPlus.saveFile(filePath);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    bool isSuccess = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
      ),
    );
  }
  
  static Future<void> _scanMedia(String tempPath) async {
    try {
        await MediaScanner.loadMedia(path: tempPath);

      debugPrint('Scan media to recent');
    } catch (e) {
      debugPrint('Mediastore save failed: $e');
    }
  }
}
