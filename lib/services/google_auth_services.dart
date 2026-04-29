import 'package:http/http.dart' as http;
import '../config/package_config.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  Future<Map<String, dynamic>?> signIn(String type) async {
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    String endpoint;

    if (type == "konsultan") {
      endpoint = "/konsultan/login/proses_flutter";
    } else if (type == "affiliator") {
      endpoint = "/affiliator/login/proses_flutter";
    } else {
      throw Exception("Unknown login type");
    }

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      body: {'credential': idToken, 'from': 'flutter'},
    );
    debugPrint("Google Sign-In Response: ${response.body}");
    return jsonDecode(response.body);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
