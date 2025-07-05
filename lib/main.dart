import 'package:engineuity/screens/home.dart';
import 'package:engineuity/screens/login_screen.dart';
import 'package:engineuity/screens/signup_screen.dart';
import 'package:engineuity/screens/splash_screen.dart';
import 'package:engineuity/screens/start_screen.dart';
import 'package:engineuity/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();

  // Create Engineuity folder for CSV storage
  await _createEngineuityFolder();

  runApp(const MyApp());
}

Future<void> _createEngineuityFolder() async {
  try {
    // Request storage permissions first
    final storageStatus = await Permission.storage.request();
    final manageStorageStatus =
        await Permission.manageExternalStorage.request();

    debugPrint('📱 Storage permission status: $storageStatus');
    debugPrint('📱 Manage storage permission status: $manageStorageStatus');

    // On Android 11+ (API 30+), only MANAGE_EXTERNAL_STORAGE is needed
    // On older versions, STORAGE permission is needed
    if (manageStorageStatus.isGranted) {
      debugPrint('✅ Manage external storage permission granted');
    } else if (storageStatus.isGranted) {
      debugPrint('✅ Storage permission granted');
    } else {
      debugPrint(
        '⚠️ Storage permissions denied - CSV files will be saved to private directory',
      );
      return;
    }

    final engineuityDir = Directory('/storage/emulated/0/Engineuity');
    if (!await engineuityDir.exists()) {
      await engineuityDir.create(recursive: true);
      debugPrint('📁 Created Engineuity folder: ${engineuityDir.path}');
    } else {
      debugPrint('📁 Engineuity folder already exists: ${engineuityDir.path}');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to create Engineuity folder: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Engineuity',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A1F26),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1F26),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF12303B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A42),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/start-screen': (context) => const StartScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
