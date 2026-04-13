import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import '../config/package_config.dart';

class PrayerService {
  static Future<Position> _getUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location service disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<Map<String, TimeOfDay>> fetchPrayerTimesFromApi() async {
    final position = await _getUserLocation();

    final url = Uri.parse(
      'https://api.aladhan.com/v1/timings'
      '?latitude=${position.latitude}'
      '&longitude=${position.longitude}'
      '&method=11',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch prayer times');
    }

    final timings = jsonDecode(response.body)['data']['timings'];

    TimeOfDay parseTime(String value) {
      final clean = value.split(' ')[0];
      final parts = clean.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return {
      'Subuh': parseTime(timings['Fajr']),
      'Dzuhur': parseTime(timings['Dhuhr']),
      'Ashar': parseTime(timings['Asr']),
      'Maghrib': parseTime(timings['Maghrib']),
      'Isya': parseTime(timings['Isha']),
    };

    // return {
    //   'Subuh': TimeOfDay(hour: 4, minute: 30),
    //   'Dzuhur': TimeOfDay(hour: 12, minute: 0),
    //   'Ashar': TimeOfDay(hour: 15, minute: 38),
    //   'Maghrib': TimeOfDay(hour: 15, minute: 40),
    //   'Isya': TimeOfDay(hour: 15, minute: 42),
    // };
  }

  static tz.TZDateTime nextPrayerTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
