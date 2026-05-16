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
  const AddProductPage({super.key, required this.shopId, this.editProductId, this.editData});
  @override
  State<AddProductPage> createState() => _AddProductPageState();
}
 
class _AddProductPageState extends State<AddProductPage> {
  // ── Brand Colors ──
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  final _formKey   = GlobalKey<FormState>();
  final _name      = TextEditingController();
  final _desc      = TextEditingController();
  final _price     = TextEditingController();
  bool _loading    = false;
  File? _productImage;
  String? _imageUrl;
  final picker     = ImagePicker();
  final cloudName  = 'dxzaqavfj';
  final uploadPreset = 'nearbuy_preset';
 
  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _name.text  = widget.editData!['name'] ?? '';
      _desc.text  = widget.editData!['description'] ?? '';
      _price.text = (widget.editData!['price'] ?? '').toString();
      _imageUrl   = widget.editData!['image_url'];
    }
  }
 
  // All logic unchanged ─────────────────────────────────
  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _productImage = File(picked.path));
  }
 
  Future<String?> uploadToCloudinary(File image) async {
    var request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'));
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', image.path));
    var response = await request.send();
    var res = await http.Response.fromStream(response);
    if (response.statusCode == 200) return json.decode(res.body)['secure_url'];
    return null;
  }
 
  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      if (_productImage != null) {
        final url = await uploadToCloudinary(_productImage!);
        if (url != null) _imageUrl = url;
      }
      final data = {
        'name': _name.text.trim(), 'description': _desc.text.trim(),
        'price': double.tryParse(_price.text.trim()) ?? 0.0,
        'image_url': _imageUrl, 'created_at': Timestamp.now(),
      };
      final coll = FirebaseFirestore.instance.collection('shops').doc(widget.shopId).collection('products');
      if (widget.editProductId != null) {
        await coll.doc(widget.editProductId).update(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Product updated!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      } else {
        await coll.add(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Product added!'), backgroundColor: accentOrange, behavior: SnackBarBehavior.floating));
      }
      setState(() => _loading = false);
      _name.clear(); _desc.clear(); _price.clear(); _productImage = null;
      if (widget.editProductId != null) Navigator.pop(context);
    }
  }
 
  void _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Confirm Delete', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
      content: const Text('Are you sure you want to delete this product?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm == true) await FirebaseFirestore.instance.collection('shops').doc(widget.shopId).collection('products').doc(productId).delete();
  }
 
  Widget _productList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(widget.shopId)
          .collection('products').orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: accentOrange));
        final products = snapshot.data!.docs;
        if (products.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Text('No products added yet.', style: TextStyle(color: Colors.grey.shade500))));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data      = products[index].data() as Map<String, dynamic>;
            final productId = products[index].id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: data['image_url'] != null
                          ? Image.network(data['image_url'], width: 60, height: 60, fit: BoxFit.cover)
                          : Container(width: 60, height: 60, color: const Color(0xFFF0F4FF),
                              child: const Icon(Icons.image_outlined, color: primaryNavy))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryNavy)),
                    const SizedBox(height: 3),
                    Text('Rs. ${data['price']}', style: const TextStyle(color: accentOrange, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (data['description'] != null && data['description'] != '')
                      Text(data['description'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductPage(shopId: widget.shopId, editProductId: productId, editData: data))),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(padding: const EdgeInsets.all(6), child: const Icon(Icons.edit_outlined, color: primaryNavy, size: 20))),
                    InkWell(onTap: () => _deleteProduct(productId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20))),
                  ]),
                ]),
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(widget.editProductId != null ? 'Edit Product' : 'Add Product',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Form card
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(children: [
                // Image picker
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    height: 160, width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _productImage != null ? accentOrange : Colors.grey.shade200, width: _productImage != null ? 2 : 1),
                    ),
                    child: _productImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_productImage!, fit: BoxFit.cover))
                        : _imageUrl != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(_imageUrl!, fit: BoxFit.cover))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.add_photo_alternate_outlined, color: primaryNavy, size: 36),
                                const SizedBox(height: 8),
                                Text('Tap to add product image', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              ]),
                  ),
                ),
                const SizedBox(height: 16),
                // Name field
                TextFormField(
                  controller: _name,
                  decoration: _inputDec('Product Name *', Icons.label_outline),
                  validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 14),
                // Description field
                TextFormField(
                  controller: _desc, maxLines: 3,
                  decoration: _inputDec('Description (optional)', Icons.description_outlined),
                ),
                const SizedBox(height: 14),
                // Price field
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDec('Price (Rs.) *', Icons.currency_rupee),
                  validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
                ),
                const SizedBox(height: 20),
                // Save button
                SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accentOrange, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _loading ? null : _saveProduct,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(widget.editProductId != null ? 'Update Product' : 'Add Product',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          // Products list
          Row(children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: accentOrange, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('My Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryNavy)),
          ]),
          const SizedBox(height: 10),
          _productList(),
        ]),
      ),
    );
  }
 
  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: accentOrange),
    floatingLabelStyle: const TextStyle(color: primaryNavy),
    filled: true, fillColor: bgColor,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6A1A), width: 1.5)),
  );
}
