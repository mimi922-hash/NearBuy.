import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../shop_products_screen.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

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

      if (mapController != null && _currentLatLng != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(_currentLatLng!),
        );
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  // ---------------- CATEGORY COLOR ----------------
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return Colors.green;
      case 'pharmacy':
        return Colors.blue;
      case 'electronics':
        return Colors.orange;
      case 'restaurant':
        return Colors.red;
      case 'clothing':
        return Colors.pink;
      default:
        return Colors.teal;
    }
  }

  // ---------------- GOOGLE STYLE MARKER (ICON + NAME) ----------------
  Future<BitmapDescriptor> _createLabelMarker(
      String shopName, Color color) async {
    const double width = 320;
    const double height = 140;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint pinPaint = Paint()..color = color;

    // Pin circle
    canvas.drawCircle(const Offset(60, 90), 30, pinPaint);

    // Pin pointer
    final Path path = Path();
    path.moveTo(60, 125);
    path.lineTo(45, 90);
    path.lineTo(75, 90);
    path.close();
    canvas.drawPath(path, pinPaint);

    // White label background
    final RRect labelBg = RRect.fromRectAndRadius(
      const Rect.fromLTWH(110, 45, 190, 55),
      const Radius.circular(12),
    );

    final Paint bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(labelBg, bgPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(labelBg, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: shopName.length > 20
            ? "${shopName.substring(0, 20)}..."
            : shopName,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    textPainter.layout(maxWidth: 170);
    textPainter.paint(canvas, const Offset(120, 60));

    final ui.Image image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());

    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ---------------- FETCH VERIFIED SHOPS ----------------
  void _fetchVerifiedShops() {
    FirebaseFirestore.instance
        .collection('shops')
        .where('status', isEqualTo: 'verified')
        .snapshots()
        .listen((snapshot) async {
      Set<Marker> markers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final double? lat = data['location_lat'];
        final double? lng = data['location_lng'];
        final String category = data['shop_category'] ?? 'Other';
        final String shopName = data['shop_name'] ?? 'Shop';
        final String openTime = data['open_time'] ?? 'N/A';
        final String closeTime = data['close_time'] ?? 'N/A';

        if (lat == null || lng == null) continue;

        final Color markerColor = _getCategoryColor(category);

        // -------- Fetch Reviews --------
        double avgRating = 0.0;
        int reviewCount = 0;

        try {
          final reviewsSnapshot = await FirebaseFirestore.instance
              .collection('shops')
              .doc(doc.id)
              .collection('reviews')
              .get();

          reviewCount = reviewsSnapshot.docs.length;

          if (reviewCount > 0) {
            double total = 0;
            for (var r in reviewsSnapshot.docs) {
              total += (r.data()['rating'] ?? 0).toDouble();
            }
            avgRating = total / reviewCount;
          }
        } catch (e) {
          debugPrint("Rating error: $e");
        }

        final customIcon =
            await _createLabelMarker(shopName, markerColor);

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            icon: customIcon,

            infoWindow: InfoWindow(
              title: shopName,

              // 🔥 FIXED FORMAT (All info visible)
              snippet:
                  "Category: $category | "
                  "🕒 $openTime-$closeTime | "
                  "⭐ ${avgRating.toStringAsFixed(1)} ($reviewCount)",

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopProductsScreen(
                      shopId: doc.id,
                      shopName: shopName,
                    ),
                  ),
                );
              },
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

                if (_currentLatLng != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(_currentLatLng!),
                  );
                }
              },
            ),
    );
  }
}