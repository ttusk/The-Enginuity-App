import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:path/path.dart' as p;

import '../obd_connection_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'connect_screen.dart';

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
    'ENGINE_RPM': 0,
    'VEHICLE_SPEED': 0,
    'COOLANT_TEMPERATURE': 0,
    'ENGINE_LOAD': 0,
    'THROTTLE': 0,
    'INTAKE_AIR_TEMP': 0,
    'CONTROL_MODULE_VOLTAGE': 0,
    'LONG_TERM_FUEL_TRIM_BANK_1': 0,
    'SHORT_TERM_FUEL_TRIM_BANK_1': 0,
  };

  // Top 9 most common/meaningful OBD-II metrics
  static const List<String> _topMetrics = [
    'ENGINE_RPM',
    'VEHICLE_SPEED',
    'COOLANT_TEMPERATURE',
    'ENGINE_LOAD',
    'THROTTLE',
    'INTAKE_AIR_TEMP',
    'CONTROL_MODULE_VOLTAGE',
    'LONG_TERM_FUEL_TRIM_BANK_1',
    'SHORT_TERM_FUEL_TRIM_BANK_1',
  ];

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

  bool _realTimeScanning = false;
  Timer? _realTimeTimer;
  Timer? _rpmTimer;
  Timer? _csvTimer;
  bool _isCommandInProgress = false; // Prevent overlapping commands

  // Buffer for collecting readings
  final Map<String, List<double>> _readingBuffer = {};
  int _readingsCollected = 0;
  static const int _readingsPerRow = 9; // One reading for each metric

  void _startRealTimeScan() {
    if (!ObdConnectionManager().isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OBD-II device connected.')),
      );
      return;
    }
    setState(() {
      _realTimeScanning = true;
      _readingsCollected = 0;
      _readingBuffer.clear();
      // Initialize buffer for each metric
      for (String metric in _topMetrics) {
        _readingBuffer[metric] = [];
      }
    });
    // Poll all metrics except RPM every 5 seconds
    _realTimeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _updateMetricsFromObd(excludeRpm: true);
    });
    // Poll RPM every second
    _rpmTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _updateRpmFromObd();
    });
    // Generate CSV every 10 minutes
    _csvTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await _generateCsvFile();
    });
  }

  Future<void> _updateRpmFromObd() async {
    // Check if another command is in progress
    if (_isCommandInProgress) {
      debugPrint('⏳ SCAN: RPM update skipped - another command in progress');
      return;
    }

    // Check connection health
    if (!_checkConnectionHealth()) {
      debugPrint('⚠️ SCAN: RPM update skipped - connection unhealthy');
      return;
    }

    _isCommandInProgress = true;

    try {
      debugPrint('📤 SCAN: Sending PID: ENGINE_RPM (code: 010C)');

      // Clear any pending responses before sending new command
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Shorter delay for RPM

      // Add timeout to prevent hanging
      final response = await ObdConnectionManager()
          .sendObdCommand('010C')
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              // Shorter timeout for RPM
              debugPrint('⏰ SCAN: RPM command timeout');
              throw TimeoutException('RPM command timeout');
            },
          );

      String responseStr = String.fromCharCodes(response);

      debugPrint('📥 SCAN: Raw RPM response: "$responseStr"');

      if (!responseStr.trim().endsWith('>')) {
        debugPrint('⏳ SCAN: Incomplete RPM response, skipping update');
        return;
      }

      List<String> lines = responseStr.split(RegExp(r'[\r\n]+'));
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty ||
            line.contains('NO DATA') ||
            line.contains('STOPPED') ||
            line.startsWith('7F') ||
            line == '>') {
          continue;
        }
        if (line.endsWith('>')) line = line.substring(0, line.length - 1);
        if (line.startsWith('410C')) {
          double value = _parseObdResponseFromLine('ENGINE_RPM', line, '0C');
          debugPrint('✅ SCAN: ENGINE_RPM - Parsed: $value from line: "$line"');
          setState(() {
            _metrics['ENGINE_RPM'] = value;
          });

          // Add to buffer for CSV generation
          if (_realTimeScanning && _readingBuffer.containsKey('ENGINE_RPM')) {
            _readingBuffer['ENGINE_RPM']!.add(value);
            _readingsCollected++;

            // Check if we have collected all 9 readings
            if (_readingsCollected >= _readingsPerRow) {
              await _addRowToCsvBuffer();
              _readingsCollected = 0;
            }
          }

          return; // Exit after finding valid RPM data
        }
      }
      debugPrint(
        '⚠️ SCAN: No valid RPM data found in response: "$responseStr"',
      );
    } catch (e) {
      debugPrint('❌ SCAN: Error reading PID ENGINE_RPM: $e');
    } finally {
      _isCommandInProgress = false;
    }
  }

  Future<void> _updateMetricsFromObd({bool excludeRpm = false}) async {
    // Check connection health
    if (!_checkConnectionHealth()) {
      debugPrint('⚠️ SCAN: Metric update cycle skipped - connection unhealthy');
      return;
    }

    debugPrint('🔄 SCAN: Starting metric update cycle...');

    final Map<String, String> pidMap = {
      'VEHICLE_SPEED': '010D',
      'COOLANT_TEMPERATURE': '0105',
      'ENGINE_LOAD': '0104',
      'THROTTLE': '0111',
      'INTAKE_AIR_TEMP': '010F',
      'CONTROL_MODULE_VOLTAGE': '0142',
      'LONG_TERM_FUEL_TRIM_BANK_1': '0107',
      'SHORT_TERM_FUEL_TRIM_BANK_1': '0106',
    };

    for (final entry in pidMap.entries) {
      // Check connection health before each command
      if (!_checkConnectionHealth()) {
        debugPrint('⚠️ SCAN: Stopping metric cycle - connection lost');
        break;
      }

      // Check if another command is in progress (allow RPM to interrupt)
      if (_isCommandInProgress) {
        debugPrint(
          '⏳ SCAN: Skipping ${entry.key} - another command in progress',
        );
        continue;
      }

      _isCommandInProgress = true;

      try {
        debugPrint('📤 SCAN: Sending PID: ${entry.key} (code: ${entry.value})');

        // Clear any pending responses before sending new command
        await Future.delayed(
          const Duration(milliseconds: 150),
        ); // Shorter delay

        // Add timeout to prevent hanging
        final response = await ObdConnectionManager()
            .sendObdCommand(entry.value)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                // Shorter timeout
                debugPrint('⏰ SCAN: ${entry.key} command timeout');
                throw TimeoutException('${entry.key} command timeout');
              },
            );

        String responseStr = String.fromCharCodes(response);
        String responseHex = response
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');

        debugPrint('📥 SCAN: Raw response for ${entry.key}: "$responseStr"');
        debugPrint('📥 SCAN: Hex response for ${entry.key}: $responseHex');

        if (!responseStr.trim().endsWith('>')) {
          debugPrint(
            '⏳ SCAN: Incomplete response, skipping update for ${entry.key}',
          );
          continue;
        }

        // Parse the response
        double? parsedValue = _parseObdResponse(
          entry.key,
          responseStr,
          entry.value,
        );

        if (parsedValue != null) {
          debugPrint('✅ SCAN: ${entry.key} - Parsed: $parsedValue');
          setState(() {
            _metrics[entry.key] = parsedValue;
          });

          // Add to buffer for CSV generation
          if (_realTimeScanning && _readingBuffer.containsKey(entry.key)) {
            _readingBuffer[entry.key]!.add(parsedValue);
            _readingsCollected++;

            // Check if we have collected all 9 readings
            if (_readingsCollected >= _readingsPerRow) {
              await _addRowToCsvBuffer();
              _readingsCollected = 0;
            }
          }
        } else {
          debugPrint(
            '⚠️ SCAN: No valid data found for ${entry.key}, keeping previous value: ${_metrics[entry.key]}',
          );
        }
      } catch (e) {
        debugPrint('❌ SCAN: Error reading PID ${entry.key}: $e');
      } finally {
        _isCommandInProgress = false;
      }

      // Shorter delay between requests
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('✅ SCAN: Metric update cycle completed');
  }

  double? _parseObdResponse(String metric, String responseStr, String pidCode) {
    List<String> lines = responseStr.split(RegExp(r'[\r\n]+'));
    String expectedHeader = '41${pidCode.substring(2, 4).toUpperCase()}';

    debugPrint(
      '🔍 SCAN: Looking for header "$expectedHeader" in response for $metric',
    );

    for (String line in lines) {
      line = line.trim();

      // Skip error responses and empty lines
      if (line.isEmpty ||
          line.contains('NO DATA') ||
          line.contains('STOPPED') ||
          line.startsWith('7F') ||
          line == '>') {
        continue;
      }

      // Remove trailing '>' if present
      if (line.endsWith('>')) {
        line = line.substring(0, line.length - 1);
      }

      debugPrint(
        '🔍 SCAN: Checking line: "$line" for header "$expectedHeader"',
      );

      // Check if this line contains the expected response for this PID
      if (line.startsWith(expectedHeader)) {
        String pid = pidCode.substring(2, 4).toUpperCase();
        double value = _parseObdResponseFromLine(metric, line, pid);
        debugPrint(
          '✅ SCAN: Found valid response for $metric: "$line" -> $value',
        );
        return value;
      }
    }

    debugPrint(
      '❌ SCAN: No valid response found for $metric with header $expectedHeader',
    );
    return null; // No valid response found
  }

  double _parseObdResponseFromLine(String metric, String line, String pid) {
    // Remove header (e.g., 410C) and split into hex bytes
    String dataHex = line.substring(4); // after 41XX
    List<String> hexBytes = [];
    for (int i = 0; i < dataHex.length; i += 2) {
      if (i + 2 <= dataHex.length) {
        hexBytes.add(dataHex.substring(i, i + 2));
      }
    }
    if (hexBytes.isEmpty) return 0.0;
    List<int> data =
        hexBytes.map((b) => int.tryParse(b, radix: 16) ?? 0).toList();
    double value = 0.0;
    switch (metric) {
      case 'ENGINE_RPM':
        if (data.length >= 2) {
          value = ((data[0] * 256) + data[1]) / 4.0;
        }
        break;
      case 'VEHICLE_SPEED':
        if (data.isNotEmpty) {
          value = data[0].toDouble();
        }
        break;
      case 'COOLANT_TEMPERATURE':
        if (data.isNotEmpty) {
          value = (data[0] - 40).toDouble();
        }
        break;
      case 'ENGINE_LOAD':
        if (data.isNotEmpty) {
          value = (data[0] * 100.0) / 255.0;
        }
        break;
      case 'THROTTLE':
        if (data.isNotEmpty) {
          value = (data[0] * 100.0) / 255.0;
        }
        break;
      case 'INTAKE_AIR_TEMP':
        if (data.isNotEmpty) {
          value = (data[0] - 40).toDouble();
        }
        break;
      case 'CONTROL_MODULE_VOLTAGE':
        if (data.length >= 2) {
          value = ((data[0] * 256) + data[1]) / 1000.0;
        }
        break;
      case 'LONG_TERM_FUEL_TRIM_BANK_1':
        if (data.isNotEmpty) {
          value = ((data[0] - 128) * 100.0) / 128.0;
        }
        break;
      case 'SHORT_TERM_FUEL_TRIM_BANK_1':
        if (data.isNotEmpty) {
          value = ((data[0] - 128) * 100.0) / 128.0;
        }
        break;
      default:
        value = 0.0;
    }
    return value;
  }

  void _stopRealTimeScan() async {
    _realTimeTimer?.cancel();
    _rpmTimer?.cancel();
    _csvTimer?.cancel();
    _isCommandInProgress = false; // Reset command flag

    // Generate final CSV before stopping
    await _generateCsvFile();

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

  bool _checkConnectionHealth() {
    final connection = ObdConnectionManager().connection;
    if (connection == null || !connection.isConnected) {
      debugPrint('⚠️ SCAN: Connection health check failed - not connected');
      return false;
    }
    return true;
  }

  // CSV buffer for collecting data
  final List<List<String>> _csvBuffer = [];

  Future<void> _addRowToCsvBuffer() async {
    List<String> row = [];
    for (String metric in _topMetrics) {
      if (_readingBuffer[metric]!.isNotEmpty) {
        row.add(_readingBuffer[metric]!.last.toString());
      } else {
        row.add('0.0'); // Default value if no reading
      }
    }
    _csvBuffer.add(row);
    debugPrint('📊 SCAN: Added row to CSV buffer: $row');
  }

  Future<void> _generateCsvFile() async {
    if (_csvBuffer.isEmpty) {
      debugPrint('⚠️ SCAN: No data to write to CSV');
      return;
    }

    try {
      // Check storage permissions before trying to write to public directory
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      // On Android 11+ (API 30+), only MANAGE_EXTERNAL_STORAGE is needed
      // On older versions, STORAGE permission is needed
      if (manageStorageStatus.isGranted) {
        debugPrint('✅ Manage external storage permission granted');
      } else if (storageStatus.isGranted) {
        debugPrint('✅ Storage permission granted');
      } else {
        debugPrint(
          '⚠️ Storage permissions not granted, using fallback to private directory',
        );
        throw Exception('Storage permissions not granted');
      }

      final enginuityDir = Directory('/storage/emulated/0/Enginuity');
      if (!await enginuityDir.exists()) {
        await enginuityDir.create(recursive: true);
        debugPrint('📁 Created Enginuity folder for CSV storage');
      }

      final fileName =
          "${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_monitoring.csv";
      final filePath = p.join(enginuityDir.path, fileName);
      final file = File(filePath);

      final csvContent = StringBuffer();
      csvContent.writeln(_topMetrics.join(','));

      for (final row in _csvBuffer) {
        csvContent.writeln(row.join(','));
      }

      await file.writeAsString(csvContent.toString());
      debugPrint(
        '✅ SCAN: Generated CSV file: $filePath with ${_csvBuffer.length} rows',
      );

      // Clear buffer after writing
      _csvBuffer.clear();
      for (String metric in _topMetrics) {
        _readingBuffer[metric]!.clear();
      }
    } catch (e) {
      debugPrint('❌ SCAN: Failed to generate CSV file: $e');
      // Fallback to private directory if public directory fails
      try {
        final dir = await getApplicationDocumentsDirectory();
        final fileName =
            "${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_monitoring.csv";
        final filePath = p.join(dir.path, fileName);
        final file = File(filePath);

        final csvContent = StringBuffer();
        csvContent.writeln(_topMetrics.join(','));

        for (final row in _csvBuffer) {
          csvContent.writeln(row.join(','));
        }

        await file.writeAsString(csvContent.toString());
        debugPrint(
          '✅ SCAN: Generated CSV file (fallback): $filePath with ${_csvBuffer.length} rows',
        );

        // Clear buffer after writing
        _csvBuffer.clear();
        for (String metric in _topMetrics) {
          _readingBuffer[metric]!.clear();
        }
      } catch (fallbackError) {
        debugPrint(
          '❌ SCAN: Fallback CSV generation also failed: $fallbackError',
        );
      }
    }
  }

  @override
  void dispose() {
    _realTimeTimer?.cancel();
    _rpmTimer?.cancel();
    _csvTimer?.cancel();
    _isCommandInProgress = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'ScanScreen: ObdConnectionManager().isConnected = ${ObdConnectionManager().isConnected}',
    );
    // Preconditions - only check for car data
    if (!widget.skipPreconditions && widget.carData == null) {
      return _buildPreconditionScreen(
        'Add a car to start scanning',
        Icons.directions_car,
      );
    }
    final make = widget.carData?['make'] ?? '';
    final model = widget.carData?['model'] ?? '';
    final bool isDeviceConnected = ObdConnectionManager().isConnected;
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
                      label: const Text('Stop Monitoring'),
                    )
                    : !isDeviceConnected
                    ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ConnectScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Connect Device'),
                    )
                    : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _startRealTimeScan,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Monitoring'),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestScan() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children:
          _topMetrics.map((metric) {
            final value = _metrics[metric] ?? 0.0;
            return Card(
              color: const Color(0xFF12303B),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _prettyMetricName(metric),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatMetric(metric, value),
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
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
    List<File> allCsvs = [];

    // Try to read from public Enginuity directory first
    try {
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      if (manageStorageStatus.isGranted || storageStatus.isGranted) {
        final enginuityDir = Directory('/storage/emulated/0/Enginuity');
        if (await enginuityDir.exists()) {
          allCsvs =
              enginuityDir
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.endsWith('_monitoring.csv'))
                  .toList()
                ..sort(
                  (a, b) =>
                      b.statSync().modified.compareTo(a.statSync().modified),
                );
          debugPrint(
            '📁 Found ${allCsvs.length} CSV files in public directory for history',
          );
        }
      } else {
        debugPrint(
          '⚠️ Storage permissions not granted, checking private directory for history',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to read from public directory for history: $e');
    }

    // Fallback to private directory if public directory is empty or fails
    if (allCsvs.isEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        allCsvs =
            dir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('_monitoring.csv'))
                .toList()
              ..sort(
                (a, b) =>
                    b.statSync().modified.compareTo(a.statSync().modified),
              );
        debugPrint(
          '📁 Found ${allCsvs.length} CSV files in private directory for history',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to read from private directory for history: $e');
      }
    }

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children:
          _topMetrics.map((metric) {
            final value = _metrics[metric] ?? 0.0;
            return Card(
              color: const Color(0xFF12303B),
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _prettyMetricName(metric),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatMetric(metric, value),
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  // Helper to format metric values with units
  String _formatMetric(String key, double value) {
    switch (key) {
      case 'ENGINE_RPM':
        return '${value.toStringAsFixed(0)} rpm';
      case 'VEHICLE_SPEED':
        return '${value.toStringAsFixed(0)} km/h';
      case 'COOLANT_TEMPERATURE':
        return '${value.toStringAsFixed(1)} °C';
      case 'ENGINE_LOAD':
        return '${value.toStringAsFixed(1)} %';
      case 'THROTTLE':
        return '${value.toStringAsFixed(1)} %';
      case 'INTAKE_AIR_TEMP':
        return '${value.toStringAsFixed(1)} °C';
      case 'CONTROL_MODULE_VOLTAGE':
        return '${value.toStringAsFixed(2)} V';
      case 'LONG_TERM_FUEL_TRIM_BANK_1':
        return '${value.toStringAsFixed(1)} %';
      case 'SHORT_TERM_FUEL_TRIM_BANK_1':
        return '${value.toStringAsFixed(1)} %';
      default:
        return value.toStringAsFixed(2);
    }
  }

  // Helper to prettify metric names
  String _prettyMetricName(String key) {
    switch (key) {
      case 'ENGINE_RPM':
        return 'Engine RPM';
      case 'VEHICLE_SPEED':
        return 'Vehicle Speed';
      case 'COOLANT_TEMPERATURE':
        return 'Coolant Temp';
      case 'ENGINE_LOAD':
        return 'Engine Load';
      case 'THROTTLE':
        return 'Throttle Position';
      case 'INTAKE_AIR_TEMP':
        return 'Intake Air Temp';
      case 'CONTROL_MODULE_VOLTAGE':
        return 'Module Voltage';
      case 'LONG_TERM_FUEL_TRIM_BANK_1':
        return 'Long Term Fuel Trim';
      case 'SHORT_TERM_FUEL_TRIM_BANK_1':
        return 'Short Term Fuel Trim';
      default:
        return key;
    }
  }
}

class _ScanRecord {
  final DateTime date;
  final String path;
  _ScanRecord(this.date, this.path);
}
