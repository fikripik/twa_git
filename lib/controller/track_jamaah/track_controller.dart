import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import '../../config/package_config.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

class TrackController {
	final int? idAgen;

	TrackController({this.idAgen});

	// Fetch Jamaah from API
	Future<List<Jamaah>> fetchJamaah() async {
		if (idAgen == null) throw Exception('ID Agen is null');

		final url = Uri.parse(
			'${AppConfig.baseUrl}/api_flutter/getJamaahForTracker/$idAgen',
		);
		final response = await http.get(url);

		if (response.statusCode == 200) {
			final List data = jsonDecode(response.body);
			return data.map((e) => Jamaah.fromJson(e)).toList();
		} else {
			throw Exception('Failed to fetch Jamaah: ${response.statusCode}');
		}
	}

	// Validate location
	bool hasValidLocation(Jamaah j) {
		return j.lat != 0 &&
				j.lng != 0 &&
				j.lat >= -90 &&
				j.lat <= 90 &&
				j.lng >= -180 &&
				j.lng <= 180;
	}

	// Update markers with optimization
	Future<Set<Marker>> updateMarkers(
		List<Jamaah> jamaahs,
		Set<Marker> existingMarkers,
		Marker? userMarker,
		Function(Jamaah) onTap,
	) async {
		final Map<String, Marker> existingMarkersMap = {
			for (var marker in existingMarkers) marker.markerId.value: marker,
		};

		final Map<String, Marker> updatedMarkers = {};

		for (var jamaah in jamaahs) {
			if (!hasValidLocation(jamaah)) continue;

			final markerId = jamaah.id.toString();
			final newPosition = LatLng(jamaah.lat, jamaah.lng);

			if (existingMarkersMap.containsKey(markerId)) {
				final existingMarker = existingMarkersMap[markerId]!;

				if (existingMarker.position != newPosition) {
					// Position changed, update marker
					final updatedMarker = existingMarker.copyWith(
						positionParam: newPosition,
					);
					updatedMarkers[markerId] = updatedMarker;
				} else {
					// Position unchanged, reuse existing marker
					updatedMarkers[markerId] = existingMarker;
				}
			} else {
				// Create new marker
				final icon = await createMarkerWithName(jamaah.name);
				final newMarker = Marker(
					markerId: MarkerId(markerId),
					position: newPosition,
					icon: icon,
					anchor: const Offset(0.5, 1),
					onTap: () => onTap(jamaah),
				);
				updatedMarkers[markerId] = newMarker;
			}
		}

		// Add user marker if exists
		if (userMarker != null) {
			updatedMarkers['user'] = userMarker;
		}

		return updatedMarkers.values.toSet();
	}

	// Create custom marker with name
	Future<BitmapDescriptor> createMarkerWithName(String name) async {
		const int w = 200;
		const int h = 100;
		final recorder = ui.PictureRecorder();
		final canvas = Canvas(recorder);
		final bg = Paint()..color = Colors.white;
		final rrect = RRect.fromRectAndRadius(
			Rect.fromLTWH(0, 0, w.toDouble(), h - 32),
			const Radius.circular(20),
		);
		canvas.drawShadow(Path()..addRRect(rrect), Colors.black38, 4, true);
		canvas.drawRRect(rrect, bg);
		
		final tp = TextPainter(
			text: TextSpan(
				text: name,
				style: const TextStyle(
					fontSize: 28,
					color: Colors.black,
					fontWeight: FontWeight.w600,
				),
			),
			maxLines: 1,
			ellipsis: '…',
			textDirection: TextDirection.ltr,
		);
		tp.layout(maxWidth: w - 20);
		tp.paint(canvas, Offset((w - tp.width) / 2, 14));
		canvas.drawCircle(Offset(w / 2, h - 22), 12, Paint()..color = Colors.red);
		
		final img = await recorder.endRecording().toImage(w, h);
		final data = await img.toByteData(format: ui.ImageByteFormat.png);
		return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
	}

	// Fetch route information
  Future<Map<String, String>> fetchRouteInfo({
    required LatLng origin,
    required LatLng destination,
    required String travelMode,
  }) async {
    // Define the backend URL
    final url = Uri.parse('${AppConfig.baseUrl}/api_flutter/fetchLocation');

    // Prepare the request body
      final Map<String, dynamic> requestBody = {
        "origin": {
          "latitude": origin.latitude,
          "longitude": origin.longitude,
        },
        "destination": {
          "latitude": destination.latitude,
          "longitude": destination.longitude,
        },
        "travelMode": travelMode,
      };

      // Prepare the headers
      final headers = {
        'Content-Type': 'application/json',
      };

      try {
        // Send the POST request
        final res = await http.post(
          url,
          headers: headers,
          body: jsonEncode(requestBody),
        );

        // Check for HTTP errors
        if (res.statusCode != 200) {
          throw Exception('Failed to fetch route info: ${res.body}');
        }

        // Parse the response
        final data = jsonDecode(res.body);

        // Handle the response structure
        final distance = data['distance'] ?? 'Unknown';
        final distanceMeters = data['distanceMeters'] ?? 'Unknown';
        final duration = data['duration'] ?? 'Unknown';
        final polyline = data['polyline'] ?? '';
        final speedReadingIntervals = data['speedReadingIntervals'] ?? '[]';

        // Return the parsed data
        return {
          'distance': distance,
          'distanceMeters': distanceMeters,
          'duration': duration,
          'polyline': polyline,
          'speedReadingIntervals': speedReadingIntervals,
        };
      } catch (e) {
        // Handle any errors
        throw Exception('Error fetching route info: $e');
      }
    }

  double calculateDistance(LatLng point1, LatLng point2) {
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

  Future<void> sendTourLeaderLocation({
    required double latitude,
    required double longitude,
    required int idAgen
  }) async {
    final url = '${AppConfig.baseUrl}/api_flutter/update_tour_leader_location?id_agen=$idAgen&lat=$latitude&lng=$longitude';
    
    try {
      debugPrint('Sending location to backend: $latitude, $longitude for idAgen: $idAgen');
      final response = await http.post(Uri.parse(url));
      debugPrint('Response: ${response.body}');
  
      if (response.statusCode != 200) {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }
}