import 'package:enginuity_the_app/screens/connect_screen.dart';
import 'package:enginuity_the_app/screens/home.dart';
import 'package:enginuity_the_app/screens/login_screen.dart';
import 'package:enginuity_the_app/screens/signup_screen.dart';
import 'package:enginuity_the_app/screens/splash_screen.dart';
import 'package:enginuity_the_app/screens/start_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'add_car_screen.dart';
// import 'home_screen.dart';
// import 'login_screen.dart';
// import 'signup_screen.dart';
// import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}): super(key: key);

  @override Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Enginuity',
      theme: ThemeData.dark(),
      home: HomeScreen(), // <== DIRECT TEST HERE COMMENT ROUTES OUT TO TEST
      //initialRoute: '/',
      //routes: {
      //  '/': (context) => const SplashScreen(),
      //  '/signup': (context) => const SignUpScreen(),
      //  '/start-screen': (context) => const StartScreen(),
      //  '/login': (context) => const LoginScreen(),
      //  '/home': (context) => const HomeScreen()
      // },
    );
  }
}
