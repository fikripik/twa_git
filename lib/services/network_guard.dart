import '../config/package_config.dart';

class Toast {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static void show(String msg) {
    final context = navKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}

class NetworkGuard {
  static Dio create() {
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          // DNS error / No Internet
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.unknown) {
            Toast.show("Server tidak bisa diakses");
            return handler.resolve(
              Response(
                requestOptions: e.requestOptions,
                data: {"status": "error", "message": "NO_CONNECTION"},
              ),
            );
          }

          // Timeout
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            Toast.show("Koneksi timeout");
            return handler.resolve(
              Response(
                requestOptions: e.requestOptions,
                data: {"status": "error", "message": "TIMEOUT"},
              ),
            );
          }

          return handler.next(e);
        },
      ),
    );

    return dio;
  }
}
