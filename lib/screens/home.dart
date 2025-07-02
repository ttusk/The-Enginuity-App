import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';
import 'add_car_screen.dart';
import 'connect_screen.dart';
import 'scan_screen.dart';
import 'errors_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.checkAndNotify(); // Call your notification checker here
  }




  int _selectedIndex = 0;

void _onItemTapped(int index) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final carsColl = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('cars');
  final carsSnapshot = await carsColl.get();
  final hasCars = carsSnapshot.docs.isNotEmpty;

  if ((index == 1 || index == 2 || index == 3) && !hasCars) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a car to access this feature.')),
    );
    return;
  }

  if (index == 1) {
    // Load last_errors.json from documents directory
    List<dynamic> errors = [];
    List<dynamic> predictions = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'last_errors.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonData = json.decode(content);
        errors = jsonData['errors'] ?? [];
        predictions = jsonData['predictions'] ?? [];
      }
    } catch (_) {}
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ErrorsScreen(
          errors: errors,
          predictions: predictions,
        ),
      ),
    );
    setState(() => _selectedIndex = 0); // Return to home after errors screen
  } else if (index == 2) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanScreen(carData: null, deviceConnected: false)),
    );
    setState(() => _selectedIndex = 0); // Return to home after scan
  } else if (index == 3) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
    setState(() => _selectedIndex = 0); // Return to home after connect
  } else {
    setState(() => _selectedIndex = index);
  }
}

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/start-screen');
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final carsColl = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cars')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F26),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'logout') _logout();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'logout', child: Text('Logout')),
                    ],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 22,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Loading...',
                                style: TextStyle(color: Colors.white));
                          } else if (snapshot.hasError ||
                              !snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return const Text('Hey there!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold));
                          } else {
                            final fullName = snapshot.data!.get('fullName') ?? 'there';
                            return Text('Hey, $fullName!',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold));
                          }
                        },
                      ),
                      const SizedBox(height: 2),
                      const Text('Welcome',
                          style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('My Cars',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: carsColl.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No Cars Added',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        color: const Color(0xFF22313F),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: data['imageUrl'] != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                              : const Icon(Icons.directions_car,
                              color: Colors.white),
                          title: Text('${data['make']} ${data['model']}',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Mileage: ${data['mileage']} miles\n'
                                'Last Service: ${data['lastServiceDate'] != null ? (data['lastServiceDate'] as Timestamp).toDate().toString().split(" ")[0] : 'N/A'}\n'
                                'Last Scan: ${data['lastScan'] != null ? (data['lastScan'] as Timestamp).toDate().toString().split(" ")[0] : 'N/A'}',
                            style: const TextStyle(color: Colors.white70),
                          ),



                          isThreeLine: true,
                          trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Car"),
                              content: const Text("Are you sure you want to delete this car?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await doc.reference.delete();
                          }
                        },
                      ),

                      ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C4D54),
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AddCarScreen()));
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0A1F26),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.share), label: ''),
        ],
      ),

    );
  }
}






