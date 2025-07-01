import 'package:flutter/material.dart';
import 'home.dart';

class ErrorsScreen extends StatelessWidget {
  final List<dynamic> errors;
  final List<dynamic> predictions;
  final bool showMLMessage;

  const ErrorsScreen({Key? key, required this.errors, required this.predictions, this.showMLMessage = false}) : super(key: key);

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
              child: const Icon(Icons.directions_car, color: Colors.white70, size: 100),
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
                      Text('ZS', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      Text('MG', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                  _buildErrorList(errors),
                  showMLMessage
                      ? _buildMLMessage()
                      : _buildErrorList(predictions),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

  static Widget _buildMLMessage() {
    return const Center(
      child: Text(
        'Run an ML Scan to see predictions.',
        style: TextStyle(color: Colors.white54, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
} 