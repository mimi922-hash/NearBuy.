import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:image_picker/image_picker.dart';

import 'package:http/http.dart' as http;

import 'dart:async'; // ✅ FIX: StreamSubscription ke liye

import 'role_selection_screen.dart';

import 'shop_registration_page.dart';

import 'add_product_page.dart';

import 'shop_reviews_screen.dart';

import 'shopkeeper_orders_screen.dart';

import 'shopkeeper_billing_screen.dart'; // ✅ NEW

class ShopkeeperDashboard extends StatefulWidget {
  const ShopkeeperDashboard({super.key});

  @override
  State<ShopkeeperDashboard> createState() => _ShopkeeperDashboardState();
}

class _ShopkeeperDashboardState extends State<ShopkeeperDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  bool _loading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _shopData;
  String? _shopId;
  String? _profileImageUrl;
  final Color primaryColor = const Color(0xFF1565C0);

  // ✅ FIX: Pending count state variable — StreamBuilder hataya
  int _pendingOrdersCount = 0;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  // ✅ NEW: Billing status
  String _billingStatus = 'active'; // active | suspended
  String _billingPaymentStatus = 'unpaid'; // unpaid | pending_verification | verified | rejected
  StreamSubscription<DocumentSnapshot>? _billingSubscription;

  @override
  void initState() {
    super.initState();
    _checkShop();
    _loadProfileImage();
  }

  @override
  void dispose() {
    // ✅ FIX: Stream cancel karo jab widget destroy ho
    _ordersSubscription?.cancel();
    _billingSubscription?.cancel(); // ✅ NEW
    super.dispose();
  }

  // ✅ FIX: Shop load hone ke baad stream subscribe karo — widget rebuild nahi hogi baar baar
  void _subscribeToPendingOrders(String shopId) {
    _ordersSubscription?.cancel(); // pehli subscription cancel karo agar thi
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingOrdersCount = snapshot.docs.length;
        });
      }
    });
  }

  // ✅ NEW: Billing status subscribe
  void _subscribeToBillingStatus(String shopId) {
    final now = DateTime.now();
    final docId = '${shopId}_${now.year}_${now.month}';
    _billingSubscription?.cancel();
    _billingSubscription = FirebaseFirestore.instance
        .collection('billing')
        .doc(docId)
        .snapshots()
        .listen((snap) {
      if (mounted && snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        setState(() {
          _billingPaymentStatus = d['payment_status'] ?? 'unpaid';
        });
      }
    });
  }

  // Cloudinary Upload Logic
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        String cloudName = "dxzaqavfj";
        String uploadPreset = "nearbuy_preset";

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
        );

        request.fields['upload_preset'] = uploadPreset;
        request.files.add(
            await http.MultipartFile.fromPath('file', pickedFile.path));

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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Profile updated successfully!")),
          );
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _loadProfileImage() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    if (doc.exists && doc.data()?['profile_image'] != null) {
      setState(() {
        _profileImageUrl = doc.data()!['profile_image'];
      });
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

  void _checkShop() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .where('owner_email', isEqualTo: user?.email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _shopData = snapshot.docs.first.data();
      _shopId = snapshot.docs.first.id;

      // ✅ FIX: Shop mil gai — ab orders stream subscribe karo
      if (_shopData!['status'] == 'verified') {
        _subscribeToPendingOrders(_shopId!);
        _subscribeToBillingStatus(_shopId!); // ✅ NEW
        _billingStatus = _shopData!['billing_status'] ?? 'active'; // ✅ NEW
      }
    }

    setState(() {
      _loading = false;
    });
  }

  void _clearNotification() {
    if (_shopId != null) {
      FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopId)
          .update({'notification': ""});

      setState(() {
        _shopData!['notification'] = "";
      });
    }
  }

  Widget _productList() {
    if (_shopId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopId)
          .collection('products')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs;

        if (products.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No products added yet.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: products.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("Price: Rs.${data['price']}"),
                          if (data['description'] != null &&
                              data['description']
                                  .toString()
                                  .isNotEmpty)
                            Text(
                              data['description'],
                              style: TextStyle(
                                  color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddProductPage(
                                  shopId: _shopId!,
                                  editProductId: doc.id,
                                  editData: data,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('shops')
                                .doc(_shopId)
                                .collection('products')
                                .doc(doc.id)
                                .delete();
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _reviewButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.rate_review, color: Colors.white),
      label: const Text(
        "Manage Reviews",
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        elevation: 5,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopReviewsPage(shopId: _shopId!),
          ),
        );
      },
    );
  }

  // ✅ NEW: Billing button + suspended banner
  Widget _billingButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') {
      return const SizedBox.shrink();
    }
    return ElevatedButton.icon(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white),
          if (_billingPaymentStatus == 'unpaid' ||
              _billingPaymentStatus == 'rejected')
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
      label: Text(
        _billingPaymentStatus == 'pending_verification'
            ? 'Billing — Verification Pending'
            : _billingPaymentStatus == 'verified'
                ? 'Billing — Paid ✓'
                : 'Monthly Billing — Pay Now',
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _billingPaymentStatus == 'verified'
            ? Colors.green
            : _billingPaymentStatus == 'pending_verification'
                ? Colors.orange.shade600
                : Colors.red.shade600,
        elevation: 5,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ShopkeeperBillingScreen(shopId: _shopId!),
          ),
        );
      },
    );
  }

  // ✅ NEW: Suspended warning banner
  Widget _suspendedBanner() {
    if (_billingStatus != 'suspended') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠️ Your shop is temporarily hidden from customers.\nPay the platform fee and upload JazzCash receipt.',
              style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  // Ab yeh widget sirf tab rebuild hoga jab count change ho — poora dashboard rebuild nahi hoga
  Widget _ordersButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') {
      return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: Colors.white),
          if (_pendingOrdersCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_pendingOrdersCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      label: Text(
        _pendingOrdersCount > 0
            ? "Manage Orders ($_pendingOrdersCount pending)"
            : "Manage Orders",
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade700,
        elevation: 5,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ShopkeeperOrdersScreen(shopId: _shopId!),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              accountName: Text(
                  user?.displayName ?? "Shopkeeper",
                  style:
                      const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(Icons.person,
                              color: primaryColor, size: 40)
                          : null,
                    ),
                    if (_isUploading)
                      const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 15),
                      ),
                    )
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("View Profile"),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        const SizedBox(height: 15),
                        Text(
                            user?.displayName ?? "Shopkeeper",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(user?.email ?? "",
                            style:
                                const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"))
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            _loading
                ? const CircularProgressIndicator()
                : _shopData != null
                    ? ListTile(
                        leading: const Icon(Icons.store),
                        title: const Text("Your Shop"),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title:
                                  const Text("Your Shop Details"),
                              content: Text(
                                  "Name: ${_shopData!['shop_name']}\nLocation: ${_shopData!['shop_location']}\nContact: ${_shopData!['owner_contact']}\nStatus: ${_shopData!['status']}"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text("Close"),
                                )
                              ],
                            ),
                          );
                        },
                      )
                    : ListTile(
                        leading: const Icon(Icons.add_business),
                        title: const Text("Register Shop"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ShopRegistrationPage()),
                          ).then((_) => _checkShop());
                        },
                      ),
            if (_shopData != null &&
                _shopData!['status'] == 'verified')
              ListTile(
                leading: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.orange),
                title: const Text("Manage Orders"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopkeeperOrdersScreen(
                          shopId: _shopId!),
                    ),
                  );
                },
              ),
            // ✅ NEW: Billing shortcut in drawer
            if (_shopData != null &&
                _shopData!['status'] == 'verified')
              ListTile(
                leading: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _billingPaymentStatus == 'verified'
                      ? Colors.green
                      : Colors.red,
                ),
                title: const Text("Monthly Billing"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopkeeperBillingScreen(shopId: _shopId!),
                    ),
                  );
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout",
                  style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Shopkeeper Dashboard"),
        backgroundColor: primaryColor,
        actions: [
          if (_shopData != null &&
              _shopData!['notification'] != null &&
              _shopData!['notification'] != "")
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  const Positioned(
                    right: 0,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Notification"),
                    content: Text(_shopData!['notification']),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _clearNotification();
                          Navigator.pop(context);
                        },
                        child: const Text("OK"),
                      ),
                      if (_shopData!['status'] == 'verified')
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddProductPage(
                                    shopId: _shopId!),
                              ),
                            );
                          },
                          child: const Text("Add Product"),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _shopData != null
                      ? Column(
                          children: [
                            _suspendedBanner(), // ✅ NEW
                            const Icon(Icons.store_mall_directory,
                                size: 80,
                                color: Color.fromARGB(
                                    255, 21, 101, 192)),
                            const SizedBox(height: 20),
                            const Text(
                              "Your Shop is Registered!",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Shop Name: ${_shopData!['shop_name']}\nLocation: ${_shopData!['shop_location']}\nContact: ${_shopData!['owner_contact']}\nStatus: ${_shopData!['status']}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 20),
                            if (_shopData!['status'] ==
                                'verified') ...[
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            AddProductPage(
                                                shopId:
                                                    _shopId!)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  minimumSize:
                                      const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                ),
                                child: const Text("Add Product",
                                    style: TextStyle(
                                        color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              _ordersButton(),
                              const SizedBox(height: 12),
                              _billingButton(), // ✅ NEW
                              const SizedBox(height: 12),
                              _reviewButton(),
                            ],
                            const SizedBox(height: 20),
                            _productList(),
                          ],
                        )
                      : Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                                Icons.store_mall_directory,
                                size: 80,
                                color: Color.fromARGB(
                                    255, 21, 101, 192)),
                            const SizedBox(height: 20),
                            const Text(
                              "Welcome Shopkeeper!",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Register your shop to get started.",
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ShopRegistrationPage()),
                                ).then((_) => _checkShop());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize:
                                    const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: const Text("Register Shop",
                                  style: TextStyle(
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}

