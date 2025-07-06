import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import 'home.dart';

class ErrorsScreen extends StatefulWidget {
  final Map<String, dynamic>? carData;
  
  const ErrorsScreen({super.key, this.carData});

  @override
  State<ErrorsScreen> createState() => _ErrorsScreenState();
}

class _ErrorsScreenState extends State<ErrorsScreen> {
  List<dynamic> errors = [];
  List<dynamic> predictions = [];
  bool isLoading = true;
  bool hasCsvFiles = false;
  String? errorStatus;
  String? predictionStatus;
  Map<String, dynamic>? errorSummary;
  Map<String, dynamic>? predictionSummary;

  @override
  void initState() {
    super.initState();
    _loadLatestCsvData();
  }

  Future<void> _loadLatestCsvData() async {
    try {
      // Try to read from public Engineuity directory first
      List<File> allCsvs = [];

      try {
        // Check storage permissions before trying to read from public directory
        final storageStatus = await Permission.storage.status;
        final manageStorageStatus =
            await Permission.manageExternalStorage.status;

        // On Android 11+ (API 30+), only MANAGE_EXTERNAL_STORAGE is needed
        // On older versions, STORAGE permission is needed
        if (manageStorageStatus.isGranted || storageStatus.isGranted) {
          final engineuityDir = Directory('/storage/emulated/0/Engineuity');
          if (await engineuityDir.exists()) {
            allCsvs =
                engineuityDir
                    .listSync()
                    .whereType<File>()
                    .where((f) => f.path.endsWith('_monitoring.csv'))
                    .toList()
                  ..sort(
                    (a, b) =>
                        b.statSync().modified.compareTo(a.statSync().modified),
                  );
            debugPrint(
              '📁 Found ${allCsvs.length} CSV files in public directory',
            );
          }
        } else {
          debugPrint(
            '⚠️ Storage permissions not granted, skipping public directory',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to read from public directory: $e');
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
            '📁 Found ${allCsvs.length} CSV files in private directory',
          );
        } catch (e) {
          debugPrint('⚠️ Failed to read from private directory: $e');
        }
      }

      if (allCsvs.isEmpty) {
        setState(() {
          hasCsvFiles = false;
          isLoading = false;
        });
        return;
      }

      setState(() {
        hasCsvFiles = true;
      });

      final latestCsv = allCsvs.first;

      // Send to prediction endpoint
      try {
        debugPrint('📤 Sending CSV to prediction endpoint...');
        final request1 = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.1.102:5000/predict-faults'),
        );
        request1.files.add(
          await http.MultipartFile.fromPath('file', latestCsv.path),
        );
        debugPrint('📤 Request sent, waiting for response...');
        final streamedResponse1 = await request1.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⏰ Prediction request timed out');
            throw TimeoutException('Prediction request timed out');
          },
        );
        final response1 = await http.Response.fromStream(streamedResponse1);
        debugPrint('📥 Prediction response status: ${response1.statusCode}');
        debugPrint('📥 Prediction response body: ${response1.body}');

