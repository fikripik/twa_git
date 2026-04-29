import 'package:path/path.dart';

import '../config/package_config.dart';

class GoogleLoginView extends StatelessWidget {
  final GoogleAuthService _authService = GoogleAuthService();
  final String type;

  GoogleLoginView({super.key, required this.type});

  String get roleLabel {
    if (type == "affiliator") return "Affiliator";
    return "Konsultan";
  }

  String get urlLink {
    if (type == "affiliator") {
      return "${AppConfig.baseUrl}/affiliator/daftar_affiliator";
    }
    return "${AppConfig.baseUrl}/konsultan/daftar_konsultan";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          Navigator.pop(context, "${AppConfig.baseUrl}/jamaah/masuk");
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF2F5F4),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.black : Colors.white,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context, "${AppConfig.baseUrl}/jamaah/masuk");
            },
          ),
          centerTitle: true,
          title: Image.asset(
            isDark
                ? 'assets/images/LOGO-VENTOUR-Putih-new.png'
                : 'assets/images/LOGO-VENTOUR-Hitam-new.png',
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Bismillah",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Login $roleLabel",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$roleLabel masuk menggunakan email google yang telah terdaftar di Ventour.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  InkWell(
                    onTap: () async {
                      final result = await _authService.signIn(type);
                      debugPrint("Google Sign-In result: $result");

                      if (result != null && context.mounted) {
                        if (result['status_code'] == 400) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? "Login gagal"),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } else {
                          final redirectUrl = result['redirect_url'] as String?;
                          String? tokenFromUrl;
                          
                          if (redirectUrl != null) {
                            try {
                              final uri = Uri.parse(redirectUrl);
                              tokenFromUrl = uri.queryParameters['token'];
                              debugPrint("✅ Extracted token from URL: $tokenFromUrl");
                            } catch (e) {
                              debugPrint('Error parsing redirect_url: $e');
                            }
                          }

                          // ✅ Use token from result OR extracted from URL
                          final token = result['token'] ?? tokenFromUrl;

                          if (token != null) {
                            final storage = FlutterSecureStorage();
                            await storage.write(
                              key: 'auth_token',
                              value: token,
                            );

                            await storage.write(
                              key: 'auth_role',
                              value: type, // saat ini ada konsultan, affiliator
                            );

                            debugPrint("Login berhasil, dengan role $type");
                          }
                          Navigator.pop(context, result['redirect_url']);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            "https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png",
                            width: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Login dengan Google",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Jika email belum terdaftar, silakan hubungi Customer Service.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Belum punya akun? ",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context, urlLink);
                        },
                        child: const Text(
                          "Daftar sekarang",
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
