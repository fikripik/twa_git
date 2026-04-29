import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../config/package_config.dart';

class WebviewService {
  final InAppWebViewController controller;
  bool _tokenSent = false;

  WebviewService(this.controller);

  Future<bool> waitForSession({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final cm = CookieManager.instance();
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);
      try {
        final cookies = await cm.getCookies(url: WebUri(AppConfig.cookieUrl));
        final has = cookies.any(
          (c) => c.name == 'PHPSESSID' || c.name == 'remember_me_konsultan',
        );
        if (has) return true;
      } catch (e) {
        debugPrint('Cookie check error: $e');
      }
    }
    return false;
  }

  Future<void> injectSliderHandler() async {

    await controller.evaluateJavascript(source: "window.getPaketPushSelling && window.getPaketPushSelling();");
  }

  Future<void> injectShareHandler() async {
    const js = '''
      (function() {
        navigator.canShare = function(data) { return true; };
        navigator.share = function(data) {
          return new Promise(function(resolve, reject) {
            try {
              window.flutter_inappwebview.callHandler(
                'flutterShare',
                JSON.stringify({
                  title: data.title || '',
                  text:  data.text  || '',
                  url:   data.url   || ''
                })
              );
              resolve();
            } catch(e) {
              reject(e);
            }
          });
        };
      })();
    ''';
    await controller.evaluateJavascript(source: js);
  }

  Future<void> triggerCardHeight() async {
    await controller.evaluateJavascript(
      source: "window.updateCardHeight && window.updateCardHeight();",
    );
  }

  Future<void> sendLocationOnce() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final js =
          """
      fetch('${AppConfig.baseUrl}/api_flutter/send_location', {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'lat=${pos.latitude}&lng=${pos.longitude}'
      })
      .then(res => res.text())
      .then(r => console.log('📍 API response:', r))
      .catch(e => console.log('❌ API error:', e));
    """;

      debugPrint('Send location: ${pos.latitude}, ${pos.longitude}');

      await controller.evaluateJavascript(source: js);
    } catch (e) {}
  }
}