        if (response1.statusCode == 200) {
          final jsonResponse = json.decode(response1.body);
          setState(() {
            predictions = jsonResponse['predictions'] ?? [];
            predictionStatus = jsonResponse['status'];
            predictionSummary = jsonResponse['summary'];
          });
          debugPrint('✅ Predictions loaded: ${predictions.length} items');
        } else {
          debugPrint(
            '❌ Prediction request failed with status: ${response1.statusCode}',
          );
        }
      } catch (e) {
        debugPrint('❌ Error getting predictions: $e');
      }

      // Send to check errors endpoint
      try {
        debugPrint('📤 Sending CSV to errors endpoint...');
        final request2 = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.1.102:5000/check-current-errors'),
        );
        request2.files.add(
          await http.MultipartFile.fromPath('file', latestCsv.path),
        );
        debugPrint('📤 Request sent, waiting for response...');
        final streamedResponse2 = await request2.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⏰ Errors request timed out');
            throw TimeoutException('Errors request timed out');
          },
        );
        final response2 = await http.Response.fromStream(streamedResponse2);
        debugPrint('📥 Errors response status: ${response2.statusCode}');
        debugPrint('📥 Errors response body: ${response2.body}');

        if (response2.statusCode == 200) {
          final jsonResponse = json.decode(response2.body);
          setState(() {
            errors = jsonResponse['errors'] ?? [];
            errorStatus = jsonResponse['status'];
            errorSummary = jsonResponse['summary'];
          });
          debugPrint('✅ Errors loaded: ${errors.length} items');
        } else {
          debugPrint(
            '❌ Errors request failed with status: ${response2.statusCode}',
          );
        }
      } catch (e) {
        debugPrint('❌ Error getting errors: $e');
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading CSV data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1F26),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ),
        body: Column(
          children: [
            // Car image placeholder
            SizedBox(
              width: double.infinity,
              height: 180,
              child: widget.carData?['imageUrl'] != null
                  ? Image.network(
                      widget.carData!['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(
                            Icons.directions_car,
                            color: Colors.white70,
                            size: 100,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(
                          Icons.directions_car,
                          color: Colors.white70,
                          size: 100,
                        ),
                      ),
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
                      Text(
                        widget.carData?['model'] ?? 'Unknown Model',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        widget.carData?['make'] ?? 'Unknown Make',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.build, color: Colors.white70),
                ],
              ),
            ),
            const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(child: Text('Errors')),
                Tab(child: Text('Predicted Errors')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  hasCsvFiles ? _buildErrorsTab() : _buildMLMessage(),
                  hasCsvFiles ? _buildPredictionsTab() : _buildMLMessage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errors.isEmpty) {
      return const Center(
        child: Text(
          'No current errors detected',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Status and Summary Card
        if (errorStatus != null || errorSummary != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(errorStatus),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorStatus != null)
                  Text(
                    'Status: ${errorStatus!.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (errorSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Critical: ${errorSummary!['critical_faults'] ?? 0} | '
                    'Warnings: ${errorSummary!['warning_faults'] ?? 0} | '
                    'Total: ${errorSummary!['total_faults'] ?? 0}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        // Errors List
        ...errors.expand((errorGroup) {
          final faults = errorGroup['faults'] as List<dynamic>? ?? [];
          return faults.map((fault) => _buildFaultCard(fault, 'error'));
        }),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (predictions.isEmpty) {
      return const Center(
        child: Text(
          'No predictions available',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Status and Summary Card
        if (predictionStatus != null || predictionSummary != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(predictionStatus),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (predictionStatus != null)
                  Text(
                    'Status: ${predictionStatus!.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (predictionSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Fault Predictions: ${predictionSummary!['fault_predictions'] ?? 0} | '
                    'Fault %: ${(predictionSummary!['fault_percentage'] ?? 0).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        // Predictions List - Show only predictions with actual faults or high probability
        ...predictions
            .where((prediction) {
              final probability = prediction['probability'] as double? ?? 0.0;
              final actualFault =
                  prediction['actual_future_fault'] as bool? ?? false;
              final severity = prediction['severity'] as String? ?? 'success';
              return actualFault || probability > 0.5 || severity != 'success';
            })
            .map((prediction) => _buildPredictionCard(prediction)),
      ],
    );
  }

  Widget _buildFaultCard(Map<String, dynamic> fault, String type) {
    final severity = fault['severity'] as String? ?? 'info';
    final message = fault['message'] as String? ?? 'Unknown fault';
    final suggestion = fault['suggestion'] as String? ?? '';
    final metric = fault['metric'] as String? ?? '';
    final value = (fault['value'] as num?)?.toDouble() ?? 0.0;
    final threshold = (fault['threshold'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12303B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getSeverityColor(severity), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSeverityIcon(severity),
                color: _getSeverityColor(severity),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (metric.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Metric: $metric (Value: $value, Threshold: $threshold)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final severity = prediction['severity'] as String? ?? 'success';
    final predictionText =
        prediction['prediction'] as String? ?? 'No prediction';
    final suggestion = prediction['suggestion'] as String? ?? '';
    final probability = prediction['probability'] as double? ?? 0.0;
    final faultType = prediction['predicted_fault_type'] as String? ?? '';
    final actualFault = prediction['actual_future_fault'] as bool? ?? false;
    final detectedFaults =
        prediction['detected_faults'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12303B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getSeverityColor(severity), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSeverityIcon(severity),
                color: _getSeverityColor(severity),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  predictionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(probability * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (faultType.isNotEmpty &&
              faultType != "No specific fault predicted") ...[
            const SizedBox(height: 8),
            Text(
              'Predicted Fault: $faultType',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (actualFault && detectedFaults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Detected Faults:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...detectedFaults
                .take(5)
                .map(
                  (fault) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      '• $fault',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            if (detectedFaults.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  '... and ${detectedFaults.length - 5} more',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'healthy':
        return Colors.green;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  Widget _buildMLMessage() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasCsvFiles) {
      return const Center(
        child: Text(
          'Please scan first',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const Center(
      child: Text(
        'No data available',
        style: TextStyle(color: Colors.white54, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
