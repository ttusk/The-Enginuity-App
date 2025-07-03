import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'errors_screen.dart';
import '../obd_connection_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanScreen extends StatefulWidget {
  final Map<String, dynamic>? carData;
  // You can pass the device connection status from outside when real integration is ready
  final bool deviceConnected;
  final bool skipPreconditions;

  const ScanScreen({
    super.key,
    required this.carData,
    this.deviceConnected = false,
    this.skipPreconditions = false,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Future<void> _updateLastScanInFirestore({
    required String carId,
    required DateTime scanTime,
    List<dynamic>? errors,
    List<dynamic>? predictions,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('cars').doc(carId).update({
        'lastScan': Timestamp.fromDate(scanTime),
        'lastScanErrors': errors ?? [],
        'lastScanPredictions': predictions ?? [],
      });
    } catch (e) {
      debugPrint('Failed to update last scan: $e');
    }
  }

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

  void _showScanTypeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Scan Type'),
          content: const Text('Select the type of scan you want to perform.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startRealTimeScan();
              },
              child: const Text('Real-Time Scan'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showMLScanSizeDialog();
              },
              child: const Text('ML Scan'),
            ),
          ],
        );
      },
    );
  }

  void _showMLScanSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int selectedSize = 20;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('ML Scan Size'),
              content: DropdownButton<int>(
                value: selectedSize,
                items:
                    [20, 40, 60, 80, 100]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v readings'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => selectedSize = v ?? 20),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _performMLScan(selectedSize);
                  },
                  child: const Text('Start ML Scan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _realTimeScanning = false;
  Timer? _realTimeTimer;

  void _startRealTimeScan() {
    if (!ObdConnectionManager().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OBD-II device connected.')),
      );
      return;
    }
    setState(() {
      _realTimeScanning = true;
    });
    _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _updateMetricsFromObd();
    });
  }

  Future<void> _updateMetricsFromObd() async {
    final connection = ObdConnectionManager().connection;
    if (connection == null || !connection.isConnected) return;
    final Map<String, String> pidMap = {
      'ENGINE_RUN_TIME': '011F',
      'ENGINE_RPM': '010C',
      'VEHICLE_SPEED': '010D',
      'THROTTLE': '0111',
      'ENGINE_LOAD': '0104',
      'COOLANT_TEMPERATURE': '0105',
      'LONG_TERM_FUEL_TRIM_BANK_1': '0107',
      'SHORT_TERM_FUEL_TRIM_BANK_1': '0106',
      'INTAKE_MANIFOLD_PRESSURE': '010B',
      'FUEL_TANK': '012F',
      'ABSOLUTE_THROTTLE_B': '014D',
      'PEDAL_D': '015A',
      'PEDAL_E': '015B',
      'COMMANDED_THROTTLE_ACTUATOR': '014C',
      'FUEL_AIR_COMMANDED_EQUIV_RATIO': '0134',
      'ABSOLUTE_BAROMETRIC_PRESSURE': '0133',
      'RELATIVE_THROTTLE_POSITION': '0145',
      'INTAKE_AIR_TEMP': '010F',
      'TIMING_ADVANCE': '010E',
      'CATALYST_TEMPERATURE_BANK1_SENSOR1': '013C',
      'CATALYST_TEMPERATURE_BANK1_SENSOR2': '013D',
      'CONTROL_MODULE_VOLTAGE': '0142',
      'COMMANDED_EVAPORATIVE_PURGE': '012E',
      'TIME_RUN_WITH_MIL_ON': '014D',
      'TIME_SINCE_TROUBLE_CODES_CLEARED': '014E',
      'DISTANCE_TRAVELED_WITH_MIL_ON': '0121',
    };
    for (final entry in pidMap.entries) {
      try {
        connection.output.add(utf8.encode('${entry.value}\r'));
        await connection.output.allSent;
        await Future.delayed(const Duration(milliseconds: 200));
        final response = await connection.input!.first;
        final value = _parseObdResponse(entry.key, response);
        setState(() {
          _metrics[entry.key] = value;
        });
      } catch (_) {
        // Ignore errors for now
      }
    }
  }

  double _parseObdResponse(String metric, List<int> response) {
    // Convert response to hex string
    String hex = response
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    List<String> bytes = hex.split(' ');
    // Find the data bytes (skip echo: 2 bytes)
    if (bytes.length < 3) return 0.0;
    // Most OBD-II responses: [41, PID, ...data]
    List<int> data =
        bytes.skip(2).map((b) => int.tryParse(b, radix: 16) ?? 0).toList();
    double value = 0.0;
    switch (metric) {
      case 'ENGINE_RUN_TIME': // 011F
      case 'TIME_RUN_WITH_MIL_ON': // 014D
      case 'TIME_SINCE_TROUBLE_CODES_CLEARED': // 014E
      case 'DISTANCE_TRAVELED_WITH_MIL_ON': // 0121
        if (data.length >= 2) value = (data[0] * 256 + data[1]).toDouble();
        break;
      case 'ENGINE_RPM': // 010C
        if (data.length >= 2) value = ((data[0] * 256) + data[1]) / 4.0;
        break;
      case 'VEHICLE_SPEED': // 010D
      case 'INTAKE_MANIFOLD_PRESSURE': // 010B
      case 'ABSOLUTE_BAROMETRIC_PRESSURE': // 0133
        if (data.isNotEmpty) value = data[0].toDouble();
        break;
      case 'THROTTLE': // 0111
      case 'ENGINE_LOAD': // 0104
      case 'FUEL_TANK': // 012F
      case 'ABSOLUTE_THROTTLE_B': // 014D
      case 'PEDAL_D': // 015A
      case 'PEDAL_E': // 015B
      case 'COMMANDED_THROTTLE_ACTUATOR': // 014C
      case 'RELATIVE_THROTTLE_POSITION': // 0145
      case 'COMMANDED_EVAPORATIVE_PURGE': // 012E
        if (data.isNotEmpty) value = (data[0] * 100.0) / 255.0;
        break;
      case 'COOLANT_TEMPERATURE': // 0105
      case 'INTAKE_AIR_TEMP': // 010F
        if (data.isNotEmpty) value = (data[0] - 40).toDouble();
        break;
      case 'LONG_TERM_FUEL_TRIM_BANK_1': // 0107
      case 'SHORT_TERM_FUEL_TRIM_BANK_1': // 0106
        if (data.isNotEmpty) value = ((data[0] - 128) * 100.0) / 128.0;
        break;
      case 'FUEL_AIR_COMMANDED_EQUIV_RATIO': // 0134
        if (data.length >= 2) value = ((data[0] * 256) + data[1]) / 32768.0;
        break;
      case 'TIMING_ADVANCE': // 010E
        if (data.isNotEmpty) value = (data[0] / 2.0) - 64.0;
        break;
      case 'CATALYST_TEMPERATURE_BANK1_SENSOR1': // 013C
      case 'CATALYST_TEMPERATURE_BANK1_SENSOR2': // 013D
        if (data.length >= 2) value = ((data[0] * 256) + data[1]) / 10.0;
        break;
      case 'CONTROL_MODULE_VOLTAGE': // 0142
        if (data.length >= 2) value = ((data[0] * 256) + data[1]) / 1000.0;
        break;
      default:
        value = 0.0;
    }
    // Normalize for progress bars (0.0-1.0) for most metrics
    switch (metric) {
      case 'ENGINE_RUN_TIME':
      case 'TIME_RUN_WITH_MIL_ON':
      case 'TIME_SINCE_TROUBLE_CODES_CLEARED':
      case 'DISTANCE_TRAVELED_WITH_MIL_ON':
        return (value / 600.0).clamp(0.0, 1.0); // e.g., 10 min max
      case 'ENGINE_RPM':
        return (value / 8000.0).clamp(0.0, 1.0); // 8000 RPM max
      case 'VEHICLE_SPEED':
        return (value / 240.0).clamp(0.0, 1.0); // 240 km/h max
      case 'THROTTLE':
      case 'ENGINE_LOAD':
      case 'FUEL_TANK':
      case 'ABSOLUTE_THROTTLE_B':
      case 'PEDAL_D':
      case 'PEDAL_E':
      case 'COMMANDED_THROTTLE_ACTUATOR':
      case 'RELATIVE_THROTTLE_POSITION':
      case 'COMMANDED_EVAPORATIVE_PURGE':
        return (value / 100.0).clamp(0.0, 1.0);
      case 'COOLANT_TEMPERATURE':
      case 'INTAKE_AIR_TEMP':
        return ((value + 40.0) / 215.0).clamp(0.0, 1.0); // -40 to 175C
      case 'LONG_TERM_FUEL_TRIM_BANK_1':
      case 'SHORT_TERM_FUEL_TRIM_BANK_1':
        return ((value + 100.0) / 200.0).clamp(0.0, 1.0); // -100 to +100
      case 'FUEL_AIR_COMMANDED_EQUIV_RATIO':
        return (value / 2.0).clamp(0.0, 1.0); // 0-2
      case 'TIMING_ADVANCE':
        return ((value + 64.0) / 128.0).clamp(0.0, 1.0); // -64 to +64
      case 'CATALYST_TEMPERATURE_BANK1_SENSOR1':
      case 'CATALYST_TEMPERATURE_BANK1_SENSOR2':
        return (value / 1200.0).clamp(0.0, 1.0); // up to 1200C
      case 'CONTROL_MODULE_VOLTAGE':
        return (value / 20.0).clamp(0.0, 1.0); // up to 20V
      default:
        return value;
    }
  }

  void _stopRealTimeScan() async {
    _realTimeTimer?.cancel();
    setState(() {
      _realTimeScanning = false;
    });

    final scanTime = DateTime.now();
    if (widget.carData != null && widget.carData!['id'] != null) {
      await _updateLastScanInFirestore(
        carId: widget.carData!['id'],
        scanTime: scanTime,
      );
    }
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Preconditions
    if (!widget.skipPreconditions && widget.carData == null) {
      return _buildPreconditionScreen(
        'Add a car to start scanning',
        Icons.directions_car,
      );
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
              child:
                  _carImageFile == null
                      ? Container(
                        color: Colors.black54,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: _pickCarImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                            ),
                            child: const Text('Add Car Image'),
                          ),
                        ),
                      )
                      : Image.file(_carImageFile!, fit: BoxFit.cover),
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
                      Text(
                        model,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        make,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  _realTimeScanning ? _buildRealTimeScan() : _buildLatestScan(),
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
            child:
                _realTimeScanning
                    ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _stopRealTimeScan,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Scan'),
                    )
                    : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _showScanTypeDialog,
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
              Text('$name:', style: const TextStyle(color: Colors.white70)),
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
                        '${(value * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
    // List the last 5 CSVs in the documents directory
    return FutureBuilder<List<_ScanRecord>>(
      future: _getScanHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(
            child: Text(
              'No scan history yet',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final rec = history[index];
            final formattedDate = DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(rec.date);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => OpenFile.open(rec.path),
                    child: const Text('Open'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_ScanRecord>> _getScanHistory() async {
    final dir = await getApplicationDocumentsDirectory();
    final allCsvs =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_scan.csv'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    return allCsvs
        .take(5)
        .map((f) => _ScanRecord(f.statSync().modified, f.path))
        .toList();
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

  Widget _buildRealTimeScan() {
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
              Text('$name:', style: const TextStyle(color: Colors.white70)),
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
                        '${(value * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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

  Future<void> _performMLScan(int scanSize) async {
    if (!ObdConnectionManager().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OBD-II device connected.')),
      );
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_ml_scan.csv";
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    final headers = _metrics.keys.toList();
    final csvContent = StringBuffer();
    csvContent.writeln(headers.join(','));
    List<List<String>> rows = [];
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _MLScanProgressDialog(total: scanSize);
      },
    );
    for (int i = 0; i < scanSize; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _updateMetricsFromObd();
      if (!mounted) return;
      rows.add(_metrics.values.map((v) => v.toString()).toList());
      // Update progress
      _MLScanProgressDialog.of(context)?.updateProgress(i + 1);
    }
    // Write CSV
    for (final row in rows) {
      csvContent.writeln(row.join(','));
    }
    await file.writeAsString(csvContent.toString());
    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog
    // Send to /check-current-errors and /predict-faults
    List<dynamic> errors = [];
    List<dynamic> predictions = [];
    try {
      // /check-current-errors
      final request1 = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/check-current-errors'),
      );
      request1.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse1 = await request1.send();
      if (!mounted) return;
      final response1 = await http.Response.fromStream(streamedResponse1);
      if (!mounted) return;
      if (response1.statusCode == 200) {
        final jsonResponse = json.decode(response1.body);
        errors = jsonResponse['errors'] ?? [];
      }
      // /predict-faults
      final request2 = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/predict-faults'),
      );
      request2.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse2 = await request2.send();
      if (!mounted) return;
      final response2 = await http.Response.fromStream(streamedResponse2);
      if (!mounted) return;
      if (response2.statusCode == 200) {
        final jsonResponse = json.decode(response2.body);
        predictions = jsonResponse['predictions'] ?? [];
      }
      final scanTime = DateTime.now();

      // Firestore update
      if (widget.carData != null && widget.carData!['id'] != null) {
        await _updateLastScanInFirestore(
          carId: widget.carData!['id'],
          scanTime: scanTime,
          errors: errors,
          predictions: predictions,
        );
      }

      // Navigate to results screen
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ErrorsScreen(
            errors: errors,
            predictions: predictions,
            showMLMessage: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to server: $e')),
      );
    }
  }
}

class _ScanRecord {
  final DateTime date;
  final String path;
  _ScanRecord(this.date, this.path);
}

// ML Scan Progress Dialog
class _MLScanProgressDialog extends StatefulWidget {
  final int total;
  const _MLScanProgressDialog({this.total = 20});
  static _MLScanProgressDialogState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MLScanProgressDialogState>();
  }

  @override
  _MLScanProgressDialogState createState() => _MLScanProgressDialogState();
}

class _MLScanProgressDialogState extends State<_MLScanProgressDialog> {
  int progress = 0;
  void updateProgress(int value) {
    setState(() {
      progress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ML Scan in Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Collecting data... $progress/${widget.total}'),
        ],
      ),
    );
  }
}
