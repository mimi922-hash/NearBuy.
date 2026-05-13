import 'dart:convert';
import 'dart:async';
 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
 
class ShopkeeperBillingScreen extends StatefulWidget {
  final String shopId;
 
  const ShopkeeperBillingScreen({super.key, required this.shopId});
 
  @override
  State<ShopkeeperBillingScreen> createState() =>
      _ShopkeeperBillingScreenState();
}
 
class _ShopkeeperBillingScreenState
    extends State<ShopkeeperBillingScreen> {
  final Color primaryColor = const Color(0xFF1565C0);
  final user = FirebaseAuth.instance.currentUser;
 
  bool _uploading = false;
 
  // ─── FIX: Cached values — zero flicker nahi hoga ───
  int _cachedTotalOrders = 0;
  double _cachedTotalFee = 0;
  double _cachedTotalSubtotal = 0;
  bool _ordersLoaded = false; // pehli baar data aaya ya nahi
 
  // Current month info
  final int _currentMonth = DateTime.now().month;
  final int _currentYear = DateTime.now().year;
 
  final List<String> _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
 
  String get _monthLabel =>
      '${_monthNames[_currentMonth]} $_currentYear';
 
  // ─── Orders stream ───
  Stream<QuerySnapshot> _ordersStream() {
    final start = DateTime(_currentYear, _currentMonth, 1);
    final end = DateTime(_currentYear, _currentMonth + 1, 1);
 
    return FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: widget.shopId)
        .where('status', isEqualTo: 'delivered')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }
 
  // ─── Billing stream ───
  Stream<DocumentSnapshot> _billingStream() {
    final docId = '${widget.shopId}_${_currentYear}_$_currentMonth';
    return FirebaseFirestore.instance
        .collection('billing')
        .doc(docId)
        .snapshots();
  }
 
  // ─── Save billing record ───
  Future<void> _saveBillingRecord(
      List<QueryDocumentSnapshot> orders) async {
    final docId =
        '${widget.shopId}_${_currentYear}_$_currentMonth';
 
    double totalPlatformFee = 0;
    int totalOrders = orders.length;
 
    for (var order in orders) {
      final data = order.data() as Map<String, dynamic>;
      totalPlatformFee += (data['platformFee'] ?? 0).toDouble();
    }
 
    final billingRef = FirebaseFirestore.instance
        .collection('billing')
        .doc(docId);
 
    final existing = await billingRef.get();
 
    if (!existing.exists ||
        existing['payment_status'] == 'unpaid' ||
        existing['payment_status'] == 'rejected') {
      await billingRef.set({
        'shopId': widget.shopId,
        'month': _currentMonth,
        'year': _currentYear,
        'month_label': _monthLabel,
        'total_orders': totalOrders,
        'total_platform_fee': totalPlatformFee,
        'payment_status':
            existing.exists ? existing['payment_status'] : 'unpaid',
        'receipt_url':
            existing.exists ? existing['receipt_url'] ?? '' : '',
        'submitted_at':
            existing.exists ? existing['submitted_at'] : null,
        'verified_at': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
 
  // ─── Upload receipt ───
  Future<void> _uploadReceipt(double totalFee) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
 
    setState(() => _uploading = true);
 
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
          await http.MultipartFile.fromPath('file', picked.path));
 
      var response = await request.send();
 
      if (response.statusCode == 200) {
        var bytes = await response.stream.toBytes();
        var jsonRes = jsonDecode(String.fromCharCodes(bytes));
        String url = jsonRes['secure_url'];
 
        final docId =
            '${widget.shopId}_${_currentYear}_$_currentMonth';
 
        await FirebaseFirestore.instance
            .collection('billing')
            .doc(docId)
            .set({
          'shopId': widget.shopId,
          'month': _currentMonth,
          'year': _currentYear,
          'month_label': _monthLabel,
          'total_platform_fee': totalFee,
          'receipt_url': url,
          'payment_status': 'pending_verification',
          'submitted_at': FieldValue.serverTimestamp(),
          'verified_at': null,
        }, SetOptions(merge: true));
 
        await FirebaseFirestore.instance
            .collection('admin_notifications')
            .add({
          'type': 'billing_receipt',
          'shopId': widget.shopId,
          'month_label': _monthLabel,
          'message':
              'New JazzCash receipt submitted for $_monthLabel',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Receipt submitted! Admin will verify soon.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Upload failed. Try again.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
 
  // ─── Payment status banner ───
  Widget _paymentStatusBanner(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String message;
 
    switch (status) {
      case 'pending_verification':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        icon = Icons.hourglass_empty;
        message =
            'Receipt submitted. Waiting for admin verification.';
        break;
      case 'verified':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        message =
            'Payment verified! Your shop is active for next month.';
        break;
      case 'rejected':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        message =
            'Receipt rejected. Please re-upload correct JazzCash screenshot.';
        break;
      default:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        icon = Icons.info_outline;
        message =
            'Please pay the platform fee and upload JazzCash receipt.';
    }
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Monthly Billing'),
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream(),
        builder: (context, ordersSnap) {
          // ─── FIX: Sirf tab update karo jab real data aaye ───
          if (ordersSnap.hasData) {
            final orders = ordersSnap.data!.docs;
 
            double fee = 0;
            double subtotal = 0;
 
            for (var o in orders) {
              final d = o.data() as Map<String, dynamic>;
              fee += (d['platformFee'] ?? 0).toDouble();
              subtotal += (d['subtotal'] ?? 0).toDouble();
            }
 
            // Cache update — sirf tab jab values actually change hon
            final newCount = orders.length;
            if (!_ordersLoaded ||
                _cachedTotalOrders != newCount ||
                _cachedTotalFee != fee ||
                _cachedTotalSubtotal != subtotal) {
              _cachedTotalOrders = newCount;
              _cachedTotalFee = fee;
              _cachedTotalSubtotal = subtotal;
              _ordersLoaded = true;
 
              if (orders.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _saveBillingRecord(orders);
                });
              }
            }
          }
 
          // ─── Loading: pehli baar data aane se pehle ───
          if (!_ordersLoaded &&
              ordersSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
 
          // ─── Cached values use karo — zero flicker nahi ───
          final int totalOrders = _cachedTotalOrders;
          final double totalFee = _cachedTotalFee;
          final double totalSubtotal = _cachedTotalSubtotal;
          final List<QueryDocumentSnapshot> orders =
              ordersSnap.data?.docs ?? [];
 
          return StreamBuilder<DocumentSnapshot>(
            stream: _billingStream(),
            builder: (context, billingSnap) {
              final billingData = billingSnap.data?.exists == true
                  ? billingSnap.data!.data() as Map<String, dynamic>
                  : null;
              final paymentStatus =
                  billingData?['payment_status'] ?? 'unpaid';
              final receiptUrl = billingData?['receipt_url'] ?? '';
 
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calendar_month,
                              color: Colors.white, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            _monthLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Billing Summary',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
 
                    // Payment status banner
                    _paymentStatusBanner(paymentStatus),
                    const SizedBox(height: 16),
 
                    // Stats cards
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                'Delivered Orders',
                                '$totalOrders',
                                Icons.shopping_bag,
                                Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _statCard(
                                'Total Sales',
                                'Rs. ${totalSubtotal.toStringAsFixed(0)}',
                                Icons.trending_up,
                                Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 12),
 
                    // Platform fee card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Platform Fee Due (5%)',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Rs. ${totalFee.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pay via JazzCash & upload receipt below',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
 
                    // JazzCash payment details
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payment,
                                    color: Color(0xFF1565C0)),
                                SizedBox(width: 8),
                                Text(
                                  'JazzCash Payment Details',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _infoRow('Account Name', 'NearBuy Admin'),
                            const SizedBox(height: 6),
                            _infoRow(
                                'JazzCash Number', '03XX-XXXXXXX'),
                            const SizedBox(height: 6),
                            _infoRow('Amount to Pay',
                                'Rs. ${totalFee.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            _infoRow('Reference',
                                widget.shopId.substring(0, 8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
 
                    // Receipt preview
                    if (receiptUrl.isNotEmpty) ...[
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Submitted Receipt:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(10),
                                child: Image.network(
                                  receiptUrl,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
 
                    // Upload button
                    if (paymentStatus == 'unpaid' ||
                        paymentStatus == 'rejected') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Icon(Icons.upload_file,
                                  color: Colors.white),
                          label: Text(
                            _uploading
                                ? 'Uploading...'
                                : 'Upload JazzCash Receipt',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                          ),
                          onPressed: _uploading
                              ? null
                              : () => _uploadReceipt(totalFee),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Take a screenshot of JazzCash transaction & upload',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
 
                    const SizedBox(height: 24),
 
                    // Orders list
                    if (orders.isNotEmpty) ...[
                      const Text(
                        'Delivered Orders This Month:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      ...orders.map((o) {
                        final d = o.data() as Map<String, dynamic>;
                        Timestamp? ts = d['createdAt'];
                        String dateStr = '';
                        if (ts != null) {
                          final dt = ts.toDate();
                          dateStr =
                              '${dt.day}/${dt.month}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                              vertical: 5),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long,
                                color: Color(0xFF1565C0)),
                            title: Text(
                                d['customerEmail'] ?? 'Customer',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(dateStr,
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                    'Total: Rs. ${(d['totalAmount'] ?? 0).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.bold)),
                                Text(
                                    'Fee: Rs. ${(d['platformFee'] ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors
                                            .orange.shade700)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20),
                          child: Text(
                            'No delivered orders this month yet.',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
 
  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
 
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
