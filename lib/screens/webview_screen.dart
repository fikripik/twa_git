import '../config/package_config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

class WebviewScreen extends StatefulWidget {
  final bool? isLoggedIn;
  final String? initialUrl;
  const WebviewScreen({super.key, this.isLoggedIn, this.initialUrl});

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final WebviewController _webViewController = WebviewController();

  InAppWebViewController? _controller;
  DateTime? _lastBackPressTime;

  bool _locationDialogShown = false;
  bool _prayerScheduled = false;
  late String userAgentString;
  String errorText = '';
  PullToRefreshController? _pullToRefreshController;

  final ValueNotifier<bool> _showWaktuSholat = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.yellow),
      onRefresh: () async {
        if (_controller == null) return;

        if (Platform.isAndroid) {
          await _controller!.reload();
        } else if (Platform.isIOS) {
          final url = await _controller!.getUrl();
          if (url != null) {
            await _controller!.loadUrl(urlRequest: URLRequest(url: url));
          }
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMandatoryPermissions();
      _webViewController.init();
      sendLocationOnce();
      debugPrint('sendLocationOnce called from addPostFrameCallback');
    });
  }

  void _stopRefreshingSafely() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _pullToRefreshController?.endRefreshing();
    });
  }

  Future<void> _checkMandatoryPermissions() async {
    await Future.delayed(const Duration(seconds: 2));
    final locationStatus = await Permission.locationWhenInUse.status;

    if (locationStatus.isGranted) {
      if (_locationDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _locationDialogShown = false;
      }
      if (!_prayerScheduled) {
        _prayerScheduled = true;
        await NotificationService.schedulePrayerNotifications();
      }
      return;
    }

    final requested = await Permission.locationWhenInUse.request();

    if (requested.isGranted) {
      if (_locationDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _locationDialogShown = false;
      }
      await NotificationService.schedulePrayerNotifications();
    } else {
      if (!_locationDialogShown && mounted) {
        _locationDialogShown = true;
        if (Platform.isAndroid) {
          _showLocationRequiredDialog();
        }
      }
    }
  }

  void _showLocationRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Izin Lokasi Wajib'),
        content: const Text(
          'Aplikasi membutuhkan lokasi untuk menentukan jadwal sholat sesuai daerah Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text('Keluar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _openRequiredSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequiredSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(milliseconds: 1000));
    await _openLocationSettings();
  }

  Future<void> sendLocationOnce() async {
    _webViewController.sendLocationOnce();
  }

  Future<void> _openLocationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.LOCATION_SOURCE_SETTINGS',
    );
    await intent.launch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
        _checkMandatoryPermissions();
        sendLocationOnce();
        debugPrint('sendLocationOnce called from didChangeAppLifecycleState.resumed');
      }
    }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webViewController.dispose();
    _showWaktuSholat.dispose();
    super.dispose();
  }

  /* =========================
   * UI & WEBVIEW
   * ========================= */

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (Platform.isAndroid) {
      userAgentString =
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36 VentourFlutter/1.0.0';
    } else {
      userAgentString =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 13_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Mobile/15E148 Safari/604.1 VentourFlutter/1.0.0';
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _webViewController.ready,
      builder: (context, ready, __) {
        if (!ready) {
          return const Scaffold(body: SizedBox());
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (!didPop) {
              if (await _controller!.canGoBack()) {
                _controller!.goBack();
              } else {
                final now = DateTime.now();
                if (_lastBackPressTime == null ||
                    now.difference(_lastBackPressTime!) >
                        const Duration(seconds: 2)) {
                  _lastBackPressTime = now;
                  Fluttertoast.showToast(
                    msg: 'Press back again to exit',
                    backgroundColor: Colors.black54,
                    textColor: Colors.white,
                  );
                } else {
                  SystemNavigator.pop();
                }
              }
            }
          },
          child: SafeArea(
            top: true,
            bottom: false,
            child: Scaffold(
              body: Stack(
                children: [
                  if (errorText.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_off,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                errorText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    errorText = '';
                                  });
                                  _controller?.reload();
                                },
                                child: const Text("Coba Lagi"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  InAppWebView(
                    pullToRefreshController: _pullToRefreshController,
                    initialUrlRequest: URLRequest(
                      url: WebUri(
                        widget.initialUrl ??
                            pendingUrl ??
                            _webViewController.initialUrl.value,
                      ),
                    ),

                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,

                      cacheEnabled: false,
                      clearCache: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      sharedCookiesEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      useHybridComposition: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      allowFileAccess: true,
                      allowContentAccess: true,
                      hardwareAcceleration: true,
                      loadsImagesAutomatically: true,
                      useWideViewPort: true,
                      loadWithOverviewMode: true,
                      allowFileAccessFromFileURLs: true,
                      allowUniversalAccessFromFileURLs: true,
                      useShouldOverrideUrlLoading: true,
                      userAgent: userAgentString,
                    ),
                    onWebViewCreated: (controller) async {
                      _controller = controller;

                      controller.addJavaScriptHandler(
                        handlerName: 'flutterShare',
                        callback: (args) async {
                          if (args.isNotEmpty) {
                            await _webViewController.handleShareMessage(
                              args[0].toString(),
                            );
                          }
                        },
                      );

                      if (widget.isLoggedIn == true) {
                        final storage = const FlutterSecureStorage();
                        final token = await storage.read(key: 'auth_token');
                        final role = await storage.read(key: 'auth_role');

                        if (token != null) {
                          await controller.postUrl(
                            url: WebUri(
                              "${AppConfig.baseUrl}/$role/backdoor/flutter_auth", 
                            ),
                            postData: Uint8List.fromList(
                              utf8.encode("token=$token"),
                            ),
                          );
                          return;
                        }
                      }
                    },

                    onLoadError: (controller, url, code, message) {
                      _stopRefreshingSafely();

                      setState(() {
                        errorText = "Gagal memuat halaman";
                      });
                      if (code == -105) {
                        setState(() {
                          errorText =
                              "Server tidak bisa diakses. Periksa koneksi atau DNS.";
                        });
                      }
                    },
                    onLoadStart: (_, __) {
                      _webViewController.setLoading(true);
                      setState(() {
                        errorText = '';
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        _stopRefreshingSafely();
                      }
                    },

                    onLoadStop: (controller, uri) async {
                      _stopRefreshingSafely();
                      _webViewController.setLoading(false);
                      _webViewController.attachController(controller);
                      await _webViewController.handleJavascript();

                      if (pendingUrl != null) {
                        pendingUrl = null;
                      }
                      if (fcmToken != null) {
                        await InsertToken(
                          controller,
                        ).insertTokenToServer(fcmToken!);
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      final url = request.url.toString();

                      if (url.contains("youtube.com") || url.contains("youtu.be")) {
                        // abaikan error karena kita memang cancel
                        return;
                      }

                      print("❌ WebView error: ${error.description}");
                      _webViewController.setLoading(false);
                    },
                    // onReceivedError: (_, __, error) {
                    //   debugPrint('❌ WebView error: ${error.description}');
                    //   _webViewController.isLoading.value = false;
                    // },

                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          uri.toString();
                          print("HOST: ${uri?.host}");
                          print("URL: $uri");

                          if (uri == null) return NavigationActionPolicy.ALLOW;

                          return await _webViewController.handleNavigation(
                            navigationAction,
                            context,
                          );
                        },

                    onDownloadStartRequest: (controller, request) async {
                      await _webViewController.handleDownloadRequest(
                        context,
                        request.url,
                        request.suggestedFilename,
                      );
                    },
                    // onConsoleMessage: (_, msg) =>
                    //     debugPrint('🧠 JS: ${msg.message}'),
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: _webViewController.isLoading,
                    builder: (context, loading, _) {
                      if (!loading) return const SizedBox.shrink();
                      return const Center(child: CircularProgressIndicator(backgroundColor: Color.fromARGB(50, 0, 0, 0)));
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _showWaktuSholat,
                    builder: (context, show, _) {
                      if (!show) return const SizedBox.shrink();
                      return const Positioned(
                        bottom: 20,
                        right: 20,
                        child: WaktuSholatButton(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
