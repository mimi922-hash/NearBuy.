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

  final Color primaryColor = const Color(0xFF1565C0); // logo color

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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs;

        if (products.isEmpty)
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No products added yet.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final productId = products[index].id;

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  data['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text("Price: \$${data['price']}\n${data['description'] ?? ''}"),
                isThreeLine: data['description'] != null && data['description'] != '',
                trailing: Row(
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
                              editProductId: productId,
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
                            .doc(productId)
                            .delete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
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
              accountName: Text(user?.displayName ?? "Shopkeeper", style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, color: Colors.blue, size: 40),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
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
                              title: const Text("Your Shop Details"),
                              content: Text(
                                  "Name: ${_shopData!['shop_name']}\nLocation: ${_shopData!['shop_location']}\nContact: ${_shopData!['owner_contact']}\nStatus: ${_shopData!['status']}"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
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
                            MaterialPageRoute(builder: (_) => ShopRegistrationPage()),
                          ).then((_) => _checkShop());
                        },
                      ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
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
          if (_shopData != null && _shopData!['notification'] != null && _shopData!['notification'] != "")
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  Positioned(
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
                                builder: (_) => AddProductPage(shopId: _shopId!),
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
                            const Icon(Icons.store_mall_directory, size: 80, color: Color.fromARGB(255, 21, 101, 192)),
                            const SizedBox(height: 20),
                            const Text(
                              "Your Shop is Registered!",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Shop Name: ${_shopData!['shop_name']}\nLocation: ${_shopData!['shop_location']}\nContact: ${_shopData!['owner_contact']}\nStatus: ${_shopData!['status']}",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 20),
                            if (_shopData!['status'] == 'verified')
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AddProductPage(shopId: _shopId!)),
                                  );
                                },
                                child: const Text("Add Product"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            const SizedBox(height: 20),
                            _productList(),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.store_mall_directory, size: 80, color: Color.fromARGB(255, 21, 101, 192)),
                            const SizedBox(height: 20),
                            const Text(
                              "Welcome Shopkeeper!",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                                  MaterialPageRoute(builder: (_) => ShopRegistrationPage()),
                                ).then((_) => _checkShop());
                              },
                              child: const Text("Register Shop"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}