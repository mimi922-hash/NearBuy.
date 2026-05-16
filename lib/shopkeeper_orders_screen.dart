import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 
class ShopkeeperOrdersScreen extends StatefulWidget {
  final String shopId;
  const ShopkeeperOrdersScreen({super.key, required this.shopId});
  @override
  State<ShopkeeperOrdersScreen> createState() => _ShopkeeperOrdersScreenState();
}
 
class _ShopkeeperOrdersScreenState extends State<ShopkeeperOrdersScreen>
    with SingleTickerProviderStateMixin {
  // ── Brand Colors ──
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  late TabController _tabController;
  final List<String> _statusTabs = ['All','Pending','Confirmed','Delivered','Cancelled'];
 
  @override
  void initState() { super.initState(); _tabController = TabController(length: _statusTabs.length, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }
 
  // ── All logic unchanged ──────────────────────────────
  Stream<QuerySnapshot> _ordersStream(String statusFilter) {
    if (statusFilter == 'All') return FirebaseFirestore.instance.collection('orders').where('shopId', isEqualTo: widget.shopId).snapshots();
    return FirebaseFirestore.instance.collection('orders').where('shopId', isEqualTo: widget.shopId)
        .where('status', isEqualTo: statusFilter.toLowerCase()).snapshots();
  }
 
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Order marked as $newStatus'), backgroundColor: _statusColor(newStatus),
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)));
  }
 
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':   return const Color(0xFFFF6A1A);
      case 'confirmed': return Colors.blue.shade600;
      case 'delivered': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey;
    }
  }
 
  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':   return Icons.hourglass_top_rounded;
      case 'confirmed': return Icons.check_circle_outline;
      case 'delivered': return Icons.local_shipping_outlined;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.info_outline;
    }
  }
 
  void _openOrderDetails(Map<String, dynamic> data, String orderId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(
        data: data, orderId: orderId, onStatusUpdate: _updateOrderStatus, statusColor: _statusColor)));
  }
 
  Widget _buildOrderList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No ${statusFilter == 'All' ? '' : statusFilter.toLowerCase()} orders yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ]));
        }
        final orders = snapshot.data!.docs.toList();
        orders.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data    = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            final status  = data['status'] ?? 'pending';
            final items   = List.from(data['items'] ?? []);
            final total   = (data['totalAmount'] ?? 0).toDouble();
            Timestamp? ts = data['createdAt'];
            String dateStr = '';
            if (ts != null) { final d = ts.toDate(); dateStr = '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2,'0')}'; }
 
            return GestureDetector(
              onTap: () => _openOrderDetails(data, orderId),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: _statusColor(status), width: 3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_statusIcon(status), color: _statusColor(status), size: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(data['customerEmail'] ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                          overflow: TextOverflow.ellipsis)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 11))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.inventory_2_outlined, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('${items.length} item${items.length == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      const Spacer(),
                      Text('Rs. ${total.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      const Spacer(),
                      const Icon(Icons.money, size: 13, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('COD', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text('Tap for details →', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ]),
                    if (status == 'pending') ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                          onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
                          child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 13)),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E2A47), elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                          onPressed: () => _updateOrderStatus(orderId, 'confirmed'),
                          child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 13)),
                        )),
                      ]),
                    ],
                  ]),
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Manage Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: accentOrange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: _statusTabs.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusTabs.map((s) => _buildOrderList(s)).toList(),
      ),
    );
  }
}
 
// ── Order Detail Screen ──
class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final Future<void> Function(String, String) onStatusUpdate;
  final Color Function(String) statusColor;
  const OrderDetailScreen({super.key, required this.data, required this.orderId, required this.onStatusUpdate, required this.statusColor});
 
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  @override
  Widget build(BuildContext context) {
    final items  = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final status = data['status'] ?? 'pending';
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Order Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                border: Border(left: BorderSide(color: statusColor(status), width: 4))),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: primaryNavy, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor(status))),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor(status), fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 12),
 
          // Customer info card
          _infoCard([
            _infoRow(Icons.person_outline, 'Customer', data['customerEmail'] ?? 'N/A'),
            Divider(height: 18, color: Colors.grey.shade100),
            _infoRow(Icons.money, 'Payment', 'Cash on Delivery'),
            Divider(height: 18, color: Colors.grey.shade100),
            _infoRow(Icons.tag, 'Order ID', orderId.length > 12 ? '${orderId.substring(0, 12)}...' : orderId),
          ]),
          const SizedBox(height: 12),
 
          // Items card
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items Ordered:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy)),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: (item['image_url'] != null && item['image_url'] != '')
                          ? Image.network(item['image_url'], width: 58, height: 58, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder())
                          : _imgPlaceholder()),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryNavy)),
                    const SizedBox(height: 3),
                    Text('Qty: ${item['quantity']}  ·  Rs. ${(item['price'] ?? 0).toStringAsFixed(0)} each',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ])),
                  Text('Rs. ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy)),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 12),
 
          // Price summary card
          _infoCard([
            _priceRow('Subtotal', 'Rs. ${(data['subtotal'] ?? 0).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _priceRow('Platform Fee (5%)', 'Rs. ${(data['platformFee'] ?? 0).toStringAsFixed(2)}', color: accentOrange),
            Divider(height: 18, color: Colors.grey.shade100),
            _priceRow('Total', 'Rs. ${(data['totalAmount'] ?? 0).toStringAsFixed(2)}', bold: true, color: primaryNavy),
          ]),
          const SizedBox(height: 20),
 
          // Action buttons
          if (status == 'pending') ...[
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async { await onStatusUpdate(orderId, 'cancelled'); if (context.mounted) Navigator.pop(context); },
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Confirm', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async { await onStatusUpdate(orderId, 'confirmed'); if (context.mounted) Navigator.pop(context); },
              )),
            ]),
          ] else if (status == 'confirmed') ...[
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping, color: Colors.white),
              label: const Text('Mark as Delivered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async { await onStatusUpdate(orderId, 'delivered'); if (context.mounted) Navigator.pop(context); },
            )),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
 
  Widget _imgPlaceholder() => Container(
    width: 58, height: 58,
    decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.image_outlined, color: primaryNavy, size: 26),
  );
 
  Widget _infoCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    padding: const EdgeInsets.all(16),
    child: Column(children: children),
  );
 
  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 18, color: Colors.grey.shade400),
    const SizedBox(width: 8),
    Text('$label: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryNavy), overflow: TextOverflow.ellipsis)),
  ]);
 
  Widget _priceRow(String label, String value, {bool bold = false, Color? color}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: bold ? 15 : 14, color: Colors.grey.shade600)),
      Text(value, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
    ],
  );
}
