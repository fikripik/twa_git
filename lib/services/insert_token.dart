import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../config/package_config.dart';

class InsertToken {
  final InAppWebViewController controller;

  InsertToken(this.controller);
  Future<void> insertTokenToServer(String fcmToken) async {
    final js =
        """
    fetch('${AppConfig.baseUrl}/api_flutter/send_token', {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: 'token=${Uri.encodeComponent(fcmToken)}'
    })
    .then(res => res.text())
    .then(r => console.log('🔥 send_token response:', r))
    .catch(e => console.log('❌ send_token error:', e));
  """;

    await controller.evaluateJavascript(source: js);
  }
}
