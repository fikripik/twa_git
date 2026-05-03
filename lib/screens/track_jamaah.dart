import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controller/track_jamaah/track_bloc.dart';
import '../controller/track_jamaah/track_event.dart';
import '../controller/track_jamaah/track_state.dart';
import '../controller/track_jamaah/track_controller.dart';
import '../config/package_config.dart';

class Jamaah {
  final int id;
  final String name;
  final String fullName;
  final double lat;
  final double lng;
  final DateTime lastUpdateLocation;

  Jamaah({
    required this.id,
    required this.name,
    required this.fullName,
    required this.lat,
    required this.lng,
    required this.lastUpdateLocation,
  });

  factory Jamaah.fromJson(Map<String, dynamic> json) {
    return Jamaah(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      fullName: json['fullName'] ?? '',
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
      lastUpdateLocation: DateTime.parse(json['last_update_location']),
    );
  }
}

class MapTrackerPage extends StatefulWidget {
  final int? idAgen;

  const MapTrackerPage({super.key, this.idAgen});

  @override
  State<MapTrackerPage> createState() => _MapTrackerPageState();
}

class _MapTrackerPageState extends State<MapTrackerPage> with WidgetsBindingObserver{
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _userLocationSub;
  
  final TextEditingController _searchCtrl = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  final ValueNotifier<Jamaah?> _selectedJamaah = ValueNotifier(null);
  final ValueNotifier<CustomTravelMode> _selectedTravelMode = ValueNotifier(CustomTravelMode.driving);
  StreamSubscription? _supervisionSubscription;

  final LatLng _center = const LatLng(-6.2, 106.816666);
  Marker? _userMarker;
  MapType _currentMapType = MapType.normal;

  late TrackBloc _trackBloc;

  @override
  void initState() {
    super.initState();
    _trackBloc = TrackBloc(TrackController(idAgen: widget.idAgen));
    _requestLocationPermission();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchQuery.dispose();
    _selectedJamaah.dispose();
    _userLocationSub?.cancel();
    _supervisionSubscription?.cancel();
    _trackBloc.add(StopSupervisionEvent());
    _trackBloc.close();
    super.dispose();
  }

  void _onMarkerTapped(Jamaah jamaah) {
    _selectedJamaah.value = jamaah;
      _showInfoCard(jamaah, _trackBloc.controller);
  }

  void _clearSelectedJamaah() {
    _selectedJamaah.value = null;
  }

  void _startLiveJamaahUpdate() {
  final state = _trackBloc.state;
  
  if (state is TrackLoaded && state.isRouteMode && state.focusedJamaah != null) {
    _trackBloc.add(FetchJamaahEvent(
      travelMode: _selectedTravelMode.value,
      jamaahId: state.focusedJamaah?.id.toString(),
    ));
  } else {
    // ✅ Add FetchJamaahEvent and wait for response via listener
    _trackBloc.add(FetchJamaahEvent());

    // Listen for when FetchJamaahEvent completes (state becomes TrackLoaded)
    _supervisionSubscription = _trackBloc.stream.listen((newState) {
      if (newState is TrackLoaded && _userMarker != null) {
        debugPrint('📦 Jamaah data loaded, starting supervision...');
        _trackBloc.add(StartSupervisionEvent(tourLeaderLocation: _userMarker!.position));
        debugPrint("Supervision started with tour leader location: ${_userMarker!.position.latitude}, ${_userMarker!.position.longitude}");
        _supervisionSubscription?.cancel();
      }
    });
  }
}

