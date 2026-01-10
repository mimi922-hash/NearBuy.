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

class _AdminDashboardState extends State<AdminDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final Color primaryColor = const Color(0xFFF4511E); // Orange
  final Color appBarTextColor = const Color(0xFFF4511E); // Orange text

  int selectedIndex = 0; // 0=pending, 1=verified, 2=rejected

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

  Stream<int> _count(String collection, {String? status}) {
    Query ref = FirebaseFirestore.instance.collection(collection);
    if (status != null) {
      ref = ref.where('status', isEqualTo: status);
    }
    return ref.snapshots().map((s) => s.docs.length);
  }

  Widget _counterText(int value) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      builder: (context, val, _) {
        return Text(
          val.toString(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _dashboardCard(
      String title, IconData icon, Color iconColor, Stream<int> stream) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 10),
              _counterText(value),
              Text(title, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }

  Widget _statusTab(String title, int index) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isActive ? primaryColor : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: isActive ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  String _currentStatus() {
    if (selectedIndex == 0) return "pending";
    if (selectedIndex == 1) return "verified";
    return "rejected";
  }

  Widget _shopList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('status', isEqualTo: _currentStatus())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = snapshot.data!.docs;

        if (shops.isEmpty) {
          return Center(child: Text("No ${_currentStatus()} shops"));
        }

        return ListView.builder(
          itemCount: shops.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final shop = shops[index];
            final data = shop.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.store, color: Colors.white),
                ),
                title: Text(
                  data['shop_name'] ?? "Unnamed Shop",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(data['owner_name'] ?? "Unknown Owner"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailPage(
                        shopId: shop.id,
                        shopData: data,
                        onStatusChange: (String status, {String? reason}) {
                          // Placeholder: handle status change if needed
                          print(
                              "Shop status changed: $status, reason: $reason");
                        },
                      ),
                    ),
                  );
                },
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: appBarTextColor),
        title: Text(
          "NearBuy",
          style: TextStyle(
            color: appBarTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              "assets/logo.jpeg",
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              accountName: Text(user?.displayName ?? "Admin"),
              accountEmail: Text(user?.email ?? ""),
            ),
            Expanded(child: ListView(children: [])),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dashboard Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _dashboardCard(
                      "Total Users", Icons.people, Colors.green, _count("users")),
                  _dashboardCard(
                      "Total Shops", Icons.store, primaryColor, _count("shops")),
                  _dashboardCard("Verified Shops", Icons.verified, Colors.blue,
                      _count("shops", status: "verified")),
                  _dashboardCard("Pending Shops", Icons.hourglass_top, Colors.orange,
                      _count("shops", status: "pending")),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Status tabs container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusTab("Pending", 0),
                    _statusTab("Verified", 1),
                    _statusTab("Rejected", 2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Shop list
            _shopList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
