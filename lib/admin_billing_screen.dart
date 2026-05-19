import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ADMIN BILLING SCREEN
//  Flow (matches diagram):
//   Step 5 → View all submitted receipts (All / Pending / Verified / Rejected)
//   Step 6 → Review receipt detail (image + amount breakdown)
//   Step 7 → Verify or Reject (with optional note)
//   Step 8 → Status updated + shopkeeper notified
// ══════════════════════════════════════════════════════════════════════════════

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color primaryBlue  = Color(0xFF1565C0);
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color lightBlue    = Color(0xFF1976D2);
  static const Color accentGreen  = Color(0xFF2E9E6B);
  static const Color accentRed    = Color(0xFFE53935);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color bgColor      = Color(0xFFF0F3F8);
  static const Color cardWhite    = Color(0xFFFFFFFF);
  static const Color greenLight   = Color(0xFFE8F5EE);
  static const Color redLight     = Color(0xFFFFECEC);
  static const Color orangeLight  = Color(0xFFFFF0E8);

  late TabController _tabController;
  final List<String> _tabs = ['All', 'Pending', 'Verified', 'Rejected'];

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

  // ── Firestore streams ─────────────────────────────────────────────────────
  Stream<QuerySnapshot> _billingStream(String filter) {
    final ref = FirebaseFirestore.instance.collection('billing');
    switch (filter) {
      case 'Pending':
        return ref
            .where('payment_status', isEqualTo: 'pending_verification')
            .snapshots();
      case 'Verified':
        return ref
            .where('payment_status', isEqualTo: 'verified')
            .snapshots();
      case 'Rejected':
        return ref
            .where('payment_status', isEqualTo: 'rejected')
            .snapshots();
      default:
        return ref.snapshots();
    }
  }

  // ── Verify payment ────────────────────────────────────────────────────────
  Future<void> _verifyPayment(
      String billingDocId, String shopId, String monthLabel) async {
    await FirebaseFirestore.instance
        .collection('billing')
        .doc(billingDocId)
        .update({
      'payment_status': 'verified',
      'verified_at'   : FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'billing_status'    : 'active',
      'is_visible'        : true,
      'billing_verified_at': FieldValue.serverTimestamp(),
      'notification'      :
          '✅ Your platform fee payment for $monthLabel has been verified. Shop is active!',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment verified. Shopkeeper has been notified.'),
        backgroundColor: accentGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Reject payment ────────────────────────────────────────────────────────
  Future<void> _rejectPayment(String billingDocId, String shopId,
      String reason, String monthLabel) async {
    await FirebaseFirestore.instance
        .collection('billing')
        .doc(billingDocId)
        .update({
      'payment_status'  : 'rejected',
      'rejection_reason': reason,
      'rejected_at'     : FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'billing_status': 'suspended',
      'is_visible'    : false,
      'notification'  :
          '❌ Payment receipt for $monthLabel was rejected: $reason. Please re-upload the correct JazzCash/EasyPaisa receipt.',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Receipt rejected. Shopkeeper has been notified.'),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 6+7+8: Receipt Detail Dialog
  // ══════════════════════════════════════════════════════════════════════════
  void _openReceiptDetail(
      Map<String, dynamic> data, String docId, String shopName) {
    final shopId     = data['shopId'] ?? '';
    final status     = data['payment_status'] ?? 'unpaid';
    final receiptUrl = data['receipt_url'] ?? '';
    final monthLabel = data['month_label'] ?? '';
    final fee        = (data['total_platform_fee'] ?? 0).toDouble();
    final totalOrders   = data['total_orders'] ?? 0;
    final customersPaid = (data['customers_paid'] ?? 0).toDouble();
    final totalReceived = (data['total_received'] ?? 0).toDouble();

    Timestamp? submittedAt = data['submitted_at'];
    String submittedStr = '';
    if (submittedAt != null) {
      final d = submittedAt.toDate();
      submittedStr =
          '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    }

    final TextEditingController noteCtrl = TextEditingController();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReceiptDetailPage(
          shopName       : shopName,
          shopId         : shopId,
          monthLabel     : monthLabel,
          status         : status,
          receiptUrl     : receiptUrl,
          totalOrders    : totalOrders,
          customersPaid  : customersPaid,
          platformFee    : fee,
          totalReceived  : totalReceived,
          submittedStr   : submittedStr,
          noteCtrl       : noteCtrl,
          onVerify       : () async {
            Navigator.pop(context);
            await _verifyPayment(docId, shopId, monthLabel);
          },
          onReject       : (reason) async {
            Navigator.pop(context);
            await _rejectPayment(docId, shopId, reason, monthLabel);
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 5: Receipt list
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildList(String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _billingStream(filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: primaryBlue));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(Icons.receipt_long_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 14),
              Text('No ${filter.toLowerCase()} records',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 15)),
            ]),
          );
        }

        final docs = List.from(snapshot.data!.docs);
        docs.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['submitted_at'] as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['submitted_at'] as Timestamp?;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data  = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status     = data['payment_status'] ?? 'unpaid';
            final shopId     = data['shopId'] ?? '';
            final monthLabel = data['month_label'] ?? '';
            final fee        = (data['total_platform_fee'] ?? 0).toDouble();
            final totalOrders   = data['total_orders'] ?? 0;
            final hasReceipt    = (data['receipt_url'] ?? '').isNotEmpty;
            final receiptUrl    = data['receipt_url'] ?? '';

            Timestamp? ts = data['submitted_at'];
            String dateStr = '';
            if (ts != null) {
              final d = ts.toDate();
              dateStr =
                  '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
            }

            // Fetch shop name
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .get(),
              builder: (context, shopSnap) {
                final shopName = shopSnap.hasData && shopSnap.data!.exists
                    ? (shopSnap.data!.data()
                            as Map<String, dynamic>)['shop_name'] ??
                        'Shop'
                    : 'Shop';

                return GestureDetector(
                  onTap: () => _openReceiptDetail(data, docId, shopName),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // ── Header row ──
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.store_outlined,
                                color: primaryBlue, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shopName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _statusBadge(status),
                        ]),
                        const SizedBox(height: 10),

                        // ── Amount row ──
                        Row(children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text('Amount Sent: ',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12)),
                          Text('Rs. ${fee.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange)),
                        ]),
                        const SizedBox(height: 4),

                        // ── Submission date ──
                        if (dateStr.isNotEmpty)
                          Text(
                            'Submitted: $dateStr',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        const SizedBox(height: 10),

                        // ── Receipt thumbnail + tap to review ──
                        Row(children: [
                          if (hasReceipt) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                receiptUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.receipt,
                                        size: 20, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.image_outlined,
                                size: 14, color: accentGreen),
                            const SizedBox(width: 4),
                            Text('Receipt uploaded',
                                style: TextStyle(
                                    fontSize: 12, color: accentGreen)),
                          ] else ...[
                            Icon(Icons.image_not_supported_outlined,
                                size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('No receipt',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400)),
                          ],
                          const Spacer(),
                          Text('Tap to review',
                              style: TextStyle(
                                  color: primaryBlue.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right,
                              color: primaryBlue.withOpacity(0.7),
                              size: 16),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Status badge ──────────────────────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending_verification':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'verified':
        color = accentGreen;
        label = 'Verified';
        break;
      case 'rejected':
        color = accentRed;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unpaid';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Receipt Verifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // Live pending count badge
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('billing')
                .where('payment_status', isEqualTo: 'pending_verification')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Stack(alignment: Alignment.topRight, children: [
                  const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 26),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: accentRed, shape: BoxShape.circle),
                      child: Text('$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          tabs: _tabs
              .map((t) => Tab(
                    child: t == 'Pending'
                        ? StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('billing')
                                .where('payment_status',
                                    isEqualTo: 'pending_verification')
                                .snapshots(),
                            builder: (context, snap) {
                              final count = snap.data?.docs.length ?? 0;
                              return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(t),
                                    if (count > 0) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Text('$count',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.bold)),
                                      )
                                    ]
                                  ]);
                            },
                          )
                        : Text(t),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _buildList(t)).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RECEIPT DETAIL PAGE (Step 6 + 7 + 8)
// ══════════════════════════════════════════════════════════════════════════════
class _ReceiptDetailPage extends StatefulWidget {
  final String shopName;
  final String shopId;
  final String monthLabel;
  final String status;
  final String receiptUrl;
  final int    totalOrders;
  final double customersPaid;
  final double platformFee;
  final double totalReceived;
  final String submittedStr;
  final TextEditingController noteCtrl;
  final VoidCallback onVerify;
  final void Function(String reason) onReject;

  const _ReceiptDetailPage({
    required this.shopName,
    required this.shopId,
    required this.monthLabel,
    required this.status,
    required this.receiptUrl,
    required this.totalOrders,
    required this.customersPaid,
    required this.platformFee,
    required this.totalReceived,
    required this.submittedStr,
    required this.noteCtrl,
    required this.onVerify,
    required this.onReject,
  });

  @override
  State<_ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<_ReceiptDetailPage> {
  static const Color primaryBlue  = Color(0xFF1565C0);
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentGreen  = Color(0xFF2E9E6B);
  static const Color accentRed    = Color(0xFFE53935);
  static const Color bgColor      = Color(0xFFF0F3F8);
  static const Color cardWhite    = Color(0xFFFFFFFF);
  static const Color greenLight   = Color(0xFFE8F5EE);
  static const Color redLight     = Color(0xFFFFECEC);
  static const Color orangeLight  = Color(0xFFFFF0E8);

  // Step 8: after action
  bool _actionDone = false;
  String _actionResult = '';  // 'verified' or 'rejected'

  Future<void> _handleVerify() async {
    widget.onVerify();
    setState(() {
      _actionDone   = true;
      _actionResult = 'verified';
    });
  }

  Future<void> _handleReject() async {
    final reason = widget.noteCtrl.text.trim().isNotEmpty
        ? widget.noteCtrl.text.trim()
        : 'Invalid receipt';
    widget.onReject(reason);
    setState(() {
      _actionDone   = true;
      _actionResult = 'rejected';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Step 8 — Status updated screen
    if (_actionDone) {
      return _buildStatusUpdatedScreen();
    }

    // Step 6 + 7 — Review & action
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Receipt Details',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // ── Shop & amount header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: primaryNavy.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Shop name row
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.store_outlined,
                      color: primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Shopkeeper',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
                    Text(widget.shopName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryNavy)),
                  ]),
                ),
                _statusBadge(widget.status),
              ]),
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 10),

              // Amount sent
              _detailRow('Amount Sent',
                  'Rs. ${widget.platformFee.toStringAsFixed(2)}',
                  bold: true, valueColor: Colors.orange),
              const SizedBox(height: 8),

              // Submitted time
              _detailRow('Submitted to', widget.submittedStr),
              const SizedBox(height: 8),

              // Note
              _detailRow('Note', 'None'),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Receipt Image ────────────────────────────────────────────
          const Text('Receipt Image',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: primaryNavy)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: primaryNavy.withOpacity(0.05),
                      blurRadius: 10)
                ]),
            padding: const EdgeInsets.all(12),
            child: widget.receiptUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.receiptUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade100,
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey, size: 36))),
                    ),
                  )
                : Container(
                    height: 120,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                        child: Text('No receipt uploaded',
                            style: TextStyle(color: Colors.grey)))),
          ),
          const SizedBox(height: 16),

          // ── Check & Verify checklist ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: primaryNavy.withOpacity(0.04), blurRadius: 8)
                ]),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Check & Verify',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primaryNavy)),
              const SizedBox(height: 12),
              _checkItem('Amount matches'),
              _checkItem('Receipt is valid'),
              _checkItem('From correct account'),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Verify / Reject Section ───────────────────────────────────
          if (widget.status == 'pending_verification') ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: primaryNavy.withOpacity(0.05),
                        blurRadius: 10)
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Shop details
                Row(children: [
                  const Icon(Icons.store_outlined,
                      color: primaryNavy, size: 16),
                  const SizedBox(width: 6),
                  Text(widget.shopName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: primaryNavy)),
                ]),
                const SizedBox(height: 6),
                _infoRow('Amount',
                    'Rs. ${widget.platformFee.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                _infoRow('Submitted at', widget.submittedStr),
                const SizedBox(height: 4),
                _infoRow('Receipt',
                    widget.receiptUrl.isNotEmpty
                        ? '📄 receipt_image.jpg'
                        : 'No receipt'),
                const SizedBox(height: 14),

                const Text('Action',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryNavy)),
                const SizedBox(height: 10),

                // Add Meta / Note field
                const Text('Add Note (Optional)',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.noteCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Write note here...',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF0F3F8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Verify / Reject buttons
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: accentGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: widget.receiptUrl.isNotEmpty
                          ? _handleVerify
                          : null,
                      child: const Text('Verify',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: accentRed),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: _handleReject,
                      child: const Text('Reject',
                          style: TextStyle(
                              color: accentRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                ]),
              ]),
            ),
          ] else ...[
            // Already verified or rejected — show status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.status == 'verified' ? greenLight : redLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: widget.status == 'verified'
                        ? accentGreen.withOpacity(0.3)
                        : accentRed.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(
                  widget.status == 'verified'
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: widget.status == 'verified'
                      ? accentGreen
                      : accentRed,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.status == 'verified'
                      ? 'Payment verified successfully'
                      : 'Payment was rejected',
                  style: TextStyle(
                      color: widget.status == 'verified'
                          ? accentGreen
                          : accentRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text('Back to List',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STEP 8: Status Updated Screen
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatusUpdatedScreen() {
    final isVerified = _actionResult == 'verified';
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: isVerified ? accentGreen : accentRed,
                  shape: BoxShape.circle),
              child: Icon(
                isVerified
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isVerified
                  ? 'Receipt Verified\nSuccessfully!'
                  : 'Receipt Rejected',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isVerified ? accentGreen : accentRed,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
            const SizedBox(height: 12),
            Text(
              isVerified
                  ? 'Shopkeeper has been notified.'
                  : 'Shopkeeper has been asked to re-upload.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isVerified ? accentGreen : primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  Navigator.pop(context); // back to list
                },
                child: const Text('Back to List',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _checkItem(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
            color: accentGreen, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 12),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(fontSize: 13, color: primaryNavy)),
    ]),
  );

  Widget _detailRow(String label, String value,
      {bool bold = false, Color? valueColor}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: valueColor ?? primaryNavy)),
        ],
      );

  Widget _infoRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style:
              TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      Flexible(
        child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: primaryNavy)),
      ),
    ],
  );

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending_verification':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'verified':
        color = accentGreen;
        label = 'Verified';
        break;
      case 'rejected':
        color = accentRed;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unpaid';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11)),
    );
  }
}