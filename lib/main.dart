import 'package:enginuity_the_app/screens/home.dart';
import 'package:enginuity_the_app/screens/login_screen.dart';
import 'package:enginuity_the_app/screens/signup_screen.dart';
import 'package:enginuity_the_app/screens/splash_screen.dart';
import 'package:enginuity_the_app/screens/start_screen.dart';
import 'package:enginuity_the_app/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Enginuity',
      theme: ThemeData.dark(),
      //home: HomeScreen(), // <== DIRECT TEST HERE COMMENT ROUTES OUT TO TEST
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/start-screen': (context) => const StartScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
