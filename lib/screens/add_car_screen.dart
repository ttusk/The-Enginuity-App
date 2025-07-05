import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  AddCarScreenState createState() => AddCarScreenState();
}

class AddCarScreenState extends State<AddCarScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMake, _selectedModel;
  final _mileageCtrl = TextEditingController();
  DateTime? _lastServiceDate;
  File? _carImageFile;
  bool _saving = false;

  final makes = ['MG'];
  final models = {
    'MG': ['ZS'],
  };
  final defaultImageUrl =
      'https://cdn-icons-png.flaticon.com/512/743/743977.png';

  final imgbbApiKey = '78cfc12518ea394bdab65822d14ffc3f';

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      setState(() => _carImageFile = File(picked.path));
    }
  }

  Future<String> _uploadImageToImgBB(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.imgbb.com/1/upload?key=$imgbbApiKey'),
      body: {'image': base64Image},
    );

    final json = jsonDecode(response.body);
    if (json['status'] == 200) {
      return json['data']['url'];
    } else {
      throw Exception('Image upload failed');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) setState(() => _lastServiceDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final uid = user.uid;

      String imageUrl = defaultImageUrl;
      if (_carImageFile != null) {
        imageUrl = await _uploadImageToImgBB(_carImageFile!);
      }

      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(uid)
      //     .collection('cars')
      //     .add({
      //   'make': _selectedMake,
      //   'model': _selectedModel,
      //   'mileage': int.parse(_mileageCtrl.text),
      //   'lastServiceDate': _lastServiceDate,
      //   'imageUrl': imageUrl,
      //   'createdAt': FieldValue.serverTimestamp(),
      // });

      final mileage = int.parse(_mileageCtrl.text);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cars')
          .add({
            'make': _selectedMake,
            'model': _selectedModel,
            'mileage': mileage,
            'initialMileage': mileage, // Required for 10k km check
            'lastServiceDate': _lastServiceDate,
            'lastScan':
                FieldValue.serverTimestamp(), // Placeholder until real scan
            'imageUrl': imageUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFF12303B),
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );

  @override
  void dispose() {
    _mileageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add a Car', style: TextStyle(color: Colors.white)),
      ),
      body:
          _saving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                _carImageFile != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _carImageFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Image.network(defaultImageUrl),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text("Camera"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A42),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed:
                                    () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.image, size: 18),
                                label: const Text("Gallery"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A42),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      DropdownButtonFormField<String>(
                        value: _selectedMake,
                        decoration: _dec('Car Make'),
                        items:
                            makes
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setState(() {
                              _selectedMake = val;
                              _selectedModel = null;
                            }),
                        validator: (v) => v == null ? 'Select make' : null,
                        dropdownColor: const Color(0xFF12303B),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _selectedModel,
                        decoration: _dec('Car Model'),
                        items:
                            _selectedMake == null
                                ? []
                                : models[_selectedMake!]!
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                    )
                                    .toList(),
                        onChanged:
                            (val) => setState(() => _selectedModel = val),
                        validator: (v) => v == null ? 'Select model' : null,
                        dropdownColor: const Color(0xFF12303B),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _mileageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Car Mileage (Miles)'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter mileage';
                          if (int.tryParse(v) == null) {
                            return 'Enter valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _dec(
                              'Last Service Date',
                            ).copyWith(hintText: 'dd/MM/yyyy'),
                            controller: TextEditingController(
                              text:
                                  _lastServiceDate == null
                                      ? ''
                                      : DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_lastServiceDate!),
                            ),
                            validator:
                                (_) =>
                                    _lastServiceDate == null
                                        ? 'Select date'
                                        : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text("ADD"),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
