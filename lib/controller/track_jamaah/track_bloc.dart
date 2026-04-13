import 'package:bloc/bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../config/package_config.dart';
import 'track_event.dart';
import 'track_state.dart';
import 'track_controller.dart';

class TrackBloc extends Bloc<TrackEvent, TrackState> {
  final TrackController controller;

  TrackBloc(this.controller) : super(TrackInitial()) {
    on<FetchJamaahEvent>(_onFetchJamaah);
    on<UpdateMarkersEvent>(_onUpdateMarkers);
    on<DrawRouteEvent>(_onDrawRoute);
    on<CancelRouteEvent>(_onCancelRoute);
    on<UpdateUserMarkerEvent>(_onUpdateUserMarker);
  }

  Future<void> _onFetchJamaah(
      FetchJamaahEvent event, Emitter<TrackState> emit) async {
    try {
			TrackLoaded? previousState;
      
			// Preserve current state while loading
      if (state is! TrackLoaded) {
        emit(TrackLoading());
      } else {
				previousState = state as TrackLoaded;
        emit(TrackLoading(
          jamaahs: previousState.jamaahs,
          markers: previousState.markers,
          polylines: previousState.polylines,
          routeDistance: previousState.routeDistance,
          routeDuration: previousState.routeDuration,
          isRouteMode: previousState.isRouteMode,
          focusedJamaah: previousState.focusedJamaah,
        ));
      }

      final jamaahs = await controller.fetchJamaah();

			if (previousState == null) {
				emit(TrackLoaded(jamaahs: jamaahs, markers: {}));
				add(UpdateMarkersEvent());
				return;
			}

			emit(previousState.copyWith(jamaahs: jamaahs));

			// If we were in route mode, check if focused Jamaah's location changed
      if (previousState.isRouteMode && previousState.focusedJamaah != null) {
        try {
          final updatedFocusedJamaah = jamaahs.firstWhere(
            (j) => j.id == previousState!.focusedJamaah!.id,
            orElse: () => previousState!.focusedJamaah!,
          );
  
          final userMarker = previousState.markers
          .where((m) => m.markerId.value == 'user')
            .firstOrNull;
  
      		// Check auto-redraw conditions ONCE
          if (userMarker != null && 
              controller.hasValidLocation(updatedFocusedJamaah)) {
						emit(previousState.copyWith(focusedJamaah: updatedFocusedJamaah));

            // Trigger auto-redraw with new jamaah location
            add(DrawRouteEvent(
              jamaah: updatedFocusedJamaah,
              userLocation: userMarker.position,
              travelMode: event.travelMode ?? CustomTravelMode.driving,
            ));
            return;
          }
        } catch (e) {
          debugPrint('Auto-redraw failed: $e');
        }
      }

      // Standard update - not in route mode
      add(UpdateMarkersEvent());
    } catch (e) {
      emit(TrackError(
        'Failed to fetch Jamaah: $e',
        jamaahs: state.jamaahs,
        markers: state.markers,
      ));
    }
  }

  Future<void> _onUpdateMarkers(
      UpdateMarkersEvent event, Emitter<TrackState> emit) async {
    if (state is! TrackLoaded) return;

    final currentState = state as TrackLoaded;

    try {
      final markers = await controller.updateMarkers(
        currentState.jamaahs,
        currentState.markers,
        event.userMarker,
        (jamaah) {}, // onTap handled in UI
      );

      emit(currentState.copyWith(markers: markers));
    } catch (e) {
      emit(TrackError(
        'Failed to update markers: $e',
        jamaahs: currentState.jamaahs,
        markers: currentState.markers,
      ));
    }
  }
	
	Future<void> _onDrawRoute(
			DrawRouteEvent event, Emitter<TrackState> emit) async {
			if (state is! TrackLoaded) return;
	
			final currentState = state as TrackLoaded;
	
			try {
				if (!controller.hasValidLocation(event.jamaah)) {
					emit(TrackError(
						'Invalid location for Jamaah',
						jamaahs: currentState.jamaahs,
						markers: currentState.markers,
					));
					return;
				}
	
				final destination = LatLng(event.jamaah.lat, event.jamaah.lng);
	
				// Single source of truth - no duplicate API calls
				final routeInfo = await controller.fetchRouteInfo(
					origin: event.userLocation,
					destination: destination,
					travelMode: event.travelMode.requestName,
				);
	
				// Decode polyline from controller response
				final decoded = PolylinePoints.decodePolyline(routeInfo['polyline'] ?? '');
				final points = decoded
										.map((p) => LatLng(p.latitude, p.longitude))
										.toList();
	
				// Build traffic-aware polylines using speedReadingIntervals
				final polylines = _buildTrafficPolylines(
					points: points,
					intervalsJson: routeInfo['speedReadingIntervals'] ?? '[]',
					useTraffic: event.travelMode != CustomTravelMode.walking,
				);

        final routeDistance = (event.travelMode == CustomTravelMode.walking)
          ? routeInfo['distance']
          : routeInfo['distanceMeters'];
	
				// final focusedMarker = currentState.markers.firstWhere(
				// 	(m) =>
				// 			m.position.latitude == event.jamaah.lat &&
				// 			m.position.longitude == event.jamaah.lng,
				// 	orElse: () => const Marker(markerId: MarkerId('destination')),
				// );

				final focusedMarkerIcon = await controller.createMarkerWithName(event.jamaah.name);
				final focusedMarker = Marker(
						markerId: MarkerId(event.jamaah.id.toString()),
						position: LatLng(event.jamaah.lat, event.jamaah.lng),
						icon: focusedMarkerIcon,
						anchor: const Offset(0.5, 1),
				);
	
				final userMarker = currentState.markers
						.where((m) => m.markerId.value == 'user')
						.toSet();

				emit(currentState.copyWith(
					polylines: polylines,
					routeDistance: routeDistance,
					routeDuration: routeInfo['duration'],
					isRouteMode: true,
					focusedJamaah: event.jamaah,
					markers: {focusedMarker, ...userMarker},
				));
			} catch (e) {
				debugPrint('Route error: $e');
				emit(TrackError(
					'Failed to draw route: $e',
					jamaahs: currentState.jamaahs,
					markers: currentState.markers,
				));
			}
		}
	
