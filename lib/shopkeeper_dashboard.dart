import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'role_selection_screen.dart';
import 'shop_registration_page.dart';
import 'add_product_page.dart';
import 'shop_reviews_screen.dart';
import 'shopkeeper_orders_screen.dart';
import 'shopkeeper_billing_screen.dart';
 
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
  int _pendingOrdersCount = 0;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  String _billingStatus = 'active';
  String _billingPaymentStatus = 'unpaid';
  StreamSubscription<DocumentSnapshot>? _billingSubscription;
 
  // ── NearBuy Brand Colors ──
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color lightNavy    = Color(0xFF1A3A5C);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  @override
  void initState() {
    super.initState();
    _checkShop();
    _loadProfileImage();
  }
 
  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _billingSubscription?.cancel();
    super.dispose();
  }
 
  // ✅ All logic methods unchanged ──────────────────────
  void _subscribeToPendingOrders(String shopId) {
    _ordersSubscription?.cancel();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => _pendingOrdersCount = snapshot.docs.length);
    });
  }
 
  void _subscribeToBillingStatus(String shopId) {
    final now = DateTime.now();
    final docId = '${shopId}_${now.year}_${now.month}';
    _billingSubscription?.cancel();
    _billingSubscription = FirebaseFirestore.instance
        .collection('billing').doc(docId).snapshots().listen((snap) {
      if (mounted && snap.exists) {
        final d = snap.data() as Map<String, dynamic>;
        setState(() => _billingPaymentStatus = d['payment_status'] ?? 'unpaid');
      }
    });
  }
 
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        var request = http.MultipartRequest('POST',
            Uri.parse('https://api.cloudinary.com/v1_1/dxzaqavfj/image/upload'));
        request.fields['upload_preset'] = 'nearbuy_preset';
        request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));
        var response = await request.send();
        if (response.statusCode == 200) {
          var jsonRes = jsonDecode(String.fromCharCodes(await response.stream.toBytes()));
          String url = jsonRes['secure_url'];
          await FirebaseFirestore.instance.collection('users').doc(user?.uid)
              .set({'profile_image': url}, SetOptions(merge: true));
          setState(() => _profileImageUrl = url);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated!'),
              backgroundColor: accentOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) { debugPrint('Upload Error: $e'); }
      finally { setState(() => _isUploading = false); }
    }
  }
 
  void _loadProfileImage() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (doc.exists && doc.data()?['profile_image'] != null)
      setState(() => _profileImageUrl = doc.data()!['profile_image']);
  }
 
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (r) => false);
  }
 
  void _checkShop() async {
    final snapshot = await FirebaseFirestore.instance.collection('shops')
        .where('owner_email', isEqualTo: user?.email).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      _shopData = snapshot.docs.first.data();
      _shopId = snapshot.docs.first.id;
      if (_shopData!['status'] == 'verified') {
        _subscribeToPendingOrders(_shopId!);
        _subscribeToBillingStatus(_shopId!);
        _billingStatus = _shopData!['billing_status'] ?? 'active';
      }
    }
    setState(() => _loading = false);
  }
 
  void _clearNotification() {
    if (_shopId != null) {
      FirebaseFirestore.instance.collection('shops').doc(_shopId).update({'notification': ''});
      setState(() => _shopData!['notification'] = '');
    }
  }
 
  // ── UI WIDGETS ──────────────────────────────────────
 
  // ✅ Updated product list with brand theme
  Widget _productList() {
    if (_shopId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(_shopId)
          .collection('products').orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A)));
        final products = snapshot.data!.docs;
        if (products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No products added yet.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(
                  color: const Color(0xFFFF6A1A), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('My Products', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0E2A47))),
            ]),
            const SizedBox(height: 10),
            ...products.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: data['image_url'] != null
                            ? Image.network(data['image_url'], width: 64, height: 64, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _productPlaceholder())
                            : _productPlaceholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'], style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0E2A47))),
                            const SizedBox(height: 4),
                            Text('Rs. ${data['price']}',
                                style: const TextStyle(color: Color(0xFFFF6A1A), fontWeight: FontWeight.w600, fontSize: 14)),
                            if (data['description'] != null && data['description'].toString().isNotEmpty)
                              Text(data['description'],
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _iconBtn(Icons.edit_outlined, const Color(0xFF0E2A47), () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AddProductPage(shopId: _shopId!, editProductId: doc.id, editData: data)));
                          }),
                          _iconBtn(Icons.delete_outline, Colors.red.shade400, () {
                            FirebaseFirestore.instance.collection('shops').doc(_shopId)
                                .collection('products').doc(doc.id).delete();
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
 
  Widget _productPlaceholder() => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.image_outlined, color: Color(0xFF0E2A47), size: 28),
  );
 
  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: color, size: 20)),
  );
 
  // ✅ Updated review button
  Widget _reviewButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') return const SizedBox.shrink();
    return _actionButton(
      icon: Icons.rate_review_outlined,
      label: 'Manage Reviews',
      bgColor: const Color(0xFF0E2A47),
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ShopReviewsPage(shopId: _shopId!))),
    );
  }
 
  // ✅ Updated billing button
  Widget _billingButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') return const SizedBox.shrink();
    final Color btnColor = _billingPaymentStatus == 'verified'
        ? Colors.green.shade600
        : _billingPaymentStatus == 'pending_verification'
            ? Colors.orange.shade600
            : Colors.red.shade600;
    final String btnLabel = _billingPaymentStatus == 'pending_verification'
        ? 'Billing — Verification Pending'
        : _billingPaymentStatus == 'verified'
            ? 'Billing — Paid ✓'
            : 'Monthly Billing — Pay Now';
    return _actionButton(
      icon: Icons.account_balance_wallet_outlined,
      label: btnLabel,
      bgColor: btnColor,
      badgeDot: _billingPaymentStatus == 'unpaid' || _billingPaymentStatus == 'rejected',
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ShopkeeperBillingScreen(shopId: _shopId!))),
    );
  }
 
  // ✅ Updated orders button
  Widget _ordersButton() {
    if (_shopData == null || _shopData!['status'] != 'verified') return const SizedBox.shrink();
    return _actionButton(
      icon: Icons.shopping_bag_outlined,
      label: _pendingOrdersCount > 0
          ? 'Manage Orders ($_pendingOrdersCount pending)'
          : 'Manage Orders',
      bgColor: const Color(0xFFFF6A1A),
      badgeCount: _pendingOrdersCount,
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ShopkeeperOrdersScreen(shopId: _shopId!))),
    );
  }
 
  // ✅ Reusable action button widget
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required VoidCallback onPressed,
    bool badgeDot = false,
    int badgeCount = 0,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                if (badgeDot) Positioned(right: -5, top: -5,
                    child: Container(width: 10, height: 10,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                if (badgeCount > 0) Positioned(right: -8, top: -8,
                    child: Container(padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Text('$badgeCount',
                            style: TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.bold)))),
              ],
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
 
  // ✅ Updated suspended banner
  Widget _suspendedBanner() {
    if (_billingStatus != 'suspended') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        const Expanded(child: Text(
          '⚠️ Your shop is temporarily hidden.\nPay platform fee & upload JazzCash receipt.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
 
  // ✅ Stats chip row (new addition for dashboard)
  Widget _statsRow() {
    return Row(children: [
      _statChip(Icons.pending_actions_outlined, '$_pendingOrdersCount', 'Pending', const Color(0xFFFF6A1A)),
      const SizedBox(width: 10),
      _statChip(Icons.storefront_outlined, _shopData != null ? '1' : '0', 'My Shop', const Color(0xFF0E2A47)),
    ]);
  }
 
  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ]),
        ]),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
 
      // ── UPDATED DRAWER ──
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topRight: Radius.circular(28), bottomRight: Radius.circular(28))),
        child: Column(
          children: [
            // Drawer header — navy gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryNavy, lightNavy],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  // Profile avatar
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accentOrange, width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!) : null,
                            child: _profileImageUrl == null
                                ? const Icon(Icons.person, color: primaryNavy, size: 30) : null,
                          ),
                        ),
                        if (_isUploading)
                          const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: accentOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Shopkeeper',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(user?.email ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Drawer items
            _drawerItem(Icons.dashboard_outlined, 'Dashboard', () => Navigator.pop(context)),
            _drawerItem(Icons.person_outline, 'View Profile', () {
              Navigator.pop(context);
              showDialog(context: context, builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 50, backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!) : null,
                      child: _profileImageUrl == null ? const Icon(Icons.person, size: 50) : null),
                  const SizedBox(height: 15),
                  Text(user?.displayName ?? 'Shopkeeper',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy)),
                  Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
                ]),
                actions: [TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: accentOrange)))],
              ));
            }),
            Divider(color: Colors.grey.shade200, height: 1),
            _loading
                ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFFFF6A1A)))
                : _shopData != null
                    ? _drawerItem(Icons.store_outlined, 'Your Shop', () {
                        showDialog(context: context, builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Shop Details', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
                          content: Text('Name: ${_shopData!["shop_name"]}\nLocation: ${_shopData!["shop_location"]}\nContact: ${_shopData!["owner_contact"]}\nStatus: ${_shopData!["status"]}'),
                          actions: [TextButton(onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(color: accentOrange)))],
                        ));
                      })
                    : _drawerItem(Icons.add_business_outlined, 'Register Shop', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ShopRegistrationPage()))
                            .then((_) => _checkShop());
                      }),
            if (_shopData != null && _shopData!['status'] == 'verified') ...[
              _drawerItem(Icons.shopping_bag_outlined, 'Manage Orders', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ShopkeeperOrdersScreen(shopId: _shopId!)));
              }, badge: _pendingOrdersCount > 0 ? '$_pendingOrdersCount' : null, badgeColor: accentOrange),
              _drawerItem(Icons.account_balance_wallet_outlined, 'Monthly Billing', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ShopkeeperBillingScreen(shopId: _shopId!)));
              }, iconColor: _billingPaymentStatus == 'verified' ? Colors.green : Colors.red),
            ],
            const Spacer(),
            Divider(color: Colors.grey.shade200),
            _drawerItem(Icons.logout, 'Logout', _logout, iconColor: Colors.red, labelColor: Colors.red),
            const SizedBox(height: 16),
          ],
        ),
      ),
 
      // ── UPDATED APPBAR ──
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          const Text('Near', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text('Buy', style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold, fontSize: 20)),
        ]),
        actions: [
          if (_shopData != null &&
              _shopData!['notification'] != null &&
              _shopData!['notification'] != '')
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: Row(children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: accentOrange, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications, color: Colors.white, size: 18)),
                        const SizedBox(width: 10),
                        const Text('Notification', style: TextStyle(color: primaryNavy)),
                      ]),
                      content: Text(_shopData!['notification']),
                      actions: [
                        TextButton(onPressed: () { _clearNotification(); Navigator.pop(context); },
                            child: const Text('OK', style: TextStyle(color: accentOrange))),
                        if (_shopData!['status'] == 'verified')
                          TextButton(
                            onPressed: () { Navigator.pop(context); Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AddProductPage(shopId: _shopId!))); },
                            child: const Text('Add Product', style: TextStyle(color: primaryNavy)),
                          ),
                      ],
                    ));
                  },
                ),
                Positioned(top: 10, right: 10,
                  child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: accentOrange, shape: BoxShape.circle))),
              ],
            ),
        ],
      ),
 
      // ── UPDATED BODY ──
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _suspendedBanner(),
                  _shopData != null ? _registeredShopView() : _noShopView(),
                ],
              ),
            ),
    );
  }
 
  // ── Registered shop view ──
  Widget _registeredShopView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shop info card — navy gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryNavy, lightNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accentOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.storefront, color: accentOrange, size: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_shopData!['shop_name'] ?? '', style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_shopData!['shop_location'] ?? '',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ])),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _shopData!['status'] == 'verified'
                        ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _shopData!['status'] == 'verified'
                        ? Colors.green : Colors.orange),
                  ),
                  child: Text(_shopData!['status'].toString().toUpperCase(),
                      style: TextStyle(color: _shopData!['status'] == 'verified'
                          ? Colors.green : Colors.orange,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.phone_outlined, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(_shopData!['owner_contact'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
 
        // Stats row
        if (_shopData!['status'] == 'verified') ...[
          _statsRow(),
          const SizedBox(height: 16),
          // Action buttons
          _actionButton(
            icon: Icons.add_circle_outline,
            label: 'Add Product',
            bgColor: accentOrange,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddProductPage(shopId: _shopId!))),
          ),
          const SizedBox(height: 10),
          _ordersButton(),
          const SizedBox(height: 10),
          _billingButton(),
          const SizedBox(height: 10),
          _reviewButton(),
        ],
        const SizedBox(height: 20),
        _productList(),
      ],
    );
  }
 
  // ── No shop registered view ──
  Widget _noShopView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2A47).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_outlined, size: 72, color: Color(0xFF0E2A47)),
          ),
          const SizedBox(height: 24),
          const Text('Welcome, Shopkeeper!', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0E2A47))),
          const SizedBox(height: 8),
          Text('Register your shop to start selling', style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A1A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_business, color: Colors.white),
              label: const Text('Register Shop', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ShopRegistrationPage())).then((_) => _checkShop()),
            ),
          ),
        ],
      ),
    );
  }
 
  // ── Drawer item helper ──
  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {
    String? badge, Color? badgeColor, Color? iconColor, Color? labelColor,
  }) {
    return ListTile(
      leading: Stack(clipBehavior: Clip.none, children: [
        Icon(icon, color: iconColor ?? const Color(0xFF0E2A47), size: 22),
        if (badge != null) Positioned(right: -6, top: -6,
          child: Container(padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: badgeColor ?? const Color(0xFFFF6A1A), shape: BoxShape.circle),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
      ]),
      title: Text(label, style: TextStyle(
          fontWeight: FontWeight.w500, color: labelColor ?? const Color(0xFF0E2A47))),
      onTap: onTap,
    );
  }
}
