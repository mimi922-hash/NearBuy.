import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
 
class ShopRegistrationPage extends StatefulWidget {
  const ShopRegistrationPage({super.key});
  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}
 
class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  // ── Brand Colors ──
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
  static const Color lightNavy    = Color(0xFF1A3A5C);
  static const Color bgColor      = Color(0xFFF8FAFC);
 
  // All controllers, logic variables unchanged ──────────
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final _ownerNameController    = TextEditingController();
  final _ownerEmailController   = TextEditingController();
  final _ownerContactController = TextEditingController(text: '03');
  final _shopNameController     = TextEditingController();
  final _cnicController         = TextEditingController();
  final _regNoController        = TextEditingController();
  String? _shopCategory;
  final _shopLocationController = TextEditingController();
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  int _currentStep = 0;
  final user = FirebaseAuth.instance.currentUser;
  File? _cnicFrontImage, _cnicBackImage, _shopImage;
  String? _cnicFrontUrl, _cnicBackUrl, _shopImageUrl;
 
  final List<String> groceryCategories = [
    'General Store', 'Super Mart', 'Vegetable Shop', 'Fruit Shop',
    'Meat Shop', 'Bakery', 'Dairy Shop', 'Frozen Foods',
    'Spices Store', 'Organic Store', 'Wholesale Grocery', 'Convenience Store',
  ];
 
  @override
  void initState() {
    super.initState();
    _ownerEmailController.text = user?.email ?? '';
  }
 
  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else { _submitForm(); }
    }
  }
 
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }
 
  Future<File?> pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) return File(image.path);
    return null;
  }
 
  Future<void> _submitForm() async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A))));
    try {
      if (_shopImage != null) _shopImageUrl = await CloudinaryService.uploadImage(_shopImage!, 'nearbuy_preset');
      if (_cnicFrontImage != null) _cnicFrontUrl = await CloudinaryService.uploadImage(_cnicFrontImage!, 'nearbuy_preset');
      if (_cnicBackImage != null) _cnicBackUrl = await CloudinaryService.uploadImage(_cnicBackImage!, 'nearbuy_preset');
      await FirebaseFirestore.instance.collection('shops').add({
        'owner_name': _ownerNameController.text,
        'owner_email': _ownerEmailController.text,
        'owner_contact': _ownerContactController.text,
        'shop_name': _shopNameController.text,
        'shop_category': _shopCategory,
        'cnic_number': _cnicController.text,
        'registration_no': _regNoController.text,
        'shop_location': _shopLocationController.text,
        'location_lat': _selectedLocation?.latitude ?? 0.0,
        'location_lng': _selectedLocation?.longitude ?? 0.0,
        'location_geo': _selectedLocation != null
            ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude) : GeoPoint(0, 0),
        'cnic_front_url': _cnicFrontUrl ?? '',
        'cnic_back_url': _cnicBackUrl ?? '',
        'shop_image_url': _shopImageUrl ?? '',
        'status': 'pending',
        'created_at': Timestamp.now(),
      });
      Navigator.pop(context); Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit')));
    }
  }
 
  Future<void> _pickLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    LatLng current = LatLng(pos.latitude, pos.longitude);
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SizedBox(height: 400, child: GoogleMap(
        initialCameraPosition: CameraPosition(target: current, zoom: 15),
        onMapCreated: (c) => _mapController = c,
        onTap: (latLng) => setState(() => _selectedLocation = latLng),
        markers: _selectedLocation == null ? {}
            : { Marker(markerId: const MarkerId('shop'), position: _selectedLocation!) },
      )),
      actions: [
        TextButton(child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context)),
        ElevatedButton(style: ElevatedButton.styleFrom(
            backgroundColor: accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Select', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            if (_selectedLocation != null) {
              List<Placemark> p = await placemarkFromCoordinates(
                  _selectedLocation!.latitude, _selectedLocation!.longitude);
              _shopLocationController.text = '${p.first.street}, ${p.first.locality}';
            }
            Navigator.pop(context);
          },
        ),
      ],
    ));
  }
 
  // ── UI Helpers ──
  Widget _field({
    required TextEditingController controller, required String label,
    required IconData icon, String? Function(String?)? validator,
    bool readOnly = false, TextInputType? keyboard, List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller, readOnly: readOnly,
        keyboardType: keyboard, inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: accentOrange),
          labelText: label,
          floatingLabelStyle: const TextStyle(color: primaryNavy),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accentOrange, width: 1.5)),
        ),
      ),
    );
  }
 
  // ✅ Updated step wizard
  Widget _stepWizard() {
    final steps = ['Owner', 'Shop', 'Location'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = _currentStep == i;
          final isDone   = _currentStep > i;
          return Expanded(
            child: Row(
              children: [
                Column(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? accentOrange : isDone ? primaryNavy : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isActive || isDone ? Colors.transparent : Colors.grey.shade300, width: 1.5),
                      boxShadow: isActive ? [BoxShadow(color: accentOrange.withOpacity(0.3), blurRadius: 10)] : [],
                    ),
                    child: Center(child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text('${i+1}', style: TextStyle(
                            color: isActive || isDone ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i], style: TextStyle(
                      fontSize: 11, color: isActive ? accentOrange : Colors.grey.shade500,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                ]),
                if (i < 2) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 22),
                    color: isDone ? primaryNavy : Colors.grey.shade200)),
              ],
            ),
          );
        }),
      ),
    );
  }
 
  // ✅ Updated image upload box
  Widget _imageUploadBox(String title, IconData icon, File? imageFile, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: imageFile != null ? accentOrange : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: accentOrange),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: primaryNavy))),
          imageFile != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Image.file(imageFile, width: 50, height: 50, fit: BoxFit.cover))
              : Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.upload_outlined, color: accentOrange, size: 18)),
        ]),
      ),
    );
  }
 
  Widget _bottomButton(String text, VoidCallback onTap, {Color? bg}) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: bg ?? primaryNavy, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: onTap,
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
 
  Widget _backNextButtons(String nextText) => Row(children: [
    Expanded(child: OutlinedButton(
      style: OutlinedButton.styleFrom(
          side: BorderSide(color: _currentStep == 0 ? Colors.grey.shade300 : accentOrange),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: _currentStep == 0 ? Colors.grey : accentOrange),
      onPressed: _previousStep,
      child: const Text('Back'),
    )),
    const SizedBox(width: 12),
    Expanded(child: _bottomButton(nextText, _nextStep, bg: accentOrange)),
  ]);
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: const Text('Shop Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _stepWizard(),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // ── STEP 1: Owner Details ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      _sectionTitle('Owner Details', Icons.person_outline),
                      _field(controller: _ownerNameController, label: 'Owner Name', icon: Icons.person,
                          validator: (v) => v!.isEmpty ? 'Owner name is required' : null),
                      _field(controller: _ownerEmailController, label: 'Email', icon: Icons.email, readOnly: true),
                      _field(controller: _ownerContactController, label: 'Phone Number', icon: Icons.phone,
                          keyboard: TextInputType.number, inputFormatters: phoneFormatter,
                          validator: (v) => RegExp(r'^03\d{2}-\d{7}$').hasMatch(v!) ? null : 'Format: 03xx-xxxxxxx'),
                      const SizedBox(height: 14),
                      _imageUploadBox('Upload CNIC Front', Icons.badge, _cnicFrontImage,
                          () async { File? img = await pickImage(); if (img != null) setState(() => _cnicFrontImage = img); }),
                      const SizedBox(height: 12),
                      _imageUploadBox('Upload CNIC Back', Icons.badge, _cnicBackImage,
                          () async { File? img = await pickImage(); if (img != null) setState(() => _cnicBackImage = img); }),
                      const SizedBox(height: 24),
                      _bottomButton('Next →', _nextStep, bg: accentOrange),
                    ]),
                  ),
 
                  // ── STEP 2: Shop Details ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      _sectionTitle('Shop Details', Icons.store_outlined),
                      _field(controller: _shopNameController, label: 'Shop Name', icon: Icons.store,
                          validator: (v) => v!.isEmpty ? 'Shop name required' : null),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField(
                          value: _shopCategory,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.category, color: Color(0xFFFF6A1A)),
                            labelText: 'Shop Category',
                            floatingLabelStyle: const TextStyle(color: primaryNavy),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: accentOrange, width: 1.5)),
                          ),
                          items: groceryCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _shopCategory = v),
                          validator: (v) => v == null ? 'Please select category' : null,
                        ),
                      ),
                      _field(controller: _cnicController, label: 'CNIC Number', icon: Icons.badge,
                          keyboard: TextInputType.number, inputFormatters: cnicFormatter,
                          validator: (v) => RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(v!) ? null : 'Format: XXXXX-XXXXXXX-X'),
                      const SizedBox(height: 4),
                      _imageUploadBox('Upload Shop Image', Icons.store, _shopImage,
                          () async { File? img = await pickImage(); if (img != null) setState(() => _shopImage = img); }),
                      const SizedBox(height: 12),
                      _field(controller: _regNoController, label: 'Registration Number', icon: Icons.assignment,
                          validator: (v) => v!.length < 4 ? 'Invalid registration number' : null),
                      const SizedBox(height: 16),
                      _backNextButtons('Next →'),
                    ]),
                  ),
 
                  // ── STEP 3: Location ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      _sectionTitle('Shop Location', Icons.location_on_outlined),
                      _field(controller: _shopLocationController, label: 'Shop Location', icon: Icons.location_on,
                          readOnly: true, validator: (v) => v!.isEmpty ? 'Please select location' : null),
                      const SizedBox(height: 8),
                      _bottomButton('📍 Pick Location from Map', _pickLocation, bg: const Color(0xFF0E2A47).withOpacity(0.8)),
                      const SizedBox(height: 28),
                      _backNextButtons('Submit ✓'),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _sectionTitle(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accentOrange, size: 22)),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryNavy)),
    ]),
  );
 
  final phoneFormatter = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11), _PhoneNumberTextInputFormatter()];
  final cnicFormatter  = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13), _CnicTextInputFormatter()];
}
 
// ── formatters unchanged ──
class _PhoneNumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) { if (i == 4) formatted += '-'; formatted += digits[i]; }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
class _CnicTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 13) digits = digits.substring(0, 13);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) { if (i == 5 || i == 12) formatted += '-'; formatted += digits[i]; }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
