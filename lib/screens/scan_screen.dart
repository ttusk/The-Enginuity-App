import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

class ScanScreen extends StatefulWidget {
  final Map<String, dynamic>? carData;
  // You can pass the device connection status from outside when real integration is ready
  final bool deviceConnected;
  final bool skipPreconditions;

  const ScanScreen({Key? key, required this.carData, this.deviceConnected = false, this.skipPreconditions = false}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<_ScanRecord> _history = [];
  File? _carImageFile;
  // Map to hold metric values (0.0 - 1.0) for progress bars
  final Map<String, double> _metrics = {
    'ENGINE_RUN_TIME': 0,
    'ENGINE_RPM': 0,
    'VEHICLE_SPEED': 0,
    'THROTTLE': 0,
    'ENGINE_LOAD': 0,
    'COOLANT_TEMPERATURE': 0,
    'LONG_TERM_FUEL_TRIM_BANK_1': 0,
    'SHORT_TERM_FUEL_TRIM_BANK_1': 0,
    'INTAKE_MANIFOLD_PRESSURE': 0,
    'FUEL_TANK': 0,
    'ABSOLUTE_THROTTLE_B': 0,
    'PEDAL_D': 0,
    'PEDAL_E': 0,
    'COMMANDED_THROTTLE_ACTUATOR': 0,
    'FUEL_AIR_COMMANDED_EQUIV_RATIO': 0,
    'ABSOLUTE_BAROMETRIC_PRESSURE': 0,
    'RELATIVE_THROTTLE_POSITION': 0,
    'INTAKE_AIR_TEMP': 0,
    'TIMING_ADVANCE': 0,
    'CATALYST_TEMPERATURE_BANK1_SENSOR1': 0,
    'CATALYST_TEMPERATURE_BANK1_SENSOR2': 0,
    'CONTROL_MODULE_VOLTAGE': 0,
    'COMMANDED_EVAPORATIVE_PURGE': 0,
    'TIME_RUN_WITH_MIL_ON': 0,
    'TIME_SINCE_TROUBLE_CODES_CLEARED': 0,
    'DISTANCE_TRAVELED_WITH_MIL_ON': 0,
  };

  @override
  void initState() {
    super.initState();
    // If the car already has an image, keep a reference so we can display it
    if (widget.carData != null && widget.carData!['imageFile'] is File) {
      _carImageFile = widget.carData!['imageFile'] as File;
    }
  }

  Future<void> _pickCarImage() async {
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
    // Preconditions
    if (!widget.skipPreconditions && widget.carData == null) {
      return _buildPreconditionScreen('Add a car to start scanning', Icons.directions_car);
    }

    if (!widget.skipPreconditions && !widget.deviceConnected) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1F26),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Make sure device is connected to start scanning',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    final make = widget.carData?['make'] ?? '';
    final model = widget.carData?['model'] ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1F26),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // Car image
            SizedBox(
              width: double.infinity,
              height: 180,
              child: _carImageFile == null
                  ? Container(
                      color: Colors.black54,
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _pickCarImage,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                          child: const Text('Add Car Image'),
                        ),
                      ),
                    )
                  : Image.file(
                      _carImageFile!,
                      fit: BoxFit.cover,
                    ),
            ),
            Container(
              color: const Color(0xFF12303B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      Text(make, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.search, color: Colors.white70),
                ],
              ),
            ),
            // Tabs
            const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(child: Text('Latest Scan')),
                Tab(child: Text('Scan History')),
              ],
            ),
            // Tab views
            Expanded(
              child: TabBarView(
                children: [
                  _buildLatestScan(),
                  _buildHistory(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _connectAndFetch,
              icon: const Icon(Icons.search),
              label: const Text('Scan Now'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestScan() {
    final entries = _metrics.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final name = entry.key;
        final value = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name + ':', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (value * 100).toInt().toString() + '%',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const Center(
        child: Text('No scan history yet', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final rec = _history[index];
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(rec.date);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formattedDate, style: const TextStyle(color: Colors.white)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A42),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                onPressed: () => OpenFile.open(rec.path),
                child: const Text('Download'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to build beautiful precondition screens
  Widget _buildPreconditionScreen(String message, IconData icon) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectAndFetch() async {
    // TODO: Integrate with actual ELM327 library / Bluetooth connectivity
    // For now, simulate fetch by assigning random demo values
    if (!widget.deviceConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected')),
      );
      return;
    }

    // Simulate fetching with delay
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _metrics.updateAll((key, value) => (value + 0.1) % 1.0);
    });

    // Generate PDF summary
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _metrics.entries
                .map((e) => pw.Text('${e.key}: ${(e.value * 100).toInt()}%'))
                .toList(),
          );
        },
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final fileName = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now()) + '_scan.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    setState(() {
      _history.add(_ScanRecord(DateTime.now(), filePath));
    });
  }
}

class _ScanRecord {
  final DateTime date;
  final String path;
  _ScanRecord(this.date, this.path);
}
