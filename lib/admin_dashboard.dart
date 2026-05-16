import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'shop_detail_page.dart';
import 'admin_billing_screen.dart'; // ✅ NEW IMPORT

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final Color primaryColor = const Color(0xFFF4511E);
  final Color appBarTextColor = const Color(0xFFF4511E);
  int selectedIndex = 0;

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

  /// 🔥 FIRESTORE STATUS UPDATE FUNCTION (REAL LOGIC)
  Future<void> _updateShopStatus(
    String shopId,
    String status, {
    String? reason,
  }) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'status': status,
      'rejection_reason': status == "rejected" ? reason ?? "" : "",
    });
  }

  Stream<int> _count(String collection, {String? status}) {
    Query ref = FirebaseFirestore.instance.collection(collection);
    if (status != null) {
      ref = ref.where('status', isEqualTo: status);
    }
    return ref.snapshots().map((s) => s.docs.length);
  }

  // ✅ NEW: Pending billing count stream
  Stream<int> _pendingBillingCount() {
    return FirebaseFirestore.instance
        .collection('billing')
        .where('payment_status', isEqualTo: 'pending_verification')
        .snapshots()
        .map((s) => s.docs.length);
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

            // ✅ NEW: billing_status badge
            final billingStatus = data['billing_status'] ?? 'active';

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
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['shop_name'] ?? "Unnamed Shop",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // ✅ NEW: Show suspended badge on shop card
                    if (billingStatus == 'suspended')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'SUSPENDED',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(data['owner_name'] ?? "Unknown Owner"),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailPage(
                        shopId: shop.id,
                        shopData: data,
                        onStatusChange:
                            (String status, {String? reason}) async {
                          await _updateShopStatus(
                            shop.id,
                            status,
                            reason: reason,
                          );
                        },
                      ),
                    ),
                  );
                  if (result == true) {
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // ✅ NEW: Billing button widget for dashboard
  Widget _billingButton() {
    return StreamBuilder<int>(
      stream: _pendingBillingCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminBillingScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pendingCount > 0
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pendingCount > 0
                    ? Colors.orange.shade300
                    : Colors.green.shade300,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: pendingCount > 0
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Platform Billing',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pendingCount > 0
                            ? '$pendingCount receipt(s) waiting for verification'
                            : 'All payments verified',
                        style: TextStyle(
                          fontSize: 12,
                          color: pendingCount > 0
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: pendingCount > 0
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
              ],
            ),
          ),
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
              "assets/logo9.jpeg",
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
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.grey),
              ),
              accountName: Text(user?.displayName ?? "Admin"),
              accountEmail: Text(user?.email ?? ""),
            ),
            // ✅ NEW: Billing shortcut in drawer
            ListTile(
              leading: const Icon(
                  Icons.account_balance_wallet, color: Colors.orange),
              title: const Text('Platform Billing'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminBillingScreen()),
                );
              },
            ),
            Expanded(child: ListView(children: [])),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout",
                  style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Stats Grid ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _dashboardCard("Total Users", Icons.people,
                      Colors.green, _count("users")),
                  _dashboardCard("Total Shops", Icons.store,
                      primaryColor, _count("shops")),
                  _dashboardCard(
                      "Verified Shops",
                      Icons.verified,
                      Colors.blue,
                      _count("shops", status: "verified")),
                  _dashboardCard(
                      "Pending Shops",
                      Icons.hourglass_top,
                      Colors.orange,
                      _count("shops", status: "pending")),
                ],
              ),
            ),

            // ✅ NEW: Billing Button — admin can see pending receipts
            _billingButton(),
            const SizedBox(height: 16),

            // ── Shop Verification Tabs ──
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
            _shopList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}