import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
// Main Orders Screen
// ─────────────────────────────────────────────
class ShopkeeperOrdersScreen extends StatefulWidget {
  final String shopId;

  const ShopkeeperOrdersScreen({super.key, required this.shopId});

  @override
  State<ShopkeeperOrdersScreen> createState() => _ShopkeeperOrdersScreenState();
}

class _ShopkeeperOrdersScreenState extends State<ShopkeeperOrdersScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFF1565C0);
  late TabController _tabController;

  final List<String> _statusTabs = [
    'All',
    'Pending',
    'Confirmed',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // FIX: orderBy hata diya — composite index ki zaroorat nahi
  // Sorting client-side hoti hai
  Stream<QuerySnapshot> _ordersStream(String statusFilter) {
    if (statusFilter == 'All') {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: widget.shopId)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: widget.shopId)
          .where('status', isEqualTo: statusFilter.toLowerCase())
          .snapshots();
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as $newStatus'),
          backgroundColor: _statusColor(newStatus),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'delivered':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // FIX: showModalBottomSheet + DraggableScrollableSheet hata diya
  // Ab seedha full screen push hoti hai — black screen & browsing problem khatam
  void _openOrderDetails(Map<String, dynamic> data, String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          data: data,
          orderId: orderId,
          onStatusUpdate: _updateOrderStatus,
          statusColor: _statusColor,
        ),
      ),
    );
  }

  Widget _buildOrderList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 70, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No ${statusFilter == 'All' ? '' : statusFilter.toLowerCase()} orders yet',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Client-side sort: newest first
        final orders = snapshot.data!.docs.toList();
        orders.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            final status = data['status'] ?? 'pending';
            final items = List.from(data['items'] ?? []);
            final totalAmount = (data['totalAmount'] ?? 0).toDouble();

            Timestamp? ts = data['createdAt'];
            String dateStr = '';
            if (ts != null) {
              final d = ts.toDate();
              dateStr =
                  '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
            }

            return GestureDetector(
              onTap: () => _openOrderDetails(data, orderId),
              child: Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer email + status badge
                      Row(
                        children: [
                          Icon(_statusIcon(status),
                              color: _statusColor(status), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['customerEmail'] ?? 'Customer',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '${items.length} item${items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12),
                          ),
                          Text(
                            'Rs. ${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: const [
                          Icon(Icons.money,
                              size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Cash on Delivery',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 12)),
                          Spacer(),
                          Text('Tap for details',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          Icon(Icons.chevron_right,
                              color: Colors.grey, size: 16),
                        ],
                      ),

                      // Quick action buttons for pending
                      if (status == 'pending') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 8),
                                ),
                                onPressed: () => _updateOrderStatus(
                                    orderId, 'cancelled'),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 8),
                                ),
                                onPressed: () => _updateOrderStatus(
                                    orderId, 'confirmed'),
                                child: const Text('Confirm',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
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
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: primaryColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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

// ─────────────────────────────────────────────
// Order Detail — Alag Full Screen
// (Black screen fix: bottom sheet ki jagah yeh use karo)
// ─────────────────────────────────────────────
class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final Future<void> Function(String orderId, String status) onStatusUpdate;
  final Color Function(String status) statusColor;

  const OrderDetailScreen({
    super.key,
    required this.data,
    required this.orderId,
    required this.onStatusUpdate,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final status = data['status'] ?? 'pending';
    const Color primaryColor = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status card ──
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Order Details',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor(status)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Customer info card ──
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(Icons.person_outline, 'Customer',
                        data['customerEmail'] ?? 'N/A'),
                    const Divider(height: 20),
                    _infoRow(Icons.money, 'Payment', 'Cash on Delivery'),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.tag,
                      'Order ID',
                      orderId.length > 12
                          ? '${orderId.substring(0, 12)}...'
                          : orderId,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Items card ──
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items Ordered:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (item['image_url'] != null &&
                                      item['image_url'] != '')
                                  ? Image.network(
                                      item['image_url'],
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _imagePlaceholder(),
                                    )
                                  : _imagePlaceholder(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: ${item['quantity']}  |  Rs. ${(item['price'] ?? 0).toStringAsFixed(0)} each',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Rs. ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Price summary card ──
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _priceRow(
                      'Subtotal',
                      'Rs. ${(data['subtotal'] ?? 0).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _priceRow(
                      'Platform Fee (5%)',
                      'Rs. ${(data['platformFee'] ?? 0).toStringAsFixed(2)}',
                      color: Colors.orange.shade700,
                    ),
                    const Divider(height: 20),
                    _priceRow(
                      'Total',
                      'Rs. ${(data['totalAmount'] ?? 0).toStringAsFixed(2)}',
                      bold: true,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Action buttons ──
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined,
                          color: Colors.red),
                      label: const Text('Cancel',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await onStatusUpdate(orderId, 'cancelled');
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      label: const Text('Confirm',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await onStatusUpdate(orderId, 'confirmed');
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ] else if (status == 'confirmed') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping,
                      color: Colors.white),
                  label: const Text('Mark as Delivered',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await onStatusUpdate(orderId, 'delivered');
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ',
            style:
                TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 15 : 14,
                color: Colors.grey.shade700)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