		Set<Polyline> _buildTrafficPolylines({
        required List<LatLng> points,
        required String intervalsJson,
        required bool useTraffic,
      }) {
      if (points.length < 2) return {};

      Polyline defaultRoute() => Polyline(
        polylineId: const PolylineId('route_default'),
        points: points,
        width: 6,
        color: const Color(0xFF1E88E5),
      );
      if (!useTraffic) {
        return {defaultRoute()};
      }

      final rawIntervals = (jsonDecode(intervalsJson) as List? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
      if (rawIntervals.isEmpty) {
        return {defaultRoute()};
      }

      final normalized = <Map<String, dynamic>>[];
      for (final seg in rawIntervals) {
        final start = ((seg['startPolylinePointIndex'] as num?)?.toInt() ?? 0)
        .clamp(0, points.length - 1)
        .toInt();

        final end = ((seg['endPolylinePointIndex'] as num?)?.toInt() ?? 0)
        .clamp(0, points.length - 1)
        .toInt();

        final speed = (seg['speed'] ?? 'NORMAL').toString();

        if (end <= start) continue;

        normalized.add({
        'start': start,
        'end': end,
        'speed': speed,
        });
      }

      if (normalized.isEmpty) {
      return {defaultRoute()};
      }

      normalized.sort(
      (a, b) => (a['start'] as int).compareTo(b['start'] as int),
      );

      final merged = <Map<String, dynamic>>[];
      for (final seg in normalized) {
      if (merged.isEmpty) {
      merged.add(Map<String, dynamic>.from(seg));
      continue;
      }

      final last = merged.last;
      final sameSpeed = last['speed'] == seg['speed'];
      final touching = last['end'] == seg['start'];

      if (sameSpeed && touching) {
      last['end'] = seg['end'];
      } else {
      merged.add(Map<String, dynamic>.from(seg));
      }
      }

      final out = <Polyline>{};

      // Base full route first to hide tiny seams between colored segments.
      out.add(
        Polyline(
          polylineId: const PolylineId('route_base'),
          points: points,
          width: 5,
          color: const Color(0xFF90A4AE),
        ),
      );

      for (int i = 0; i < merged.length; i++) {
      final seg = merged[i];
      final s = seg['start'] as int;
      final e = seg['end'] as int;
      final speed = seg['speed'] as String;

      // Convert interval [s, e) to point slice [s, e + 1), then clamp.
      final sliceEndExclusive = (e + 1).clamp(0, points.length).toInt();

      // Only draw valid polyline segments (need at least 2 points).
      if (sliceEndExclusive - s < 2) continue;

      out.add(
        Polyline(
          polylineId: PolylineId('route_seg_$i'),
          points: points.sublist(s, sliceEndExclusive),
          width: 7,
          color: _speedColor(speed),
        ),
      );
    }

      return out.length == 1 ? {defaultRoute()} : out;
    }

	Color _speedColor(String speed) {
    switch (speed) {
      case 'TRAFFIC_JAM':
        return const Color(0xFFE53935); // red
      case 'SLOW':
        return const Color(0xFFFB8C00); // orange
      case 'NORMAL':
      default:
        return const Color(0xFF1E88E5); // blue
    }
  }

  Future<void> _onCancelRoute(
      CancelRouteEvent event, Emitter<TrackState> emit) async {
    if (state is! TrackLoaded) return;

    final currentState = state as TrackLoaded;

    final restoredMarkers = await controller.updateMarkers(
      currentState.jamaahs,
      currentState.markers,
      null,
      (jamaah) {}, // onTap handled in UI
    );
    emit(currentState.copyWith(clearRoute: true, isRouteMode: false, markers: restoredMarkers));
  }

  Future<void> _onUpdateUserMarker(
      UpdateUserMarkerEvent event, Emitter<TrackState> emit) async {
    if (state is! TrackLoaded) return;

    final currentState = state as TrackLoaded;
    
    // Update markers with new user marker
    final updatedMarkers = Set<Marker>.from(currentState.markers);
    updatedMarkers.removeWhere((m) => m.markerId.value == 'user');
    updatedMarkers.add(event.userMarker);

    emit(currentState.copyWith(markers: updatedMarkers));
  }
}