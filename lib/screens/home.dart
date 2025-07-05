import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';
import 'add_car_screen.dart';
import 'connect_screen.dart';
import 'scan_screen.dart';
import 'errors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _selectedCarData; // Track selected car
  String? _selectedCarId;
  @override
  void initState() {
    super.initState();
    NotificationService.checkAndNotify(); // Check for maintenance reminders
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final carsColl = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cars');
    final carsSnapshot = await carsColl.get();
    if (!mounted) return;
    final hasCars = carsSnapshot.docs.isNotEmpty;

    if ((index == 1 || index == 2 || index == 3) && !hasCars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a car to access this feature.')),
      );
      return;
    }

    if (index == 1) {
      // Navigate to errors screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ErrorsScreen()),
      );
      if (!mounted) return;
      setState(() => _selectedIndex = 0); // Return to home after errors screen
    } else if (index == 2) {
      // Use selected car for scan
      if (_selectedCarData == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Select a car first.')));
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  ScanScreen(carData: _selectedCarData, deviceConnected: false),
        ),
      );
      if (!mounted) return;
      setState(() => _selectedIndex = 0); // Return to home after scan
    } else if (index == 3) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
      );
      if (!mounted) return;
      setState(() => _selectedIndex = 0); // Return to home after connect
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/start-screen',
      (route) => false,
    );
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8,
              ),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'logout') _logout();
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(value: 'logout', child: Text('Logout')),
                        ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                        future:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text(
                              'Loading...',
                              style: TextStyle(color: Colors.white),
                            );
                          } else if (snapshot.hasError ||
                              !snapshot.hasData ||
                              !snapshot.data!.exists) {
                            return const Text(
                              'Hey there!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          } else {
                            final fullName =
                                snapshot.data!.get('fullName') ?? 'there';
                            return Text(
                              'Hey, $fullName!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Welcome',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // App branding section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF12303B), Color(0xFF1E3A42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/engine_logo_2.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENGINUITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Vehicle Diagnostics & Monitoring',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'My Cars',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: carsColl.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No Cars Added',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isSelected = doc.id == _selectedCarId;
                      return Card(
                        color:
                            isSelected
                                ? Colors.blueGrey
                                : const Color(0xFF12303B),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading:
                              data['imageUrl'] != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data['imageUrl'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.directions_car,
                                    color: Colors.white,
                                  ),
                          title: Text(
                            '${data['make']} ${data['model']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Mileage: ${data['mileage']} miles\n'
                            'Last Service: ${data['lastServiceDate'] != null ? DateTime.fromMillisecondsSinceEpoch((data['lastServiceDate'] as Timestamp).millisecondsSinceEpoch).toString().split(" ")[0] : 'N/A'}\n'
                            'Last Scan: ${data['lastScan'] != null ? DateTime.fromMillisecondsSinceEpoch((data['lastScan'] as Timestamp).millisecondsSinceEpoch).toString().split(" ")[0] : 'N/A'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text("Delete Car"),
                                      content: const Text(
                                        "Are you sure you want to delete this car?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirm == true) {
                                await doc.reference.delete();
                                if (_selectedCarId == doc.id) {
                                  setState(() {
                                    _selectedCarId = null;
                                    _selectedCarData = null;
                                  });
                                }
                              }
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCarId = doc.id;
                              _selectedCarData = {...data, 'id': doc.id};
                            });
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ScanScreen(
                                      carData: {...data, 'id': doc.id},
                                      deviceConnected: false,
                                    ),
                              ),
                            );
                          },
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
        backgroundColor: const Color(0xFF1E3A42),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCarScreen()),
          );
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
