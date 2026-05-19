import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────
// BRAND CONSTANTS
// ─────────────────────────────────────────────────────────────────────────
class _NB {
  static const Color navy      = Color(0xFF0E2A47);
  static const Color navyLight = Color(0xFF1A3A5C);
  static const Color orange    = Color(0xFFFF6A1A);
  static const Color bg        = Color(0xFFF0F3F8);
  static const Color surface   = Colors.white;
  static const Color border    = Color(0xFFE2E8F0);
  static const Color textGrey  = Color(0xFF94A3B8);
  static const Color green     = Color(0xFF2E9E6B);
  static const Color greenBg   = Color(0xFFE8F5EE);
  static const Color red       = Color(0xFFE53935);
  static const Color redBg     = Color(0xFFFFECEC);
  static const Color orangeBg  = Color(0xFFFFF0E8);
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────
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

class _AddProductPageState extends State<AddProductPage>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────
  final _formKey         = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _descController  = TextEditingController();
  final _priceController = TextEditingController();
  bool    _loading       = false;
  File?   _productImage;
  String? _imageUrl;
  bool    _outOfStock    = false;

  // FIX: Track whether save was attempted (to show image error border)
  bool    _imageMissing  = false;

  final   picker         = ImagePicker();

  // ── Cloudinary credentials ────────────────────────
  static const String _cloudName    = 'dxzaqavfj';
  static const String _uploadPreset = 'nearbuy_preset';

