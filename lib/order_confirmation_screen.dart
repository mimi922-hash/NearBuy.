import 'package:flutter/material.dart';
import 'customer_dashboard.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  final String shopName;
  final double totalAmount;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.shopName,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 60),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Your order has been placed successfully at $shopName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),

                // Order details card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _detailRow(Icons.receipt_long, 'Order ID', orderId.substring(0, 10) + '...'),
                        const Divider(height: 20),
                        _detailRow(Icons.store, 'Shop', shopName),
                        const Divider(height: 20),
                        _detailRow(
                          Icons.currency_rupee,
                          'Total Paid',
                          'Rs. ${totalAmount.toStringAsFixed(2)}',
                          valueColor: const Color(0xFF1565C0),
                        ),
                        const Divider(height: 20),
                        _detailRow(Icons.money, 'Payment', 'Cash on Delivery'),
                        const Divider(height: 20),
                        _detailRow(Icons.pending_actions, 'Status', 'Pending Confirmation',
                            valueColor: Colors.orange),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The shopkeeper will confirm your order shortly. Please keep cash ready for delivery.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerDashboard()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}