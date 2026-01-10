import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'shop_registration_page.dart';
import 'add_product_page.dart';

class ShopkeeperDashboard extends StatefulWidget {
  const ShopkeeperDashboard({super.key});

  @override
  State<ShopkeeperDashboard> createState() => _ShopkeeperDashboardState();
}

class _ShopkeeperDashboardState extends State<ShopkeeperDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  bool _loading = true;
  Map<String, dynamic>? _shopData;
  String? _shopId;

  final Color primaryColor = const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _checkShop();
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
    }

    setState(() => _loading = false);
  }

  void _clearNotification() {
    if (_shopId != null) {
      FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopId)
          .update({'notification': ""});
      setState(() => _shopData!['notification'] = "");
    }
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(.12),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }

  /// 🔧 OVERFLOW FIXED HERE
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
            child: Text("No products added yet.",
                style: TextStyle(color: Colors.grey)),
          );
        }

        return Column(
          children: products.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Product Info
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
                          Text("Price: \$${data['price']}"),
                          if (data['description'] != null &&
                              data['description'].toString().isNotEmpty)
                            Text(
                              data['description'],
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),

                    /// Action Buttons (NO OVERFLOW)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
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
                          icon: const Icon(Icons.delete, color: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Shopkeeper Dashboard"),
        backgroundColor: primaryColor,
        actions: [
          if (_shopData != null &&
              _shopData!['notification'] != null &&
              _shopData!['notification'] != "")
            IconButton(
              icon: const Icon(Icons.notifications_active),
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
                    ],
                  ),
                );
              },
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _shopData == null
                  ? Column(
                      children: [
                        const Icon(Icons.store, size: 90, color: Colors.blue),
                        const SizedBox(height: 20),
                        const Text(
                          "Welcome Shopkeeper",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text("Register your shop to get started"),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: const Size(double.infinity, 52),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShopRegistrationPage(),
                              ),
                            ).then((_) => _checkShop());
                          },
                          child: const Text("Register Shop"),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _infoCard("Shop Name", _shopData!['shop_name'], Icons.store),
                        _infoCard("Location", _shopData!['shop_location'],
                            Icons.location_on),
                        _infoCard("Contact", _shopData!['owner_contact'],
                            Icons.phone),
                        _infoCard("Status", _shopData!['status'], Icons.verified),
                        const SizedBox(height: 20),

                        /// 🔵 PROMINENT ADD PRODUCT BUTTON
                        if (_shopData!['status'] == 'verified')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              "Add Product",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              elevation: 5,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddProductPage(shopId: _shopId!),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                        _productList(),
                      ],
                    ),
            ),
    );
  }
}
