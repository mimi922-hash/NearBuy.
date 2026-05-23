import 'package:flutter/material.dart';
 
class BillingWorkflowScreen extends StatelessWidget {
  const BillingWorkflowScreen({super.key});
 
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kNavy = Color(0xFF0D1B3E);
 
  @override
  Widget build(BuildContext context) {
    final steps = [
      {
        'step': '1',
        'title': 'Platform Fee Generated',
        'desc': 'System automatically generates platform fee for the shopkeeper each billing month.',
        'icon': Icons.auto_mode,
        'color': kNavy,
        'status': 'auto',
      },
      {
        'step': '2',
        'title': 'Shopkeeper Uploads Receipt',
        'desc': 'Shopkeeper must upload payment receipt within 20 minutes via JazzCash, Easypaisa, or Bank Transfer.',
        'icon': Icons.upload_file,
        'color': kOrange,
        'status': 'action',
      },
      {
        'step': '3',
        'title': 'Admin Reviews Payment',
        'desc': 'Admin manually reviews the uploaded receipt, verifies transaction ID and amount.',
        'icon': Icons.admin_panel_settings,
        'color': Colors.blue,
        'status': 'review',
      },
      {
        'step': '4',
        'title': 'Valid Receipt → Approved',
        'desc': 'If receipt is genuine and amount matches, admin approves payment and shop remains active.',
        'icon': Icons.check_circle,
        'color': Colors.green,
        'status': 'success',
      },
      {
        'step': '5',
        'title': 'Fake/Blurry → Rejected',
        'desc': 'If receipt is fake, blurry, or amount is incorrect, payment is rejected with reason.',
        'icon': Icons.cancel,
        'color': Colors.red,
        'status': 'rejected',
      },
      {
        'step': '6',
        'title': 'No Receipt → Suspended',
        'desc': 'If no receipt is uploaded within 20 minutes, shop is automatically suspended and hidden from customers.',
        'icon': Icons.block,
        'color': Colors.red.shade900,
        'status': 'suspended',
      },
      {
        'step': '7',
        'title': 'After Approval → Reactivated',
        'desc': 'Once admin approves a valid payment, the shop is automatically reactivated for customers.',
        'icon': Icons.store,
        'color': Colors.green,
        'status': 'reactivated',
      },
    ];
 
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Billing Workflow',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B3E), Color(0xFF1A3A6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('NearBuy Billing Process',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Complete workflow from fee generation to shop reactivation',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
 
            // Status Legend
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _legendChip('Active', Colors.green),
                _legendChip('Pending', kOrange),
                _legendChip('Rejected', Colors.red),
                _legendChip('Suspended', Colors.red.shade900),
                _legendChip('Approved', Colors.green),
              ],
            ),
            const SizedBox(height: 24),
 
            // Timeline Steps
            ...List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: step['color'] as Color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: (step['color'] as Color)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Icon(step['icon'] as IconData,
                            color: Colors.white, size: 20),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 60,
                          color: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (step['color'] as Color)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Step ${step['step']}',
                                    style: TextStyle(
                                        color: step['color'] as Color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(step['title'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF0D1B3E))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(step['desc'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
 
  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
 