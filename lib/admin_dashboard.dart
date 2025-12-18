import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'shop_detail_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  Stream<QuerySnapshot> _getShops(String status) {
    return FirebaseFirestore.instance
        .collection('shops')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  void _updateStatus(String shopId, String newStatus) {
    FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'status': newStatus,
      'notification': newStatus == 'verified'
          ? 'Your shop has been approved'
          : 'Your shop has been rejected'
    });
  }

  Widget _shopList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getShops(status),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data!.docs;

        if (shops.isEmpty) {
          return Center(
            child: Text("No $status shops"),
          );
        }

        return ListView.builder(
          itemCount: shops.length,
          itemBuilder: (context, index) {
            final shop = shops[index];
            final data = shop.data() as Map<String, dynamic>;

            final shopName = data['shop_name'] ?? "Unnamed Shop";
            final ownerName = data['owner_name'] ?? "Unknown Owner";

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(shopName),
                subtitle: Text(ownerName),

                // 👉 ADMIN TAP TO SEE FULL DETAILS
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailPage(
                        shopId: shop.id,
                        shopData: data,
                        onStatusChange: (newStatus) {
                          _updateStatus(shop.id, newStatus);
                        },
                      ),
                    ),
                  );
                },

                trailing: status == 'pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              _updateStatus(shop.id, 'verified');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              _updateStatus(shop.id, 'rejected');
                            },
                          ),
                        ],
                      )
                    : null,
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
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(25), bottomRight: Radius.circular(25)),
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 21, 101, 192),
              ),
              accountName: Text(
                user?.displayName ?? "Admin",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings,
                    color: Colors.blue, size: 40),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard Overview"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text("Approve Shops"),
              onTap: () {
                _tabController.animateTo(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text("Reports"),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reports feature coming soon!")),
                );
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
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Verified"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _shopList("pending"),
          _shopList("verified"),
          _shopList("rejected"),
        ],
      ),
    );
  }
}