import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ShopRegistrationPage extends StatefulWidget {
  const ShopRegistrationPage({super.key});

  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}

class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // STEP 1
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerContactController = TextEditingController();

  // STEP 2
  final _shopNameController = TextEditingController();
  String? _shopCategory;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  final _cnicController = TextEditingController();
  final _regNoController = TextEditingController();

  // STEP 3
  final _shopLocationController = TextEditingController();
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  int _currentStep = 0;
  bool _isSubmitting = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ownerEmailController.text = user?.email ?? '';
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _stepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (_currentStep + 1) / 3,
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
          _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        });
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    });
  }

  Future<void> _submitForm() async {
    if (_selectedLocation == null) return;

    setState(() => _isSubmitting = true);

    await FirebaseFirestore.instance.collection('shops').add({
      'owner_name': _ownerNameController.text,
      'owner_email': _ownerEmailController.text,
      'owner_contact': _ownerContactController.text,
      'shop_name': _shopNameController.text,
      'shop_category': _shopCategory,
      'cnic': _cnicController.text,
      'reg_no': _regNoController.text,
      'open_time': _openTime?.format(context),
      'close_time': _closeTime?.format(context),
      'location_text': _shopLocationController.text,
      'lat': _selectedLocation!.latitude,
      'lng': _selectedLocation!.longitude,
      'geo': GeoPoint(
          _selectedLocation!.latitude, _selectedLocation!.longitude),
      'status': 'pending',
      'created_at': Timestamp.now(),
    });

    Navigator.pop(context);
  }

  Future<void> _pickLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    LatLng current = LatLng(pos.latitude, pos.longitude);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Shop Location"),
        content: SizedBox(
          height: 350,
          child: GoogleMap(
            initialCameraPosition:
                CameraPosition(target: current, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            onTap: (latLng) {
              setState(() => _selectedLocation = latLng);
              _mapController!
                  .animateCamera(CameraUpdate.newLatLng(latLng));
            },
            markers: _selectedLocation == null
                ? {}
                : {
                    Marker(
                        markerId: const MarkerId("shop"),
                        position: _selectedLocation!)
                  },
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text("Confirm"),
            onPressed: () async {
              List<Placemark> placemarks =
                  await placemarkFromCoordinates(
                      _selectedLocation!.latitude,
                      _selectedLocation!.longitude);
              Placemark p = placemarks.first;
              _shopLocationController.text =
                  "${p.street}, ${p.locality}";
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Your Shop")),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // STEP 1
                  _buildCard(
                    _stepHeader("Owner Details",
                        "Tell us about the shop owner"),
                    [
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: _input("Owner Name", Icons.person),
                        validator: (v) =>
                            v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ownerEmailController,
                        readOnly: true,
                        decoration: _input("Email", Icons.email),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ownerContactController,
                        decoration: _input("Contact", Icons.phone),
                        validator: (v) =>
                            v!.isEmpty ? "Required" : null,
                      ),
                      _nextButton("Next"),
                    ],
                  ),

                  // STEP 2
                  _buildCard(
                    _stepHeader(
                        "Shop Information", "Basic shop details"),
                    [
                      TextFormField(
                        controller: _shopNameController,
                        decoration:
                            _input("Shop Name", Icons.store),
                        validator: (v) =>
                            v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField(
                        decoration:
                            _input("Category", Icons.category),
                        items: ["Grocery", "Electronics", "Clothing"]
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _shopCategory = v),
                        validator: (v) =>
                            v == null ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cnicController,
                        decoration: _input("CNIC", Icons.badge),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regNoController,
                        decoration:
                            _input("Registration No", Icons.numbers),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: () =>
                                  showTimePicker(
                                      context: context,
                                      initialTime:
                                          TimeOfDay.now())
                                      .then((v) =>
                                          setState(() => _openTime = v)),
                              child: const Text("Open Time")),
                          TextButton(
                              onPressed: () =>
                                  showTimePicker(
                                      context: context,
                                      initialTime:
                                          TimeOfDay.now())
                                      .then((v) =>
                                          setState(() => _closeTime = v)),
                              child: const Text("Close Time")),
                        ],
                      ),
                      _navButtons(),
                    ],
                  ),

                  // STEP 3
                  _buildCard(
                    _stepHeader("Shop Location",
                        "Pin your shop on map"),
                    [
                      TextFormField(
                        controller: _shopLocationController,
                        readOnly: true,
                        decoration:
                            _input("Location", Icons.location_on),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickLocation,
                        icon: const Icon(Icons.map),
                        label: const Text("Pick from Map"),
                      ),
                      _navButtons(isLast: true),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(Widget header, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(children: [header, ...children]),
          ),
        ),
      ),
    );
  }

  Widget _nextButton(String text) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SizedBox(
          width: double.infinity,
          child:
              ElevatedButton(onPressed: _nextStep, child: Text(text)),
        ),
      );

  Widget _navButtons({bool isLast = false}) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: _previousStep, child: const Text("Back")),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                  onPressed: _nextStep,
                  child: Text(isLast ? "Submit" : "Next")),
            ),
          ],
        ),
      );
}
