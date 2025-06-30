import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({Key? key}) : super(key: key);

  @override
  _AddCarScreenState createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMake;
  String? _selectedModel;
  final _mileageController = TextEditingController();
  DateTime? _lastServiceDate;
  File? _carImageFile;

  final List<String> _makes = ['MG'];
  final Map<String, List<String>> _models = {
    'MG': ['ZS'],
  };

  @override
  void dispose() {
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _lastServiceDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _carImageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add a Car', style: TextStyle(color: Colors.white)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: _carImageFile == null
                        ? const Icon(Icons.directions_car, size: 48, color: Colors.white54)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_carImageFile!, fit: BoxFit.cover),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add a picture of your car', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Upload'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22313F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _selectedMake,
                decoration: _inputDecoration('Car Make'),
                items: _makes.map<DropdownMenuItem<String>>((make) => DropdownMenuItem<String>(
                  value: make,
                  child: Text(make),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedMake = val;
                    _selectedModel = null;
                  });
                },
                validator: (value) => value == null ? 'Please select a car make' : null,
                dropdownColor: const Color(0xFF22313F),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: _inputDecoration('Car Model'),
                items: (_selectedMake == null ? <DropdownMenuItem<String>>[] : _models[_selectedMake]!.map<DropdownMenuItem<String>>((model) => DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                )).toList()),
                onChanged: (val) {
                  setState(() {
                    _selectedModel = val;
                  });
                },
                validator: (value) => value == null ? 'Please select a car model' : null,
                dropdownColor: const Color(0xFF22313F),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _mileageController,
                decoration: _inputDecoration('Car Mileage (KM)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the car mileage';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: _inputDecoration('Last Service Date').copyWith(
                      hintText: 'dd/MM/yyyy',
                    ),
                    controller: TextEditingController(
                      text: _lastServiceDate == null ? '' : DateFormat('dd/MM/yyyy').format(_lastServiceDate!),
                    ),
                    validator: (value) {
                      if (_lastServiceDate == null) {
                        return 'Please select the last service date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Prepare car data
                    final carData = {
                      'make': _selectedMake,
                      'model': _selectedModel,
                      'mileage': _mileageController.text,
                      'lastServiceDate': _lastServiceDate,
                      'imageFile': _carImageFile ?? 'No image uploaded',
                    };
                    Navigator.of(context).pop(carData);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22313F),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('ADD'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF22313F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
} 