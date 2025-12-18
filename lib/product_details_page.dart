import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProductDetailsPage extends StatefulWidget {
  final String shopId;
  const ProductDetailsPage({super.key, required this.shopId});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final picker = ImagePicker();

  // For Add/Edit Product
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  File? _image;
  String? editingProductId; // If editing, store product docId

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _clearForm() {
    _nameController.clear();
    _descController.clear();
    _priceController.clear();
    _image = null;
    editingProductId = null;
  }

  Future<void> _submitProduct() async {
    if (_formKey.currentState!.validate() && (_image != null || editingProductId != null)) {
      String? imageUrl;

      // Upload image if new
      if (_image != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref("products/$fileName.jpg");
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      if (editingProductId != null) {
        // UPDATE existing product
        Map<String, dynamic> updateData = {
          "name": _nameController.text.trim(),
          "description": _descController.text.trim(),
          "price": double.parse(_priceController.text.trim()),
        };
        if (imageUrl != null) updateData["imageUrl"] = imageUrl;

        await FirebaseFirestore.instance
            .collection("products")
            .doc(editingProductId)
            .update(updateData);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product updated successfully!")));
      } else {
        // ADD new product
        await FirebaseFirestore.instance.collection("products").add({
          "shopId": widget.shopId,
          "name": _nameController.text.trim(),
          "description": _descController.text.trim(),
          "price": double.parse(_priceController.text.trim()),
          "imageUrl": imageUrl,
          "createdAt": FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product added successfully!")));
      }

      _clearForm();
      Navigator.pop(context); // Close modal
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Complete all fields & select image")));
    }
  }

  void _showProductForm({DocumentSnapshot? doc}) {
    if (doc != null) {
      // Editing existing product
      _nameController.text = doc["name"];
      _descController.text = doc["description"];
      _priceController.text = doc["price"].toString();
      editingProductId = doc.id;
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, top: 16, left: 16, right: 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _image == null && doc != null
                    ? Image.network(doc["imageUrl"], height: 150)
                    : _image == null
                        ? GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(Icons.add_a_photo, size: 50),
                            ),
                          )
                        : Image.file(_image!, height: 150),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Product Name"),
                  validator: (val) => val == null || val.isEmpty ? "Enter name" : null,
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: "Description"),
                  validator: (val) => val == null || val.isEmpty ? "Enter description" : null,
                ),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? "Enter price" : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitProduct,
                  child: Text(editingProductId != null ? "Update Product" : "Add Product"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String docId) async {
    await FirebaseFirestore.instance.collection("products").doc(docId).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Product deleted successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProductForm(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("products")
            .where("shopId", isEqualTo: widget.shopId)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No products added yet"));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Image.network(data["imageUrl"], width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(data["name"]),
                  subtitle: Text("${data["description"]}\nPrice: \$${data["price"]}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showProductForm(doc: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteProduct(data.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}