  void _requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return;
    }
    _trackUser();
  }

  IconData _getTravelModeIcon(CustomTravelMode mode) {
  switch (mode) {
    case CustomTravelMode.driving:
      return Icons.directions_car;
    case CustomTravelMode.walking:
      return Icons.directions_walk;
    case CustomTravelMode.twoWheeler:
      return Icons.motorcycle;
  }
}

  void _trackUser() {
    _userLocationSub?.cancel();
    _userLocationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      
      final marker = Marker(
        markerId: const MarkerId('user'),
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );

      setState(() => _userMarker = marker);
      _trackBloc.add(UpdateUserMarkerEvent(marker));

      final state = _trackBloc.state;
      _sendLocationToBackend(latLng);
      debugPrint("Sent tour leader with id ${widget.idAgen} location to backend: ${latLng.latitude}, ${latLng.longitude}");
      
      // Update route if in route mode
      if (state is TrackLoaded && state.isRouteMode && state.focusedJamaah != null) {
        _trackBloc.add(DrawRouteEvent(
          jamaah: state.focusedJamaah!,
          userLocation: latLng,
          fromLiveUpdate: true,
          travelMode: _selectedTravelMode.value,
        ));
      } else if (state is TrackLoaded && state.isSupervisionActive) {
        _trackBloc.add(CheckRadiusEvent(tourLeaderLocation: latLng));
      }
    });
  }

  void _toggleMapType() {
    const types = [MapType.normal, MapType.satellite, MapType.terrain, MapType.hybrid];
    setState(() {
      _currentMapType = types[(types.indexOf(_currentMapType) + 1) % types.length];
    });
  }

  String formatLastUpdate(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Future<void> _showInfoCard(Jamaah j, TrackController controller) async {
    String location = 'Lokasi tidak tersedia';
    var hasLocation = controller.hasValidLocation(j);

    if (hasLocation) {
      try {
        final p = await placemarkFromCoordinates(j.lat, j.lng);
        if (p.isNotEmpty) {
          location = [p.first.locality, p.first.administrativeArea]
              .whereType<String>()
              .join(', ');
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        iconPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Material (
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  Icons.person_pin_circle,
                  color: hasLocation ? Colors.blue : Colors.red,
                ),
                title: Text(
                  j.fullName,
                  style: TextStyle(
                    color: hasLocation ? Colors.black : Colors.red,
                    decoration: hasLocation ? TextDecoration.none : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '$location\nTerakhir update: ${formatLastUpdate(j.lastUpdateLocation)}',
                  style: TextStyle(color: hasLocation ? Colors.grey : Colors.red),
                ),
              ),
            ),
            ValueListenableBuilder<CustomTravelMode>(
              valueListenable: _selectedTravelMode,
              builder: (context, mode, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: CustomTravelMode.values.map((travelMode) {
                      return IconButton(
                        icon: Icon(
                          _getTravelModeIcon(travelMode),
                          color: mode == travelMode ? Colors.blue : Colors.grey,
                        ),
                        onPressed: () {
                          _selectedTravelMode.value = travelMode;
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: hasLocation && _userMarker != null
                  ? () {
                      Navigator.pop(context);
                      _trackBloc.add(DrawRouteEvent(
                        jamaah: j,
                        userLocation: _userMarker!.position,
                        travelMode: _selectedTravelMode.value,
                      ));
                      // _clearSelectedJamaah();
                    }
                  : null,
              icon: const Icon(Icons.directions),
              label: const Text('Tunjukkan Rute'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(TrackState state) {
    final jamaahs = state.jamaahs;
    final controller = _trackBloc.controller;

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomLeft,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text(
              'List Jamaah',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => _searchQuery.value = v.toLowerCase(),
              decoration: InputDecoration(
                hintText: 'Cari nama jamaah...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (_, query, __) {
                final filtered = jamaahs.where((j) {
                  return j.fullName.toLowerCase().contains(query);
                }).toList();
                
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Jamaah tidak ditemukan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final j = filtered[i];
                    final hasLocation = controller.hasValidLocation(j);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: hasLocation ? Colors.blue : Colors.red,
                          child: const Icon(Icons.person, size: 18, color: Colors.white),
                        ),
                        title: Text(
                          j.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasLocation ? Colors.black : Colors.red,
                            decoration: hasLocation ? TextDecoration.none : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          hasLocation
                              ? formatLastUpdate(j.lastUpdateLocation)
                              : 'Lokasi belum tersedia',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasLocation ? Colors.grey : Colors.red,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasLocation ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            hasLocation ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasLocation ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        enabled: hasLocation,
                        onTap: hasLocation
                            ? () {
                                Navigator.pop(context);
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(LatLng(j.lat, j.lng), 16),
                                );
                                _showInfoCard(j, controller);
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BlocProvider.value(
      value: _trackBloc,
      child: BlocBuilder<TrackBloc, TrackState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, dynamic result) {
              if (!didPop) {
                Navigator.pop(context, "${AppConfig.baseUrl}/konsultan/home");
              }
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: isDark ? Colors.black : Colors.white,
                iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
                title: Image.asset(
                  isDark
                      ? 'assets/images/LOGO-VENTOUR-Putih-new.png'
                      : 'assets/images/LOGO-VENTOUR-Hitam-new.png',
                  height: 24,
                  fit: BoxFit.contain,
                ),
                actions: [
                  if (state is TrackLoaded && state.isRouteMode)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _clearSelectedJamaah();
                        _trackBloc.add(CancelRouteEvent());
                      } 
                    ),
                  IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _toggleMapType,
                  ),
                ],
              ),
              drawer: _buildDrawer(state),
              body: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: _center, zoom: 11),
                    onMapCreated: (c) => _mapController = c,
                    markers: state.markers.map((marker) {
                      return marker.copyWith(
                        onTapParam: () {
                          final jamaah = state.jamaahs.firstWhere(
                            (j) => j.lat == marker.position.latitude && j.lng == marker.position.longitude,
                            orElse: () => Jamaah(
                              id: 0,
                              name: '',
                              fullName: '',
                              lat: marker.position.latitude,
                              lng: marker.position.longitude,
                              lastUpdateLocation: DateTime.now(),
                            ),
                          );
                        _onMarkerTapped(jamaah);
                        },
                      );
                    }).toSet(),
                    circles: _userMarker != null 
                    ? {
                      Circle(
                        circleId: const CircleId('supervision_radius'),
                        center: _userMarker!.position,
                        radius: TrackBloc.supervisionRadius,
                        fillColor: Colors.blue.withValues(alpha: 0.1),
                        strokeColor: Colors.blue.withValues(alpha: 0.4),
                        strokeWidth: 2,
                      ),
                    }
                    : {},
                    polylines: state is TrackLoaded ? state.polylines : {},
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapType: _currentMapType,
                    onTap: (latlng) => _clearSelectedJamaah(),
                  ),
                  if (state is TrackLoading && state.jamaahs.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'back_btn',
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context, "${AppConfig.baseUrl}/konsultan/home");
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 32,
                    right: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'track_location_btn',
                      backgroundColor: Colors.white,
                      label: const Text('Lacak Lokasi'),
                      icon: const Icon(Icons.location_on, color: Colors.red),
                      onPressed: () => _startLiveJamaahUpdate(),
                    ),
                  ),
                  if (state is TrackLoaded &&
                      state.isRouteMode &&
                      state.routeDistance != null &&
                      state.routeDuration != null)
                    Positioned(
                      bottom: 100,
                      left: 20,
                      right: 20,
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _selectedTravelMode.value == CustomTravelMode.walking
                                        ? Icons.directions_walk
                                        : _selectedTravelMode.value == CustomTravelMode.twoWheeler
                                            ? Icons.motorcycle
                                            : Icons.directions_car, 
                                        color: Colors.blue
                                  ),
                                  const SizedBox(width: 8),
                                  Text(state.routeDistance!),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.timer, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(state.routeDuration!),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
	
	Future<void> _sendLocationToBackend(LatLng location) async {
		try {
			await _trackBloc.controller.sendTourLeaderLocation(
				latitude: location.latitude,
				longitude: location.longitude,	
				idAgen: widget.idAgen!,
			);
		} catch (e) {
			debugPrint('Failed to send tour leader location: $e');
		}
	}
}