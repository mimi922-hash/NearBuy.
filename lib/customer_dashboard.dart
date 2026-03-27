import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'role_selection_screen.dart';
import 'shop_products_screen.dart';
import 'services/location_service.dart';
import 'screens/map_screen.dart';

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
  
  String? _profileImageUrl;
  String? _displayName; // Local variable for UI update
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _displayName = user?.displayName ?? "Customer";
    _fetchCurrentLocation();
    _loadProfileData(); 
  }

  // --- Profile & Cloudinary Logic ---

  void _loadProfileData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (doc.exists) {
      setState(() {
        _profileImageUrl = doc.data()?['profile_image'];
        if (doc.data()?['name'] != null) {
          _displayName = doc.data()?['name'];
        }
      });
    }
  }

  Future<void> _updateName(String newName) async {
    try {
      // Update in Firebase Auth
      await user?.updateDisplayName(newName);
      // Update in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'name': newName,
      }, SetOptions(merge: true));

      setState(() {
        _displayName = newName;
      });
    } catch (e) {
      debugPrint("Update Name Error: $e");
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        String cloudName = "your_cloud_name"; 
        String uploadPreset = "your_preset";

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
        );

        request.fields['upload_preset'] = uploadPreset;
        request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          var responseData = await response.stream.toBytes();
          var responseString = String.fromCharCodes(responseData);
          var jsonRes = jsonDecode(responseString);
          String url = jsonRes['secure_url'];

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .set({'profile_image': url}, SetOptions(merge: true));

          setState(() {
            _profileImageUrl = url;
          });
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  // --- View Profile Dialog with Edit Feature ---
  void _showProfileDialog() {
    TextEditingController nameController = TextEditingController(text: _displayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Profile Details", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
              child: _profileImageUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 10),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateName(nameController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile Updated!")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- Existing Logic (Unchanged) ---
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
        setState(() => _locationStatus = "Location permission denied");
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
              decoration: const BoxDecoration(color: Color.fromARGB(255, 21, 101, 192)),
              accountName: Text(_displayName ?? "Customer"), // Updated to use state variable
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                      child: _profileImageUrl == null ? const Icon(Icons.person, color: Colors.blue, size: 40) : null,
                    ),
                    if (_isUploading) const Center(child: CircularProgressIndicator(color: Colors.blue)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("View Profile"),
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog();
              },
            ),
            const Divider(),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
        child: const Icon(Icons.location_on),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()));
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              _currentPosition == null ? _locationStatus : "Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: "Search Shops...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getVerifiedShops(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final shops = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['shop_name'] ?? "").toString().toLowerCase().contains(_searchText) ||
                           (data['shop_category'] ?? "").toString().toLowerCase().contains(_searchText);
                  }).toList();
                  if (shops.isEmpty) return const Center(child: Text("No shops found"));
                  return ListView.builder(
                    itemCount: shops.length,
                    itemBuilder: (context, index) {
                      final data = shops[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(data['shop_name'] ?? ""),
                          subtitle: Text(data['shop_location'] ?? ""),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ShopProductsScreen(shopId: shops[index].id, shopName: data['shop_name'])),
                          ),
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