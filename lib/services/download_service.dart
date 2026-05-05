import 'package:html_to_pdf/html_to_pdf.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../config/package_config.dart';
import 'package:path/path.dart' as p;

@pragma('vm:entry-point')
class DownloadService {
    static Future<void> startDownload({
    required BuildContext context,
    required String url,
    String? suggestedFilename,
    bool forceHTML = false,
  }) async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(url));
      final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");

      final contentType = await _detectResponseType(url, cookieString);
      debugPrint('📋 Detected: $contentType');

      if (forceHTML || contentType.contains('html')) {
        debugPrint('🔄 HTML endpoint detected, converting to PDF...');
        await _generatePDFFromHTML(context, url, suggestedFilename);
      } else if (contentType.contains('pdf') || contentType.contains('octet-stream')) {
        debugPrint('📄 PDF endpoint detected, downloading directly...');
        if (Platform.isIOS) {
          await _downloadIOS(context, url, suggestedFilename);
        } else {
          await _downloadAndroid(context, url, suggestedFilename);
        }
      } else {
        debugPrint('❓ Unknown type: $contentType, attempting download...');
        if (Platform.isIOS) {
          await _downloadIOS(context, url, suggestedFilename);
        } else {
          await _downloadAndroid(context, url, suggestedFilename);
        }
      }
    } catch (e) {
      debugPrint('❌ Start download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ✅ Detect content type
  static Future<String> _detectResponseType(String url, String cookieString) async {
    try {
      final dio = Dio();
      final response = await dio.head(
        url,
        options: Options(
          headers: {"Cookie": cookieString},
          validateStatus: (status) => status != null && status < 500,
          followRedirects: false,
        ),
      );

      final contentType = response.headers['content-type']?.first ?? '';
      debugPrint('📋 Content-Type: $contentType');

      if (contentType.contains('text/html')) {
        return 'html';
      } else if (contentType.contains('application/pdf')) {
        return 'pdf';
      } else if (contentType.isEmpty) {
        return 'unknown';
      }
      return contentType;
    } catch (e) {
      debugPrint('❌ Content-type detection failed: $e');
      return 'unknown';
    }
  }

  // ✅ Generate PDF from HTML
    static Future<void> _generatePDFFromHTML(
      BuildContext context,
      String url,
      String? suggestedFilename,
    ) async {
      final hasPermission = await PermissionHelper.requestDownloadPermissions(context);
      if (!hasPermission) {
        _showSnackBar(context, 'Permission denied');
        return;
      }
  
      try {
        // Get cookies
        final cookieManager = CookieManager.instance();
        final cookies = await cookieManager.getCookies(url: WebUri(url));
        final cookieString = cookies.map((c) => "${c.name}=${c.value}").join("; ");
  
        showLoadingToast(context);
  
        // Fetch HTML
        debugPrint('📥 Fetching HTML from: $url');
        final dio = Dio();
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              "Cookie": cookieString,
              "User-Agent": "Mozilla/5.0",
              "Accept": "text/html",
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );
  
        if (response.statusCode != 200) {
          throw Exception('Failed to fetch HTML: ${response.statusCode}');
        }
  
        String htmlContent = response.data;
        debugPrint('✅ HTML fetched, size: ${htmlContent.length} bytes');
  
        // ✅ Generate PDF in Temp directory first (guaranteed permissions)
        final tempDir = await getTemporaryDirectory();
        String fileName = _extractFilenameFromHTML(htmlContent);
  
        final styledHTML = _processHTMLForPDF(htmlContent);
  
        debugPrint('🔄 Converting HTML to PDF in temp directory...');
        await HtmlToPdf.convertFromHtmlContent(
          htmlContent: styledHTML,
          printPdfConfiguration: PrintPdfConfiguration(
            targetDirectory: tempDir.path,  // ✅ Use temp directory
            targetName: fileName,
            printSize: PrintSize.A4,
            printOrientation: PrintOrientation.Portrait,
          ),
        );
  
        // Verify PDF was created in temp
        final tempPdfPath = "${tempDir.path}/$fileName.pdf";
        final tempFile = File(tempPdfPath);
        
        if (!await tempFile.exists()) {
          throw Exception('❌ PDF not created in temp. Path: $tempPdfPath');
        }
  
        final fileSize = await tempFile.length();
        if (fileSize == 0) {
          throw Exception('Generated PDF is empty');
        }
  
        debugPrint('✅ PDF generated in temp: $tempPdfPath ($fileSize bytes)');
  
        // ✅ Now copy to public downloads folder
        final baseDownloads = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        ).then((dirs) => dirs?.first);
        
        if (baseDownloads == null) {
          _showSnackBar(context, 'Tidak dapat mengakses folder Download');
          return;
        }
  
        final publicDir = Directory("/storage/emulated/0/Download/Ventour");
        await publicDir.create(recursive: true);
  
        final uniqueFileName = await _resolveDuplicateName(publicDir.path, '$fileName.pdf');
        final finalPath = p.join(publicDir.path, uniqueFileName);
  
        notificationId = await DownloadNotificationHelper.showDownloadStartNotification(uniqueFileName);
  
        // Copy from temp to public
        await tempFile.copy(finalPath);
        debugPrint('✅ PDF copied to public: $finalPath');
  
        // Verify final file
        final finalFile = File(finalPath);
        if (!await finalFile.exists()) {
          throw Exception('Failed to copy PDF to downloads');
        }
  
        // Scan media & show notification
        _scanMedia(finalPath);
        await NotificationService.plugin.cancel(id: notificationId);
        await DownloadNotificationHelper.showDownloadCompleteNotification(
          notificationId,
          uniqueFileName,
          finalPath,
        );
  
        hideLoadingToast();
        showFloatingToast(context, 'PDF Generated Successfully', isSuccess: true);
        await Future.delayed(const Duration(milliseconds: 800));
        showDownloadCompleteDialog(finalPath);
      } catch (e) {
        debugPrint('❌ HTML→PDF failed: $e');
        hideLoadingToast();
        await NotificationService.plugin.cancel(id: notificationId);
        if (context.mounted) {
          _showSnackBar(context, 'Generation failed: $e');
        }
      }
    }

    static String _extractFilenameFromHTML(String htmlContent) {
  try {
    final regex = RegExp(
      r'<meta\s+name="pdf-filename"\s+content="([^"]+)"',
      caseSensitive: false
    );
    final match = regex.firstMatch(htmlContent);
    
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }
  } catch (e) {
    debugPrint('⚠️ Error extracting filename: $e');
  }
    return '';
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

      final baseDownloads = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      ).then((dirs) => dirs?.first);
      
			if (baseDownloads == null) {
				_showSnackBar(context, 'Tidak dapat mengakses folder Download');
				return;
			}

			final downloadsDir = Directory("/storage/emulated/0/Download/Ventour");	
			await downloadsDir.create(recursive: true);

      final uniqueFileName = await _resolveDuplicateName(downloadsDir!.path, fileName);
      final filePath = p.join(downloadsDir.path, uniqueFileName);
      
      notificationId = await DownloadNotificationHelper.showDownloadStartNotification(uniqueFileName);

      showLoadingToast(context);

      final cookieManager = CookieManager.instance();

      final cookies = await cookieManager.getCookies(
        url: WebUri(url),
      );

      final cookieString = cookies
        .map((c) => "${c.name}=${c.value}")
        .join("; ");

      final response = await dio.download(
        url,
        filePath,
        options: Options(
          responseType: ResponseType.stream, 
          headers: {
            "Cookie": cookieString,
          },
        ),

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

      final file = File(filePath);
      if (response.statusCode == 200 && await file.exists()) {
        final fileSize = await file.length();

        if (fileSize == 0) {
          throw Exception("File kosong");
        }

        await Future.delayed(const Duration(milliseconds: 500));

        _scanMedia(filePath);

        await NotificationService.plugin.cancel(id: notificationId);

        await DownloadNotificationHelper.showDownloadCompleteNotification(
          notificationId,
          uniqueFileName,
          filePath,
        );

        hideLoadingToast();
        showFloatingToast(
          context,
          'Download Selesai',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        showDownloadCompleteDialog(filePath);

        return;
      }
        hideLoadingToast();
        await NotificationService.plugin.cancel(id: notificationId);
        await DownloadNotificationHelper.showDownloadErrorNotification(notificationId, uniqueFileName, 'Gagal menyimpan file');
      } catch (e) {
          debugPrint('File copy failed: $e');
          hideLoadingToast();
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

  static OverlayEntry? _loadingToast;
  static void showLoadingToast(BuildContext context) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _loadingToast?.remove(); // jaga2 kalau dobel

    _loadingToast = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).size.height * 0.15,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "Downloading...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_loadingToast!);
  }

  static void showFloatingToast(
    BuildContext context,
    String message, {
    bool isSuccess = false,
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).size.height * 0.15,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green : Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  static void hideLoadingToast() {
    _loadingToast?.remove();
    _loadingToast = null;
  }

  
  static Future<void> _scanMedia(String tempPath) async {
    try {
        await MediaScanner.loadMedia(path: tempPath);

      debugPrint('Scan media to recent');
    } catch (e) {
      debugPrint('Mediastore save failed: $e');
    }
  }
  
  static String _processHTMLForPDF(String rawHTML) {
    String cleaned = rawHTML
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; font-size: 12px; line-height: 1.6; color: #333; padding: 15px; }
        h1, h2, h3, h4, h5, h6 { margin: 10px 0 8px 0; font-weight: bold; }
        h1 { font-size: 20px; } h2 { font-size: 16px; } h3 { font-size: 14px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #999; padding: 8px; text-align: left; }
        th { background-color: #f0f0f0; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        img { max-width: 100%; height: auto; margin: 10px 0; }
        .footer { text-align: center; margin-top: 30px; font-size: 10px; border-top: 1px solid #ccc; padding-top: 10px; }
        a { color: #0066cc; text-decoration: underline; }
      </style>
    </head>
    <body>
      $cleaned
      <div class="footer">
        <p>Generated: ${DateTime.now().toString().split('.')[0]}</p>
      </div>
    </body>
    </html>
  ''';
  }
}
