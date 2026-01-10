import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopProductsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const ShopProductsScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shopName),
        backgroundColor: const Color.fromARGB(255, 21, 101, 192),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Products...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
            ),
          ),
          // Products list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final productName = data['name']?.toString().toLowerCase() ?? "";
                  return productName.contains(_searchText);
                }).toList();

                if (products.isEmpty) {
                  return const Center(child: Text("No products found."));
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data = products[index].data() as Map<String, dynamic>;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        leading: data['image_url'] != null
                            ? Image.network(data['image_url'], width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 50),
                        title: Text(data['name'] ?? "Unnamed Product"),
                        subtitle: Text("Price: \$${data['price'] ?? "0"}"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}