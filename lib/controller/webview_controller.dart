import '../config/package_config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

class WebviewController extends ChangeNotifier {
  static const String loginUrl = '${AppConfig.baseUrl}/jamaah/home';
  WebviewService? _webviewService;

  final ValueNotifier<bool> ready = ValueNotifier(false);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String> initialUrl = ValueNotifier(loginUrl);

  InAppWebViewController? _webController;
  final CookieManager _cookieManager = CookieManager.instance();

  Timer? _tokenDebounce;
  bool _tokenSent = false;

  Future<void> init() async {
    initialUrl.value = loginUrl;
    ready.value = true;
  }

  void attachController(InAppWebViewController controller) {
    _webController = controller;
    _webviewService = WebviewService(controller);
  }

  Future<void> handleJavascript() async {
    if (_webviewService == null) return;
    await _webviewService!.injectSliderHandler();
    await _webviewService!.injectShareHandler();
    await _webviewService!.triggerCardHeight();
  }

  Future<void> handleShareMessage(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final title = data['title'] as String? ?? '';
      final text  = data['text']  as String? ?? '';
      final url   = data['url']   as String? ?? '';

      final shareText = [if (text.isNotEmpty) text, if (url.isNotEmpty) url]
          .join('\n');
    
      await SharePlus.instance.share(
        ShareParams(title: title, text: shareText),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void setLoading(bool loading) => isLoading.value = loading;

  Future<bool> waitForSession({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    return await _webviewService!.waitForSession(
      timeout: timeout,
      pollInterval: pollInterval,
    );
  }

  Future<bool> ensureMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Izin Mikrofon Diperlukan"),
          content: const Text(
            "Untuk bergabung ke audio room, silakan aktifkan izin mikrofon di pengaturan.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text("Buka Pengaturan"),
            ),
          ],
        ),
      );
      return false;
    }

    return false;
  }

  Future<NavigationActionPolicy> handleNavigation(
    NavigationAction navigationAction,
    BuildContext context,
  ) async {
    final uri = navigationAction.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    if (uri.toString().contains('${AppConfig.baseUrl}/jamaah/home_user')) {
      await sendLocationOnce();
      debugPrint('User logged in, location sent');
    }

    if (uri.toString().contains('${AppConfig.baseUrl}/konsultan/login')) {
      final redirectUrl = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GoogleLoginView(type: "konsultan")),
      );

      if (redirectUrl != null) {
        await _webController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(redirectUrl)),
        );
      }

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.toString().contains('${AppConfig.baseUrl}/affiliator/login')) {
      final redirectUrl = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GoogleLoginView(type: "affiliator")),
      );

      if (redirectUrl != null) {
        await _webController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(redirectUrl)),
        );
      }

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.scheme == 'ventour' &&
        uri.toString().startsWith('ventour://location_tracker')) {
      final segments = uri.pathSegments;
      final int? idAgen = segments.isNotEmpty
          ? int.tryParse(segments.last)
          : null;

      if (idAgen == null) {
        return NavigationActionPolicy.CANCEL;
      }

      if (!context.mounted) return NavigationActionPolicy.CANCEL;

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => MapTrackerPage(idAgen: idAgen)));

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.scheme == 'ventour' && uri.host == 'room_chat') {
      final segments = uri.pathSegments;

      if (segments.length < 3) {
        return NavigationActionPolicy.CANCEL;
      }

      final int? idTl = int.tryParse(segments[0]);
      final String jenis = segments[1];
      final String name = segments[2];

      if (idTl == null) {
        return NavigationActionPolicy.CANCEL;
      }

      if (!context.mounted) return NavigationActionPolicy.CANCEL;
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomListPage(
            userId: idTl.toString(),
            jenis: jenis,
            name: name,
            fcmToken: fcmToken.toString(),
          ),
        ),
      );

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.scheme == 'ventour' && uri.host == 'audio_room') {
      final segments = uri.pathSegments;

      if (segments.length < 2) {
        return NavigationActionPolicy.CANCEL;
      }

      final int? packageId = int.tryParse(segments[0]);
      final String rawUserId = segments[1];
      final String userName = segments[2];
      final String jenis = segments[3];

      if (packageId == null) {
        return NavigationActionPolicy.CANCEL;
      }

      if (!context.mounted) return NavigationActionPolicy.CANCEL;

      // String? fcmToken = await FirebaseMessaging.instance.getToken();

      final bool isHost = (jenis == "TL");
      final roomId = "audio_${packageId}_room";
      final String userId = "$jenis-$rawUserId";

      // final hasMic = await ensureMicrophonePermission(context);
      // if (!hasMic) {
      //   debugPrint("❌ Microphone permission denied, abort audio room");
      //   return NavigationActionPolicy.CANCEL;
      // }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return AudioRoomPage(
              roomID: roomId,
              isHost: isHost,
              jenis: jenis,
              userName: userName,
              userId: userId,
            );
          },
        ),
      );

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.scheme == "whatsapp") {
      final waWeb = Uri.parse(
        "https://wa.me/${uri.queryParameters['phone'] ?? ''}",
      );

      try {
        final canOpen = await canLaunchUrl(uri);

        if (canOpen) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(waWeb, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        await launchUrl(waWeb, mode: LaunchMode.externalApplication);
      }

      return NavigationActionPolicy.CANCEL;
    }

    bool isWhatsApp =
        uri.host.contains("wa.me") || uri.host.contains("whatsapp.com");

    bool isYouTube =
        uri.host.contains("youtube.com") ||
        uri.host.contains("youtu.be") ||
        uri.host.contains("youtube-nocookie.com");

    bool isInstagram =
        uri.host.contains("instagram.com");

    bool isFacebook =
        uri.host.contains("facebook.com");

    bool isTikTok =
        uri.host.contains("tiktok.com");

    if (isYouTube) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }

    bool isGoogleMaps =
        uri.host.contains("maps.google.com") ||
        (uri.host.contains("google.com") && uri.path.startsWith("/maps"));

    if (isWhatsApp || isGoogleMaps || isInstagram || isFacebook || isTikTok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }

    if (uri.host.contains('ventour.co.id')) {
      final storage = FlutterSecureStorage();
      final role = await storage.read(key: 'auth_role');

      if (role != null && uri.path == '/$role/logout') {
        await CekAuth.clearToken();
      }

      return NavigationActionPolicy.ALLOW;
    }

    final allowedDomains = [
      'ventour.co.id',
      'accounts.google.com',
      'google.com',
      'gstatic.com',
      'googleapis.com',
      'googleusercontent.com',
      'play.google.com',
      'api-prod.duitku.com',
      'api-sandbox.duitku.com',
      'app-sandbox.duitku.com',
      'app-prod.duitku.com',
      'tdev.kiriminaja',
      'live.cekat.ai',
      'youtube.com',
      'instagram.com',
      'facebook.com',
      'tiktok.com'
    ];

    final isAllowed = allowedDomains.any((d) => uri.host.contains(d));

    return isAllowed
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  Future<void> handleDownloadRequest(
    BuildContext context,
    Uri url,
    String? suggestedFilename,
  ) async {
    await DownloadService.startDownload(
      context: context,
      url: url.toString(),
      suggestedFilename: suggestedFilename,
    );
  }

  Future<bool> canGoBack() async => _webController?.canGoBack() ?? false;
  Future<void> goBack() async => _webController?.goBack();

  @override
  void dispose() {
    _tokenDebounce?.cancel();
    isLoading.dispose();
    ready.dispose();
    initialUrl.dispose();
    super.dispose();
  }

  Future<void> sendLocationOnce() async {
    if (_webviewService == null) return;
    await _webviewService!.sendLocationOnce();
  }
}
