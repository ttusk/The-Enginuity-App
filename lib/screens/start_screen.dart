import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1E24),
              Color(0xFF2A738A),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100,),
            const Text(
              'Enginuity',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 100),
            Image.asset('assets/images/engine_logo_2.png', height: 180),
            const SizedBox(height: 100),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Login',
                buttonColor: Color(0xFF2B4752),
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ),

            ),

            const SizedBox(height: 25),

            Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Create Account',
                  buttonColor: Color(0xFF697F8C),
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                ),
              ),

            ),
            const SizedBox(height: 16),

          ],
        ),
      ),
    );
  }
}
