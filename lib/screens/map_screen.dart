import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? _currentLatLng;
  Set<Marker> _shopMarkers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchVerifiedShops();
  }

  // ---------------- CURRENT LOCATION ----------------
  void _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(_currentLatLng!),
        );
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  // ---------------- FETCH VERIFIED SHOPS ----------------
  void _fetchVerifiedShops() {
    FirebaseFirestore.instance
        .collection('shops')
        .where('status', isEqualTo: 'verified')
        .snapshots()
        .listen((snapshot) {
      Set<Marker> markers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double? lat = data['location_lat'];
        final double? lng = data['location_lng'];

        if (lat == null || lng == null) continue;

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: data['shop_name'] ?? 'Shop',
              snippet:
                  "${data['shop_category'] ?? ''}\n${data['shop_location'] ?? ''}",
            ),
          ),
        );
      }

      setState(() {
        _shopMarkers = markers;
      });
    });
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Shops")),
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLatLng!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _shopMarkers,
              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
    );
  }
}
