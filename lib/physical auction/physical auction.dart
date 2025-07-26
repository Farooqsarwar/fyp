import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show asin, cos, sqrt, pi, sin;

class AuctionLocation {
  final String id;
  final String name;
  final String phoneNumber;
  final double latitude;
  final double longitude;
  double? distanceFromUser;

  AuctionLocation({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    this.distanceFromUser,
  });
}

class PhysicalAuctions extends StatefulWidget {
  const PhysicalAuctions({super.key});
  @override
  State<PhysicalAuctions> createState() => _PhysicalAuctionsState();
}

class _PhysicalAuctionsState extends State<PhysicalAuctions> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  List<AuctionLocation> _locations = [];
  bool _isLoadingLocation = true;
  bool _locationGranted = false;

  final LatLng _defaultLocation = const LatLng(33.6844, 73.0479); // Islamabad

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled.');
      setState(() {
        _isLoadingLocation = false;
        _locationGranted = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        setState(() {
          _isLoadingLocation = false;
          _locationGranted = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions permanently denied.');
      setState(() {
        _isLoadingLocation = false;
        _locationGranted = false;
      });
      return;
    }

    setState(() {
      _locationGranted = true;
    });

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );

      _addCurrentLocationMarker();
      _loadAuctionLocations();
    } catch (e) {
      _showError('Failed to get current location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition == null) return;

    final marker = Marker(
      markerId: const MarkerId('currentLocation'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      infoWindow: const InfoWindow(title: 'Your Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );

    setState(() {
      _markers.add(marker);
    });
  }

  void _loadAuctionLocations() {
    if (_currentPosition == null) return;

    final locations = [
      AuctionLocation(
        id: '1',
        name: 'CarFirst Auto Auction - Islamabad',
        phoneNumber: '+925112345678',
        latitude: 33.6938,
        longitude: 73.0652,
      ),
      AuctionLocation(
        id: '2',
        name: 'PakWheels Car Auction - Rawalpindi',
        phoneNumber: '+925155432100',
        latitude: 33.6007,
        longitude: 73.0679,
      ),
      AuctionLocation(
        id: '3',
        name: 'Canvas Gallery - Art Auctions',
        phoneNumber: '+925154321987',
        latitude: 33.7071,
        longitude: 73.0525,
      ),
      AuctionLocation(
        id: '4',
        name: 'FurniBid - Furniture Auctions',
        phoneNumber: '+925167890123',
        latitude: 33.6769,
        longitude: 73.0548,
      ),
      AuctionLocation(
        id: '5',
        name: 'Rawalpindi Antique House',
        phoneNumber: '+925176543210',
        latitude: 33.6140,
        longitude: 73.0440,
      ),
    ];

    _calculateDistances(locations);
  }

  void _calculateDistances(List<AuctionLocation> locations) {
    if (_currentPosition == null) return;

    for (var loc in locations) {
      loc.distanceFromUser = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        loc.latitude,
        loc.longitude,
      );
    }

    locations.sort((a, b) => (a.distanceFromUser ?? double.infinity)
        .compareTo(b.distanceFromUser ?? double.infinity));

    _updateUI(locations);
  }

  void _updateUI(List<AuctionLocation> locations) {
    final markers = locations.map((loc) {
      return Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.latitude, loc.longitude),
        infoWindow: InfoWindow(
          title: loc.name,
          snippet: '${loc.distanceFromUser?.toStringAsFixed(2)} km • ${loc.phoneNumber}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }).toSet();

    setState(() {
      _locations = locations;
      _markers.addAll(markers);
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _degToRad(double deg) => deg * pi / 180;

  Future<void> _openGoogleMaps(AuctionLocation location) async {
    if (_currentPosition == null) {
      _showError('Current location not available');
      return;
    }

    final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination = '${location.latitude},${location.longitude}';
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not open Google Maps');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Physical Auctions",style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF000000),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : _defaultLocation,
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: _locationGranted,
                  myLocationButtonEnabled: _locationGranted,
                  onMapCreated: (controller) => _mapController = controller,
                ),
                if (_isLoadingLocation)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Getting location...'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_locations.isNotEmpty)
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.red),
                    title: Text(location.name,style: TextStyle(color: Colors.white),),
                    subtitle: Text('${location.distanceFromUser?.toStringAsFixed(2)} km away',style: TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.directions, color: Colors.blue),
                    onTap: () => _openGoogleMaps(location),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
