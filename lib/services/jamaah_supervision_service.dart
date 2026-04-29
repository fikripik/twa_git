import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:twa/controller/track_jamaah/track_bloc.dart';
import '../config/package_config.dart';

class JamaahSupervisionService {
  static final JamaahSupervisionService _instance = JamaahSupervisionService._internal();
  
  factory JamaahSupervisionService() {
    return _instance;
  }
  
  JamaahSupervisionService._internal();
  
  Timer? _supervisionTimer;
  StreamSubscription<Position>? _locationSub;
  
  LatLng? _tourLeaderLocation;
  bool _isActive = false;
  bool _wasOutside = false;

  /// Start supervision for Jamaah
  Future<void> startSupervision({
    required LatLng tourLeaderLocation,
  }) async {
    if (_isActive) return;
    
    _tourLeaderLocation = tourLeaderLocation;
    _isActive = true;
    
    // Start location tracking
    _trackJamaahLocation();
  }

  /// Stop supervision
  void stopSupervision() {
    _supervisionTimer?.cancel();
    _locationSub?.cancel();
    _isActive = false;
    _wasOutside = false;
  }

  void _trackJamaahLocation() {
    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!_isActive || _tourLeaderLocation == null) return;
      
      final jamaahLocation = LatLng(position.latitude, position.longitude);
      final distance = _calculateDistance(_tourLeaderLocation!, jamaahLocation);
      final isOutside = distance > TrackBloc.supervisionRadius;
      
      // Check transition: if just went outside
      if (isOutside && !_wasOutside) {
        _wasOutside = true;
        _sendNotification();
      } else if (!isOutside && _wasOutside) {
        _wasOutside = false;
      }
    });
  }

  Future<LatLng> fetchTourLeaderLocation(String idJamaah) async {
    final url = '${AppConfig.baseUrl}/api_flutter/get_tour_leader_location/$idJamaah';
    
    try {
      final response = await http.get(Uri.parse(url));
  
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return LatLng(
          double.parse(json['lat'].toString()),
          double.parse(json['lng'].toString()),
        );
      } else {
        throw Exception('Failed to fetch tour leader location');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }

  Future<void> _sendNotification() async {
    final storage = FlutterSecureStorage();
    final userRole = await storage.read(key: 'auth_role') ?? 'jamaah';
    
    // Get jamaah ID if available
    final jamaahId = await storage.read(key: 'user_id');
    final jamaahName = await storage.read(key: 'user_name') ?? 'Anda';
    
    await NotificationService.showRadiusViolation(
      jamaahId: int.tryParse(jamaahId ?? '0') ?? 0,
      jamaahName: jamaahName,
      userRole: userRole,
    );
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const R = 6371; // Earth's radius in km
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * pi / 180;
    
    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
              cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return R * c * 1000; // Return in meters
  }

  bool get isActive => _isActive;
}