import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductPage extends StatefulWidget {
  final String shopId;
  final String? editProductId;
  final Map<String, dynamic>? editData;

  const AddProductPage({super.key, required this.shopId, this.editProductId, this.editData});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _loading = false;

  // Colors matching your logo
  final Color primaryColor = const Color(0xFF1565C0); // logo color
  final Color accentColor = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _nameController.text = widget.editData!['name'] ?? "";
      _descController.text = widget.editData!['description'] ?? "";
      _priceController.text = (widget.editData!['price'] ?? "").toString();
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'created_at': Timestamp.now(),
      };

      final collection = FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products');

      if (widget.editProductId != null) {
        await collection.doc(widget.editProductId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product updated successfully")),
        );
      } else {
        await collection.add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product added successfully")),
        );
      }

      setState(() => _loading = false);
      _nameController.clear();
      _descController.clear();
      _priceController.clear();
      if (widget.editProductId != null) Navigator.pop(context);
    }
  }

  void _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products')
          .doc(productId)
          .delete();
    }
  }

  Widget _productList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs;
        if (products.isEmpty) return const Center(child: Text("No products added yet.", style: TextStyle(fontSize: 16)));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final productId = products[index].id;

            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  data['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text("Price: \$${data['price']}\n${data['description'] ?? ""}"),
                isThreeLine: data['description'] != null && data['description'].isNotEmpty,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: accentColor),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductPage(
                              shopId: widget.shopId,
                              editProductId: productId,
                              editData: data,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteProduct(productId),
                    ),
                  ],
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
        title: Text(widget.editProductId != null ? "Edit Product" : "Add Product"),
        backgroundColor: primaryColor,
        elevation: 4,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Product Name*",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.shopping_bag),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) => value == null || value.isEmpty ? "Enter name" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.description),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: "Price*",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.attach_money),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) => value == null || value.isEmpty ? "Enter price" : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _saveProduct,
                          child: Text(widget.editProductId != null ? "Update Product" : "Add Product"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _productList(),
            ],
          ),
        ),
      ),
    );
  }
}