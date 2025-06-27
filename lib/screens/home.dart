import 'package:flutter/material.dart';
import 'add_car_screen.dart';
import 'connect_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Share icon tapped, navigate to ConnectScreen
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ConnectScreen()),
      );
      // After returning, set selected index back to home
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F26),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.grey,
                        radius: 22,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Walker', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('Hey, Paul !', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  Icon(Icons.signal_cellular_alt, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Home',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:  [
                  Text('My Cars', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2C4D54),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddCarScreen()),
                      );
                    },
                    child: Text('ADD CAR', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_car, size: 120, color: Colors.black54),
                      SizedBox(height: 10),
                      Text('No Cars', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Sorry to let you down 💔', style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A1F26),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.share), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}
