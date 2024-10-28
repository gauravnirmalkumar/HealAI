import 'package:flutter/material.dart';
import 'auth/login.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff15A196),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and heartbeat line
                Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                  'Woundly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                  ),
                ],
                ),
                
                const SizedBox(height: 20), // Added space between "Woundly" and the image
                
                // Medical Symbol (Caduceus)
                Image.asset(
                'logo.png', // You'll need to add this asset
                height: 100,
                color: Colors.white,
                ),
                
                const SizedBox(height: 40),
              // Tagline
              const Text(
                'AI-Powered Healing\nfor Diabetic Foot Ulcers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Get Started Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff15A196),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Get started',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}