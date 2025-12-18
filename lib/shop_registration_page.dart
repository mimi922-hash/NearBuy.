// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopRegistrationPage extends StatefulWidget {
  const ShopRegistrationPage({super.key});

  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}

class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // Step 1: Owner Details
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  // Step 2: Shop Details
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopDescriptionController = TextEditingController();
  String? _shopCategory;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  // Manual CNIC field
  final TextEditingController _cnicController = TextEditingController();

  // Registration Number field 
  final TextEditingController _regNoController = TextEditingController();

  // Step 3: Shop Location
  final TextEditingController _shopLocationController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ownerEmailController.text = user?.email ?? '';
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
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('shops').add({
        'owner_name': _ownerNameController.text,
        'owner_email': _ownerEmailController.text,
        'owner_contact': _ownerContactController.text,
        'shop_name': _shopNameController.text,
        'shop_description': _shopDescriptionController.text,
        'shop_category': _shopCategory,
        'open_time': _openTime?.format(context),
        'close_time': _closeTime?.format(context),
        'cnic_number': _cnicController.text,
        'registration_no': _regNoController.text, 
        'shop_location': _shopLocationController.text,
        'status': 'pending',
        'created_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop Registered Successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shop Registration")),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // -------------------- STEP 1 --------------------
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _ownerNameController,
                          decoration:
                              const InputDecoration(labelText: "Owner Name"),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter owner name"
                              : null,
                        ),
                        TextFormField(
                          controller: _ownerEmailController,
                          decoration:
                              const InputDecoration(labelText: "Owner Email"),
                          readOnly: true,
                        ),
                        TextFormField(
                          controller: _ownerContactController,
                          decoration:
                              const InputDecoration(labelText: "Contact Number"),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return "Enter contact number";
                            if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value))
                              return "Enter valid number";
                            return null;
                          },
                        ),
                        const Spacer(),
                        ElevatedButton(
                            onPressed: _nextStep, child: const Text("Next")),
                      ],
                    ),
                  ),

                  // -------------------- STEP 2 --------------------
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _shopNameController,
                            decoration:
                                const InputDecoration(labelText: "Shop Name"),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? "Enter shop name"
                                    : null,
                          ),
                          DropdownButtonFormField<String>(
                            value: _shopCategory,
                            hint: const Text("Select Shop Category"),
                            items: ['Grocery', 'Electronics', 'Clothing', 'Other']
                                .map((cat) => DropdownMenuItem(
                                    value: cat, child: Text(cat)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _shopCategory = val),
                            validator: (value) =>
                                value == null ? "Select a category" : null,
                          ),

                          // -------- MANUAL CNIC FIELD --------
                          TextFormField(
                            controller: _cnicController,
                            decoration: const InputDecoration(
                                labelText: "CNIC Number (xxxxx-xxxxxxx-x)"),
                            maxLength: 15,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return "Enter CNIC number";
                              if (!RegExp(r'^\d{5}-\d{7}-\d{1}$')
                                  .hasMatch(value)) {
                                return "Format must be 12345-1234567-1";
                              }
                              return null;
                            },
                          ),

                           // ------- Registration Number -------
                          TextFormField(
                            controller: _regNoController,
                            decoration: const InputDecoration(
                                labelText: "Registration Number"),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Enter Registration Number";
                              }
                              return null;
                            },
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: Text(_openTime == null
                                    ? 'Open Time'
                                    : 'Open: ${_openTime!.format(context)}'),
                              ),
                              TextButton(
                                  onPressed: () => _pickTime(true),
                                  child: const Text("Pick")),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(_closeTime == null
                                    ? 'Close Time'
                                    : 'Close: ${_closeTime!.format(context)}'),
                              ),
                              TextButton(
                                  onPressed: () => _pickTime(false),
                                  child: const Text("Pick")),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                  onPressed: _previousStep,
                                  child: const Text("Back")),
                              ElevatedButton(
                                  onPressed: _nextStep,
                                  child: const Text("Next")),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -------------------- STEP 3 --------------------
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _shopLocationController,
                          decoration:
                              const InputDecoration(labelText: "Shop Location"),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter shop location"
                              : null,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                                onPressed: _previousStep,
                                child: const Text("Back")),
                            ElevatedButton(
                                onPressed: _nextStep,
                                child: const Text("Submit")),
                          ],
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
