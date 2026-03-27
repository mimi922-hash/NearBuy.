import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddProductPage extends StatefulWidget {
  final String shopId;
  final String? editProductId;
  final Map<String, dynamic>? editData;

  const AddProductPage({
    super.key,
    required this.shopId,
    this.editProductId,
    this.editData,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  bool _loading = false;

  File? _productImage;
  String? _imageUrl;

  final picker = ImagePicker();

  // Colors matching your logo
  final Color primaryColor = const Color(0xFF1565C0);
  final Color accentColor = Colors.blueAccent;

  // Cloudinary credentials
  final String cloudName = "dxzaqavfj";
  final String uploadPreset = "nearbuy_preset";

  @override
  void initState() {
    super.initState();

    if (widget.editData != null) {
      _nameController.text = widget.editData!['name'] ?? "";
      _descController.text = widget.editData!['description'] ?? "";
      _priceController.text = (widget.editData!['price'] ?? "").toString();
      _imageUrl = widget.editData!['image_url'];
    }
  }

  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _productImage = File(picked.path);
      });
    }
  }

  Future<String?> uploadToCloudinary(File image) async {
    final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    var request = http.MultipartRequest("POST", url);

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath('file', image.path),
    );

    var response = await request.send();
    var res = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    } else {
      return null;
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      if (_productImage != null) {
        final uploadedUrl = await uploadToCloudinary(_productImage!);
        if (uploadedUrl != null) {
          _imageUrl = uploadedUrl;
        }
      }

      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'image_url': _imageUrl,
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
      _productImage = null;

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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs;

        if (products.isEmpty) {
          return const Center(
              child: Text("No products added yet.",
                  style: TextStyle(fontSize: 16)));
        }

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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: data['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['image_url'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image, size: 40),
                title: Text(
                  data['name'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle:
                    Text("Price: \$${data['price']}\n${data['description'] ?? ""}"),
                isThreeLine:
                    data['description'] != null && data['description'] != "",
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
                      icon: const Icon(Icons.delete,
                          color: Colors.redAccent),
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

  Widget _imagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _productImage != null
                ? Image.file(_productImage!, fit: BoxFit.cover)
                : _imageUrl != null
                    ? Image.network(_imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Text("Tap to select product image")),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
            widget.editProductId != null ? "Edit Product" : "Add Product"),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _imagePicker(),

                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Product Name*",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty
                                  ? "Enter name"
                                  : null,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: "Price*",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          validator: (value) =>
                              value == null || value.isEmpty
                                  ? "Enter price"
                                  : null,
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _loading ? null : _saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize:
                                const Size(double.infinity, 50),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(widget.editProductId != null
                                  ? "Update Product"
                                  : "Add Product"),
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