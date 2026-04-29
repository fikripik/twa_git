import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../screens/track_jamaah.dart';

abstract class TrackEvent {}

class FetchJamaahEvent extends TrackEvent {
  final CustomTravelMode? travelMode;
  final String? jamaahId;

  FetchJamaahEvent({this.travelMode, this.jamaahId});
}

class UpdateMarkersEvent extends TrackEvent {
  final Marker? userMarker;

  UpdateMarkersEvent({this.userMarker});
}

  enum CustomTravelMode {
    walking,
    twoWheeler, 
    driving,
  }

  extension CustomTravelModeExtension on CustomTravelMode {
    TravelMode get apiValue {
      switch (this) {
        case CustomTravelMode.walking:
          return TravelMode.walking;
        case CustomTravelMode.twoWheeler:
          return TravelMode.twoWheeler;
        case CustomTravelMode.driving:
          return TravelMode.driving;
      }
    }

    String get requestName {
      switch (this) {
        case CustomTravelMode.walking:
          return 'WALKING';
        case CustomTravelMode.twoWheeler:
          return 'TWO_WHEELER';
        case CustomTravelMode.driving:
          return 'DRIVE';
      }
    }
  }

class DrawRouteEvent extends TrackEvent {
  final Jamaah jamaah;
  final LatLng userLocation;
  final bool fromLiveUpdate;
  final CustomTravelMode travelMode;

  DrawRouteEvent({
    required this.jamaah,
    required this.userLocation,
    this.fromLiveUpdate = false,
    required this.travelMode,
  });
}

class CancelRouteEvent extends TrackEvent {}

class UpdateUserMarkerEvent extends TrackEvent {
  final Marker userMarker;

  UpdateUserMarkerEvent(this.userMarker);
}