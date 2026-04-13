import '../config/package_config.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  final bool? isLoggedIn;
  final String? initialUrl;
  const SplashScreen({super.key, this.isLoggedIn, this.initialUrl});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        Future.delayed(const Duration(milliseconds: 90), () {
          _goNext();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WebviewScreen(isLoggedIn: widget.isLoggedIn),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Lottie.asset(
            'assets/json/venom_splash.json',
            fit: BoxFit.contain,
            repeat: false,
            controller: _controller,
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward();
            },
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/splash.png',
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      ),
    );
  }
}
