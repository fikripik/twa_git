import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart'; // 🔥 IMPORT ADHAN

class WaktuSholatPage extends StatefulWidget {
  const WaktuSholatPage({super.key});

  @override
  State<WaktuSholatPage> createState() => _WaktuSholatPageState();
}

class _WaktuSholatPageState extends State<WaktuSholatPage> {
  // Lokasi default (Misal: Kantor Ventour / Jakarta)
  // Nanti bisa diganti pakai Geolocator agar otomatis
  final myCoordinates = Coordinates(-6.2088, 106.8456); // Koordinat Jakarta
  final String locationName = "Jakarta, Indonesia";

  // Variabel untuk menampung jadwal
  late PrayerTimes prayerTimes;

  @override
  void initState() {
    super.initState();
    _calculatePrayerTimes();
  }

  void _calculatePrayerTimes() {
    // 1. Tentukan Parameter Perhitungan (Indonesia biasanya pakai Singapore / Muslim World League)
    final params = CalculationMethod.singapore.getParameters();
    params.madhab = Madhab.shafi;

    // 2. Hitung Waktu Sholat untuk HARI INI
    final date = DateComponents.from(DateTime.now());
    prayerTimes = PrayerTimes(myCoordinates, date, params);
  }

  // Format Jam (HH:mm)
  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    // Tanggal hari ini
    String dateNow = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    // Cek waktu sholat mana yang sedang aktif (Next Prayer)
    Prayer nextPrayer = prayerTimes.nextPrayer();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Jadwal Sholat",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8E24AA), Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 30,
              ),
              const SizedBox(height: 5),
              Text(
                locationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                dateNow,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Waktu Sholat Hari Ini",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔥 DATA REAL DARI ADHAN
                      _buildPrayerItem(
                        "Subuh",
                        _formatTime(prayerTimes.fajr),
                        isActive: nextPrayer == Prayer.fajr,
                      ),
                      _buildPrayerItem(
                        "Syuruq",
                        _formatTime(prayerTimes.sunrise),
                        isActive: nextPrayer == Prayer.sunrise,
                      ),
                      _buildPrayerItem(
                        "Dzuhur",
                        _formatTime(prayerTimes.dhuhr),
                        isActive: nextPrayer == Prayer.dhuhr,
                      ),
                      _buildPrayerItem(
                        "Ashar",
                        _formatTime(prayerTimes.asr),
                        isActive: nextPrayer == Prayer.asr,
                      ),
                      _buildPrayerItem(
                        "Maghrib",
                        _formatTime(prayerTimes.maghrib),
                        isActive: nextPrayer == Prayer.maghrib,
                      ),
                      _buildPrayerItem(
                        "Isya",
                        _formatTime(prayerTimes.isha),
                        isActive: nextPrayer == Prayer.isha,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerItem(String name, String time, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF8E24AA).withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: isActive ? Border.all(color: const Color(0xFF8E24AA)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF8E24AA) : Colors.black87,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? const Color(0xFF8E24AA) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
