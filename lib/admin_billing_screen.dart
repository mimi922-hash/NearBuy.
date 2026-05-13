import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFF1565C0);
  late TabController _tabController;

  final List<String> _tabs = [
    'Pending',
    'Verified',
    'Rejected',
    'All'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _billingStream(String filter) {
    var query = FirebaseFirestore.instance.collection('billing');

    if (filter == 'Pending') {
      return query
          .where('payment_status', isEqualTo: 'pending_verification')
          .snapshots();
    } else if (filter == 'Verified') {
      return query
          .where('payment_status', isEqualTo: 'verified')
          .snapshots();
    } else if (filter == 'Rejected') {
      return query
          .where('payment_status', isEqualTo: 'rejected')
          .snapshots();
    } else {
      return query.snapshots();
    }
  }

  // ─── Verify payment ───
  Future<void> _verifyPayment(String billingDocId, String shopId) async {
    await FirebaseFirestore.instance
        .collection('billing')
        .doc(billingDocId)
        .update({
      'payment_status': 'verified',
      'verified_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'billing_status': 'active',
      'billing_verified_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'notification':
          '✅ Your platform fee payment has been verified. Shop is active!',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified. Shop is now active.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ─── Reject payment ───
  Future<void> _rejectPayment(
      String billingDocId, String shopId, String reason) async {
    await FirebaseFirestore.instance
        .collection('billing')
        .doc(billingDocId)
        .update({
      'payment_status': 'rejected',
      'rejection_reason': reason,
      'rejected_at': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'billing_status': 'suspended',
    });

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .update({
      'notification':
          '❌ Payment rejected: $reason. Please re-upload correct JazzCash receipt.',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment rejected. Shop temporarily hidden.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Show receipt + action dialog ───
  void _showBillingDetail(Map<String, dynamic> data, String docId) {
    final shopId = data['shopId'] ?? '';
    final status = data['payment_status'] ?? 'unpaid';
    final receiptUrl = data['receipt_url'] ?? '';
    final monthLabel = data['month_label'] ?? '';
    final fee = (data['total_platform_fee'] ?? 0).toDouble();
    final totalOrders = data['total_orders'] ?? 0;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(monthLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Shop ID: ${shopId.substring(0, 10)}...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _miniStat('Orders', '$totalOrders', Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniStat(
                        'Fee Due', 'Rs. ${fee.toStringAsFixed(2)}', Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(status)),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),

              if (receiptUrl.isNotEmpty) ...[
                const Text('JazzCash Receipt:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    receiptUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Image not available')),
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('No receipt uploaded yet.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),

              if (status == 'pending_verification') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Rejection reason (if rejecting)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (status == 'pending_verification' && receiptUrl.isNotEmpty) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red)),
              onPressed: () async {
                Navigator.pop(context);
                await _rejectPayment(
                    docId,
                    shopId,
                    reasonController.text.isNotEmpty
                        ? reasonController.text
                        : 'Invalid receipt');
              },
              child:
                  const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(context);
                await _verifyPayment(docId, shopId);
              },
              child: const Text('Verify',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_verification':
        return Colors.orange;
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildList(String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _billingStream(filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No ${filter.toLowerCase()} records',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 15)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['submitted_at'] as Timestamp?;
          final bTs = bData['submitted_at'] as Timestamp?;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['payment_status'] ?? 'unpaid';
            final shopId = data['shopId'] ?? '';
            final monthLabel = data['month_label'] ?? '';
            final fee = (data['total_platform_fee'] ?? 0).toDouble();
            final totalOrders = data['total_orders'] ?? 0;
            final hasReceipt = (data['receipt_url'] ?? '').isNotEmpty;

            Timestamp? ts = data['submitted_at'];
            String dateStr = '';
            if (ts != null) {
              final d = ts.toDate();
              dateStr =
                  '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
            }

            return GestureDetector(
              onTap: () => _showBillingDetail(data, docId),
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
                      // Header row
                      Row(
                        children: [
                          const Icon(Icons.store,
                              color: Color(0xFF1565C0), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shopId.length > 15
                                  ? shopId.substring(0, 15) + '...'
                                  : shopId,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status == 'pending_verification'
                                  ? 'PENDING'
                                  : status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(monthLabel,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$totalOrders orders  •  $dateStr',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                          Text(
                            'Rs. ${fee.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── Tap to review row (unchanged) ──
                      Row(
                        children: [
                          Icon(
                            hasReceipt
                                ? Icons.image
                                : Icons.image_not_supported,
                            size: 14,
                            color: hasReceipt ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasReceipt ? 'Receipt uploaded' : 'No receipt',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    hasReceipt ? Colors.green : Colors.grey),
                          ),
                          const Spacer(),
                          const Text('Tap to review',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 16),
                        ],
                      ),
                      // ── Reject/Verify buttons REMOVED from here ──
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

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Platform Billing'),
        backgroundColor: primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _buildList(t)).toList(),
      ),
    );
  }
}