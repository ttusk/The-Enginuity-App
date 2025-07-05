import 'package:enginuity_the_app/screens/home.dart';
import 'package:enginuity_the_app/screens/login_screen.dart';
import 'package:enginuity_the_app/screens/signup_screen.dart';
import 'package:enginuity_the_app/screens/splash_screen.dart';
import 'package:enginuity_the_app/screens/start_screen.dart';
import 'package:enginuity_the_app/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();

  // Create Enginuity folder for CSV storage
  await _createEnginuityFolder();

  runApp(const MyApp());
}

Future<void> _createEnginuityFolder() async {
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

    final enginuityDir = Directory('/storage/emulated/0/Enginuity');
    if (!await enginuityDir.exists()) {
      await enginuityDir.create(recursive: true);
      debugPrint('📁 Created Enginuity folder: ${enginuityDir.path}');
    } else {
      debugPrint('📁 Enginuity folder already exists: ${enginuityDir.path}');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to create Enginuity folder: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Enginuity',
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
