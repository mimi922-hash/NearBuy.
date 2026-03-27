import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart'; // ✅ Import Cloudinary Service

class ShopRegistrationPage extends StatefulWidget {
  const ShopRegistrationPage({super.key});

  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}

class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  static const Color darkBlue = Color(0xFF0B2C4D);
  static const Color orange = Color(0xFFF4511E);
  static const Color lightOrange = Color(0xFFF4511E);
  static const Color white = Colors.white;

  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // STEP 1
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerContactController = TextEditingController(text: "03");

  // STEP 2
  final _shopNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _regNoController = TextEditingController();
  String? _shopCategory;

  // STEP 3
  final _shopLocationController = TextEditingController();
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  int _currentStep = 0;
  final user = FirebaseAuth.instance.currentUser;

  // Images
  File? _cnicFrontImage;
  File? _cnicBackImage;
  File? _shopImage;

  String? _cnicFrontUrl;
  String? _cnicBackUrl;
  String? _shopImageUrl;

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
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) return File(image.path);
    return null;
  }

  Future<void> _submitForm() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
    );

    try {
      if (_shopImage != null) {
        _shopImageUrl = await CloudinaryService.uploadImage(_shopImage!, 'nearbuy_preset');
      }
      if (_cnicFrontImage != null) {
        _cnicFrontUrl = await CloudinaryService.uploadImage(_cnicFrontImage!, 'nearbuy_preset');
      }
      if (_cnicBackImage != null) {
        _cnicBackUrl = await CloudinaryService.uploadImage(_cnicBackImage!, 'nearbuy_preset');
      }

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
            ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude)
            : GeoPoint(0, 0),
        'cnic_front_url': _cnicFrontUrl ?? '',
        'cnic_back_url': _cnicBackUrl ?? '',
        'shop_image_url': _shopImageUrl ?? '',
        'status': 'pending',
        'created_at': Timestamp.now(),
      });

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      print("Submit Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit")));
    }
  }

  Future<void> _pickLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    LatLng current = LatLng(pos.latitude, pos.longitude);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: SizedBox(
          height: 400,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: current, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            onTap: (latLng) => setState(() => _selectedLocation = latLng),
            markers: _selectedLocation == null
                ? {}
                : { Marker(markerId: const MarkerId('shop'), position: _selectedLocation!) },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_selectedLocation != null) {
                List<Placemark> p = await placemarkFromCoordinates(_selectedLocation!.latitude, _selectedLocation!.longitude);
                _shopLocationController.text = '${p.first.street}, ${p.first.locality}';
              }
              Navigator.pop(context);
            },
            child: const Text("Select"),
          )
        ],
      ),
    );
  }

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: orange),
          labelText: label,
          floatingLabelStyle: const TextStyle(color: darkBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: orange.withOpacity(0.6)),
          ),
        ),
      ),
    );
  }

  Widget stepWizard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _currentStep == i ? orange : white,
            shape: BoxShape.circle,
            border: Border.all(color: darkBlue),
          ),
          child: Text("${i + 1}", style: TextStyle(color: _currentStep == i ? white : darkBlue, fontWeight: FontWeight.bold)),
        );
      }),
    );
  }

  Widget bottomButton(String text, VoidCallback onTap, {Color? background}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: background ?? darkBlue,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(color: white)),
      ),
    );
  }

  Widget backNextButtons(String nextText) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  backgroundColor: _currentStep == 0 ? white : lightOrange,
                  foregroundColor: _currentStep == 0 ? darkBlue : white),
              onPressed: _previousStep,
              child: const Text("Back"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: bottomButton(nextText, _nextStep)),
        ],
      );

  Widget stepTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
      );

  Widget imageUploadBox(String title, IconData icon, File? imageFile, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: darkBlue),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: orange),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: darkBlue))),
            imageFile != null
                ? Image.file(imageFile, width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.upload, color: darkBlue),
          ],
        ),
      ),
    );
  }

  final phoneFormatter = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
    _PhoneNumberTextInputFormatter(),
  ];

  final cnicFormatter = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(13),
    _CnicTextInputFormatter(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: darkBlue,
        centerTitle: true,
        leading: const BackButton(color: white),
        title: const Text("Shop Registration", style: TextStyle(color: white)),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 10),
            stepWizard(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // STEP 1
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        stepTitle("Owner Details"),
                        field(controller: _ownerNameController, label: "Owner Name", icon: Icons.person, validator: (v) => v!.isEmpty ? "Owner name is required" : null),
                        field(controller: _ownerEmailController, label: "Email", icon: Icons.email, readOnly: true),
                        field(controller: _ownerContactController, label: "Phone Number", icon: Icons.phone, keyboard: TextInputType.number, inputFormatters: phoneFormatter, validator: (v) => RegExp(r'^03\d{2}-\d{7}$').hasMatch(v!) ? null : "Phone must be 03xx-xxxxxxx"),
                        const SizedBox(height: 12),
                        imageUploadBox("Upload CNIC Front Image", Icons.badge, _cnicFrontImage, () async { File? img = await pickImage(); if (img != null) setState(() => _cnicFrontImage = img); }),
                        const SizedBox(height: 12),
                        imageUploadBox("Upload CNIC Back Image", Icons.badge, _cnicBackImage, () async { File? img = await pickImage(); if (img != null) setState(() => _cnicBackImage = img); }),
                        const Spacer(),
                        bottomButton("Next", _nextStep),
                      ],
                    ),
                  ),

                  // STEP 2
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        stepTitle("Shop Details"),
                        field(controller: _shopNameController, label: "Shop Name", icon: Icons.store, validator: (v) => v!.isEmpty ? "Shop name required" : null),
                        DropdownButtonFormField(
                          value: _shopCategory,
                          decoration: InputDecoration(prefixIcon: const Icon(Icons.category, color: orange), floatingLabelStyle: const TextStyle(color: darkBlue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          hint: const Text("Select Grocery Category"),
                          items: groceryCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _shopCategory = v),
                          validator: (v) => v == null ? "Please select category" : null,
                        ),
                        const SizedBox(height: 14),
                        field(controller: _cnicController, label: "CNIC Number", icon: Icons.badge, keyboard: TextInputType.number, inputFormatters: cnicFormatter, validator: (v) => RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(v!) ? null : "Format: XXXXX-XXXXXXX-X"),
                        const SizedBox(height: 12),
                        imageUploadBox("Upload Shop Image", Icons.store, _shopImage, () async { File? img = await pickImage(); if (img != null) setState(() => _shopImage = img); }),
                        const SizedBox(height: 14),
                        field(controller: _regNoController, label: "Registration Number", icon: Icons.assignment, validator: (v) => v!.length < 4 ? "Invalid registration number" : null),
                        const Spacer(),
                        backNextButtons("Next"),
                      ],
                    ),
                  ),

                  // STEP 3
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        stepTitle("Select Location"),
                        field(controller: _shopLocationController, label: "Shop Location", icon: Icons.location_on, readOnly: true, validator: (v) => v!.isEmpty ? "Please select location" : null),
                        bottomButton("Pick Location from Map", _pickLocation),
                        const Spacer(),
                        backNextButtons("Submit"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneNumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 4) formatted += '-';
      formatted += digits[i];
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class _CnicTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 13) digits = digits.substring(0, 13);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 5 || i == 12) formatted += '-';
      formatted += digits[i];
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}