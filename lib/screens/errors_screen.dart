import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'home.dart';

class ErrorsScreen extends StatefulWidget {
  const ErrorsScreen({super.key});

  @override
  State<ErrorsScreen> createState() => _ErrorsScreenState();
}

class _ErrorsScreenState extends State<ErrorsScreen> {
  List<dynamic> errors = [];
  List<dynamic> predictions = [];
  bool isLoading = true;
  bool hasCsvFiles = false;

  @override
  void initState() {
    super.initState();
    _loadLatestCsvData();
  }

  Future<void> _loadLatestCsvData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final allCsvs = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_monitoring.csv'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

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
        final request1 = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:5000/predict-faults'),
        );
        request1.files.add(await http.MultipartFile.fromPath('file', latestCsv.path));
        final streamedResponse1 = await request1.send();
        final response1 = await http.Response.fromStream(streamedResponse1);
        
        if (response1.statusCode == 200) {
          final jsonResponse = json.decode(response1.body);
          setState(() {
            predictions = jsonResponse['predictions'] ?? [];
          });
        }
      } catch (e) {
        debugPrint('Error getting predictions: $e');
      }

      // Send to check errors endpoint
      try {
        final request2 = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:5000/check-current-errors'),
        );
        request2.files.add(await http.MultipartFile.fromPath('file', latestCsv.path));
        final streamedResponse2 = await request2.send();
        final response2 = await http.Response.fromStream(streamedResponse2);
        
        if (response2.statusCode == 200) {
          final jsonResponse = json.decode(response2.body);
          setState(() {
            errors = jsonResponse['errors'] ?? [];
          });
        }
      } catch (e) {
        debugPrint('Error getting errors: $e');
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
            Container(
              width: double.infinity,
              height: 180,
              color: Colors.black54,
              child: const Icon(
                Icons.directions_car,
                color: Colors.white70,
                size: 100,
              ),
            ),
            Container(
              color: const Color(0xFF12303B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZS',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        'MG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.search, color: Colors.white70),
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
                  hasCsvFiles
                      ? _buildErrorList(errors)
                      : _buildMLMessage(),
                  hasCsvFiles
                      ? _buildErrorList(predictions)
                      : _buildMLMessage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildErrorList(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No items found', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index].toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                onPressed: () {},
                child: const Text('FIX'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMLMessage() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
        'No predictions available',
        style: TextStyle(color: Colors.white54, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
