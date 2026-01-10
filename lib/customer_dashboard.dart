import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'role_selection_screen.dart';
import 'shop_products_screen.dart';
import 'services/location_service.dart';
import 'screens/map_screen.dart'; // ✅ Map screen import

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  String _searchText = "";

  Position? _currentPosition;
  String _locationStatus = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationStatus = "Location fetched";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatus = "Location permission denied";
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  Stream<QuerySnapshot> _getVerifiedShops() {
    return FirebaseFirestore.instance
        .collection('shops')
        .where('status', isEqualTo: 'verified')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 21, 101, 192),
              ),
              accountName: Text(user?.displayName ?? "Customer"),
              accountEmail: Text(user?.email ?? ""),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("Customer Dashboard"),
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
      ),

      // ✅ Floating Button (SAFE)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
        tooltip: "Open Map",
        child: const Icon(Icons.location_on),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
        },
      ),

      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Location status
            Text(
              _currentPosition == null
                  ? _locationStatus
                  : "Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search Shops...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchText = value.toLowerCase());
              },
            ),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getVerifiedShops(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final shops = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['shop_name'] ?? "")
                            .toString()
                            .toLowerCase()
                            .contains(_searchText) ||
                        (data['shop_category'] ?? "")
                            .toString()
                            .toLowerCase()
                            .contains(_searchText);
                  }).toList();

                  if (shops.isEmpty) {
                    return const Center(child: Text("No shops found"));
                  }

                  return ListView.builder(
                    itemCount: shops.length,
                    itemBuilder: (context, index) {
                      final data =
                          shops[index].data() as Map<String, dynamic>;

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(data['shop_name'] ?? ""),
                          subtitle: Text(data['shop_location'] ?? ""),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShopProductsScreen(
                                  shopId: shops[index].id,
                                  shopName: data['shop_name'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}