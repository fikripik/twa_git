import '../config/package_config.dart';

class WaktuSholatButton extends StatelessWidget {
  const WaktuSholatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WaktuSholatNativePage()),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Waktu Sholat', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// 📄 HALAMAN NATIVE WAKTU SHOLAT
/// ===============================
class WaktuSholatNativePage extends StatelessWidget {
  const WaktuSholatNativePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waktu Sholat')),
      body: const Center(
        child: Text('Native prayer times page', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