  // ── Animation ────────────────────────────────────
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Lifecycle ────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _nameController.text  = widget.editData!['name']        ?? '';
      _descController.text  = widget.editData!['description'] ?? '';
      _priceController.text = (widget.editData!['price'] ?? '').toString();
      _imageUrl             = widget.editData!['image_url'];
      _outOfStock           = widget.editData!['out_of_stock'] == true;
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════
  // LOGIC
  // ══════════════════════════════════════════════════

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _productImage = File(picked.path);
        _imageMissing = false; // clear error once image is picked
      });
    }
  }

  Future<String?> uploadToCloudinary(File image) async {
    final url     = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(
      await http.MultipartFile.fromPath('file', image.path),
    );
    final response = await request.send();
    final res      = await http.Response.fromStream(response);
    if (response.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    }
    return null;
  }

  // FIX: Image is now mandatory in BOTH add and edit mode
  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Product name is required', _NB.red);
      return false;
    }
    if (_priceController.text.trim().isEmpty) {
      _showSnack('Price is required', _NB.red);
      return false;
    }
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showSnack('Enter a valid price greater than 0', _NB.red);
      return false;
    }

    // FIX: Image required for BOTH new product and edit mode
    final bool hasImage = _productImage != null ||
        (_imageUrl != null && _imageUrl!.isNotEmpty);
    if (!hasImage) {
      setState(() => _imageMissing = true); // show red border on picker
      _showSnack('Product image is required', _NB.red);
      return false;
    }

    return true;
  }

  void _saveProduct() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    if (_productImage != null) {
      final uploadedUrl = await uploadToCloudinary(_productImage!);
      if (uploadedUrl != null) _imageUrl = uploadedUrl;
    }

    final data = {
      'name':        _nameController.text.trim(),
      'description': _descController.text.trim(),
      'price':       double.tryParse(_priceController.text.trim()) ?? 0.0,
      'image_url':   _imageUrl,
      'out_of_stock': _outOfStock,
      'created_at':  Timestamp.now(),
    };

    final collection = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('products');

    if (widget.editProductId != null) {
      await collection.doc(widget.editProductId).update(data);
      if (mounted) _showSnack('Product updated successfully!', _NB.green);
    } else {
      await collection.add(data);
      if (mounted) _showSnack('Product added successfully!', _NB.orange);
    }

    setState(() {
      _loading      = false;
      _productImage = null;
      _outOfStock   = false;
      _imageMissing = false;
    });

    if (widget.editProductId == null) {
      _nameController.clear();
      _descController.clear();
      _priceController.clear();
      setState(() => _imageUrl = null);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: _NB.navy,
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Product',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )),
          ]),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Are you sure you want to delete this product?\nThis action cannot be undone.',
            style: TextStyle(color: Color(0xFF475569), height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ══════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _inputDec({
    required String   label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText:          label,
      hintText:           hint,
      prefixIcon:         Icon(icon, color: _NB.orange, size: 20),
      floatingLabelStyle: const TextStyle(
          color: _NB.navy, fontWeight: FontWeight.w600),
      filled:             true,
      fillColor:          _NB.bg,
      contentPadding:     const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _NB.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _NB.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _NB.orange, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  Widget _sectionHeader(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            color: _NB.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: _NB.navy, size: 18),
        const SizedBox(width: 6),
        Text(text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _NB.navy,
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  // IMAGE PICKER WIDGET
  // FIX: Red border + error text shown when _imageMissing is true
  // FIX: Hint text updated — image required in both add and edit mode
  // ══════════════════════════════════════════════════

  Widget _imagePicker() {
    final hasImage = _productImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

    // Border color: red if missing after save attempt, orange if has image, grey otherwise
    final Color borderColor = _imageMissing
        ? _NB.red
        : hasImage
            ? _NB.orange
            : _NB.border;
    final double borderWidth = (_imageMissing || hasImage) ? 2.0 : 1.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: pickImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasImage ? Colors.transparent : _NB.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _productImage != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.file(_productImage!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.black.withOpacity(0.45),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Tap to change image',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ])
                : _imageUrl != null && _imageUrl!.isNotEmpty
                    ? Stack(fit: StackFit.expand, children: [
                        Image.network(
                          _imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          color: _NB.orange)),
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.black.withOpacity(0.45),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('Tap to change image',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ])
                    : _imagePlaceholder(showError: _imageMissing),
          ),
        ),
      ),

      // FIX: Error message shown in red when image is missing after save attempt
      if (_imageMissing)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 13, color: _NB.red),
            const SizedBox(width: 4),
            const Text('Product image is required',
                style: TextStyle(
                    fontSize: 11,
                    color: _NB.red,
                    fontWeight: FontWeight.w500)),
          ]),
        )
      else
        // Normal hint — image required in both modes
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(children: [
            Icon(Icons.info_outline,
                size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('Image is required to save the product',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
    ]);
  }

  Widget _imagePlaceholder({bool showError = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: showError
                ? _NB.red.withOpacity(0.08)
                : _NB.orange.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            showError
                ? Icons.add_photo_alternate_outlined
                : Icons.add_photo_alternate_outlined,
            color: showError ? _NB.red : _NB.orange,
            size: 34,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          showError ? 'Image is required — Tap to add' : 'Tap to add product image',
          style: TextStyle(
              color: showError ? _NB.red : _NB.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text('JPG, PNG supported',
            style: TextStyle(color: _NB.textGrey, fontSize: 11)),
      ],
    );
  }

  // ══════════════════════════════════════════════════
  // OUT OF STOCK TOGGLE (edit mode)
  // ══════════════════════════════════════════════════

  Widget _outOfStockToggle() {
    return GestureDetector(
      onTap: () => setState(() => _outOfStock = !_outOfStock),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _outOfStock ? _NB.redBg : _NB.greenBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _outOfStock
                  ? _NB.red.withOpacity(0.3)
                  : _NB.green.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _outOfStock
                    ? _NB.red.withOpacity(0.12)
                    : _NB.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
              _outOfStock
                  ? Icons.inventory_2_outlined
                  : Icons.check_circle_outline,
              color: _outOfStock ? _NB.red : _NB.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                _outOfStock ? 'Out of Stock' : 'In Stock',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _outOfStock ? _NB.red : _NB.green),
              ),
              const SizedBox(height: 2),
              Text(
                _outOfStock
                    ? 'Tap to mark as In Stock'
                    : 'Tap to mark as Out of Stock',
                style: TextStyle(
                    fontSize: 11,
                    color: _outOfStock
                        ? _NB.red.withOpacity(0.7)
                        : _NB.green.withOpacity(0.7)),
              ),
            ]),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: _outOfStock ? _NB.red : _NB.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _outOfStock ? 22 : 2,
                top: 2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // PRODUCT LIST (with out-of-stock badge + edit/delete)
  // ══════════════════════════════════════════════════

  Widget _productList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _NB.orange),
            ),
          );
        }
        final products = snapshot.data!.docs;
        if (products.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.inventory_2_outlined,
                  size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No products added yet.',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14)),
            ]),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data      = products[index].data() as Map<String, dynamic>;
            final productId = products[index].id;
            final bool isOutOfStock = data['out_of_stock'] == true;

            return Opacity(
              opacity: isOutOfStock ? 0.7 : 1.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _NB.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOutOfStock
                        ? _NB.red.withOpacity(0.25)
                        : _NB.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: data['image_url'] != null &&
                                data['image_url'].toString().isNotEmpty
                            ? Image.network(
                                data['image_url'],
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _listImgPlaceholder(),
                              )
                            : _listImgPlaceholder(),
                      ),
                      if (isOutOfStock)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.black.withOpacity(0.4),
                              alignment: Alignment.center,
                              child: const Text('OUT\nOF\nSTOCK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3)),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          data['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOutOfStock
                                ? Colors.grey.shade500
                                : _NB.navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? Colors.grey.shade100
                                : _NB.orangeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Rs. ${data['price']}',
                            style: TextStyle(
                              color: isOutOfStock
                                  ? Colors.grey.shade400
                                  : _NB.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (data['description'] != null &&
                            data['description']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            data['description'],
                            style: const TextStyle(
                                color: _NB.textGrey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ]),
                    ),
                    Column(children: [
                      _iconBtn(
                        icon:  Icons.edit_outlined,
                        color: _NB.navy,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductPage(
                              shopId:        widget.shopId,
                              editProductId: productId,
                              editData:      data,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _iconBtn(
                        icon:  Icons.delete_outline,
                        color: _NB.red,
                        onTap: () => _deleteProduct(productId),
                      ),
                    ]),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _listImgPlaceholder() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: _NB.orangeBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.image_outlined, color: _NB.orange, size: 26),
  );

  Widget _iconBtn({
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editProductId != null;

    return Scaffold(
      backgroundColor: _NB.bg,

      appBar: AppBar(
        backgroundColor: _NB.navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
            color: _NB.orange, size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isEdit ? 'Edit Product' : 'Add Product',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ]),
      ),

      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  decoration: BoxDecoration(
                    color: _NB.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        _sectionHeader(
                          isEdit ? 'Edit Product Details' : 'Product Details',
                          Icons.inventory_2_outlined,
                        ),

                        // Image picker (mandatory in both add & edit)
                        _imagePicker(),
                        const SizedBox(height: 18),

                        // Name field
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDec(
                            label: 'Product Name *',
                            icon:  Icons.label_outline,
                            hint:  'e.g. Fresh Apples (1kg)',
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty
                                  ? 'Enter product name'
                                  : null,
                        ),
                        const SizedBox(height: 14),

                        // Description field
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: _inputDec(
                            label: 'Description (optional)',
                            icon:  Icons.description_outlined,
                            hint:  'Brief description of the product...',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Price field
                        TextFormField(
                          controller: _priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: _inputDec(
                            label: 'Price (Rs.) *',
                            icon:  Icons.currency_rupee,
                            hint:  'e.g. 150',
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty
                                  ? 'Enter price'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Out of Stock toggle (edit mode only)
                        if (isEdit) ...[
                          _sectionHeader(
                              'Stock Status', Icons.store_outlined),
                          _outOfStockToggle(),
                          const SizedBox(height: 6),
                        ],

                        const SizedBox(height: 6),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _NB.orange,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                            onPressed: _loading ? null : _saveProduct,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isEdit
                                            ? Icons.check_circle_outline
                                            : Icons.add_circle_outline,
                                        color: Colors.white, size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isEdit
                                            ? 'Update Product'
                                            : 'Add Product',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Cancel button (edit mode only)
                        if (isEdit) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: _NB.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                                foregroundColor: _NB.textGrey,
                              ),
                              onPressed: () =>
                                  Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Product list (add mode only)
                if (!isEdit) ...[
                  _sectionHeader(
                      'My Products', Icons.storefront_outlined),
                  _productList(),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}