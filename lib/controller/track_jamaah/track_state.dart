import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../screens/track_jamaah.dart';

abstract class TrackState {
  final List<Jamaah> jamaahs;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final String? routeDistance;
  final String? routeDuration;
  final bool isRouteMode;
  final Jamaah? focusedJamaah;
  final Map<int, bool> jamaahOutsideRadius;
  final bool isSupervisionActive; 


  TrackState({
    this.jamaahs = const [],
    this.markers = const {},
    this.polylines = const {},
    this.routeDistance,
    this.routeDuration,
    this.isRouteMode = false,
    this.focusedJamaah,
    this.jamaahOutsideRadius = const {},
    this.isSupervisionActive = false,
  });
}

class TrackInitial extends TrackState {}

class TrackLoading extends TrackState {
  TrackLoading({
    super.jamaahs,
    super.markers,
    super.polylines,
    super.routeDistance,
    super.routeDuration,
    super.isRouteMode,
    super.focusedJamaah,
    super.jamaahOutsideRadius,
    super.isSupervisionActive,
  });
}

class TrackLoaded extends TrackState {
  TrackLoaded({
    required super.jamaahs,
    required super.markers,
    super.polylines,
    super.routeDistance,
    super.routeDuration,
    super.isRouteMode,
    super.focusedJamaah,
    super.jamaahOutsideRadius,
    super.isSupervisionActive,
  });

  TrackLoaded copyWith({
    List<Jamaah>? jamaahs,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    String? routeDistance,
    String? routeDuration,
    bool? isRouteMode,
    Jamaah? focusedJamaah,
    bool clearRoute = false, 
    required bool isSupervisionActive, 
    required Map<int, bool> jamaahOutsideRadius,
  }) {
    return TrackLoaded(
      jamaahs: jamaahs ?? this.jamaahs,
      markers: markers ?? this.markers,
      polylines: clearRoute ? {} : (polylines ?? this.polylines),
      routeDistance: clearRoute ? null : (routeDistance ?? this.routeDistance),
      routeDuration: clearRoute ? null : (routeDuration ?? this.routeDuration),
      isRouteMode: isRouteMode ?? this.isRouteMode,
      focusedJamaah: clearRoute ? null : (focusedJamaah ?? this.focusedJamaah),
      jamaahOutsideRadius: jamaahOutsideRadius,
      isSupervisionActive: isSupervisionActive,
    );
  }
}

class TrackError extends TrackState {
  final String message;

  TrackError(this.message, {
    super.jamaahs,
    super.markers,
    super.polylines,
    super.routeDistance,
    super.routeDuration,
    super.isRouteMode,
    super.focusedJamaah,
  });
}