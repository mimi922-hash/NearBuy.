import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_confirmation_screen.dart';

class CartScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const CartScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Color primaryColor = const Color(0xFF1565C0);
  static const double platformFeePercent = 0.05; // 5% platform fee

  Stream<QuerySnapshot> _cartStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .where('shopId', isEqualTo: widget.shopId)
        .snapshots();
  }

  double _calculateSubtotal(List<QueryDocumentSnapshot> items) {
    double total = 0;
    for (var item in items) {
      final data = item.data() as Map<String, dynamic>;
      total += (data['price'] ?? 0) * (data['quantity'] ?? 1);
    }
    return total;
  }

  Future<void> _updateQuantity(String docId, int newQty) async {
    if (newQty <= 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(docId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(docId)
          .update({'quantity': newQty});
    }
  }

  Future<void> _removeItem(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .doc(docId)
        .delete();
  }

  Future<void> _placeOrder(List<QueryDocumentSnapshot> cartItems, double subtotal) async {
    final platformFee = subtotal * platformFeePercent;
    final totalAmount = subtotal + platformFee;

    final List<Map<String, dynamic>> orderItems = cartItems.map((item) {
      final data = item.data() as Map<String, dynamic>;
      return {
        'productId': data['productId'],
        'name': data['name'],
        'price': data['price'],
        'quantity': data['quantity'],
        'image_url': data['image_url'] ?? '',
      };
    }).toList();

    // Firestore mein order save karo
    final orderRef = await FirebaseFirestore.instance.collection('orders').add({
      'customerId': user!.uid,
      'customerEmail': user!.email,
      'shopId': widget.shopId,
      'shopName': widget.shopName,
      'items': orderItems,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'totalAmount': totalAmount,
      'paymentMethod': 'Cash on Delivery',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cart clear karo is shop ke liye
    final cartDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .where('shopId', isEqualTo: widget.shopId)
        .get();

    for (var doc in cartDocs.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderRef.id,
            shopName: widget.shopName,
            totalAmount: totalAmount,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cartStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data!.docs;

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final subtotal = _calculateSubtotal(cartItems);
          final platformFee = subtotal * platformFeePercent;
          final totalAmount = subtotal + platformFee;

          return Column(
            children: [
              // Shop name header
              Container(
                width: double.infinity,
                color: primaryColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    Text(
                      widget.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final data = cartItems[index].data() as Map<String, dynamic>;
                    final docId = cartItems[index].id;
                    final qty = data['quantity'] ?? 1;
                    final price = (data['price'] ?? 0).toDouble();
                    final itemTotal = price * qty;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: data['image_url'] != null && data['image_url'] != ''
                                  ? Image.network(
                                      data['image_url'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            // Product details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${price.toStringAsFixed(0)} each',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  // Quantity controls
                                  Row(
                                    children: [
                                      _qtyButton(
                                        icon: Icons.remove,
                                        onTap: () => _updateQuantity(docId, qty - 1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _qtyButton(
                                        icon: Icons.add,
                                        onTap: () => _updateQuantity(docId, qty + 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Item total + delete
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs. ${itemTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => _removeItem(docId),
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Order Summary + Checkout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _summaryRow('Subtotal', 'Rs. ${subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    _summaryRow('Platform Fee (5%)', 'Rs. ${platformFee.toStringAsFixed(2)}',
                        color: Colors.orange.shade700),
                    const Divider(height: 20),
                    _summaryRow(
                      'Total',
                      'Rs. ${totalAmount.toStringAsFixed(2)}',
                      bold: true,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 6),
                    // Payment method badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.money, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text('Cash on Delivery', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirm Order'),
                              content: Text(
                                'Place order of Rs. ${totalAmount.toStringAsFixed(2)} from ${widget.shopName}?\n\nPayment: Cash on Delivery',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _placeOrder(cartItems, subtotal);
                          }
                        },
                        child: const Text(
                          'Place Order',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey.shade700,
          ),
        ),
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

