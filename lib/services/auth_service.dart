import '../config/package_config.dart';
import 'package:http/http.dart' as http;

class CekAuth {
  static final _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';

  static Future<bool> checkToken() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      final role = await storage.read(key: 'auth_role');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/$role/login/check_auth'),
        body: {'token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['valid'] == true) {
          return true;
        } else {
          await clearToken();
          return false;
        }
      } else {
        await clearToken();
        return false;
      }
    } catch (e) {
      print('CHECK TOKEN ERROR: $e');
      return false;
    }
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
  }
}
