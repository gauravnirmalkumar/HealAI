import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/auth/login.dart';
import 'pages/auth/signup.dart';
import 'pages/doctor/doctor_dashboard.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
     options: FirebaseOptions(
    apiKey: 'AIzaSyBCwuyZ1gx7nPWiRGt9LhjuUVHKqjNLV_Y',
    appId: '1:893121864908:android:1a868522d2a04861aa4e69',
    messagingSenderId: '893121864908',
    projectId: 'diabeticfootulcer-caf70',
    storageBucket: 'diabeticfootulcer-caf70.appspot.com',)
  );
  

 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Woundly',
      theme: ThemeData(
        primaryColor: const Color(0xFF00B0A6),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B0A6)),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/startup': (context) => const StartupScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/doctor_dashboard': (context) => DoctorDashboard(),
      
        
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData) {
          // Check user type from Firestore and redirect accordingly
          return FutureBuilder<String>(
            future: getUserType(snapshot.data!.uid),
            builder: (context, userTypeSnapshot) {
              if (userTypeSnapshot.hasData) {
                if (userTypeSnapshot.data == 'doctor') {
                  return DoctorDashboard();
                } else {
                  
                }
              }
              // While checking user type, show loading
              return const CircularProgressIndicator();
            },
          );
        }
        // If the snapshot has no user data, show startup screen
        return const StartupScreen();
      },
    );
  }

  Future<String> getUserType(String uid) async {
    // TODO: Implement Firestore check for user type
    // This is a placeholder - implement actual Firestore logic
    return 'doctor';
  }
}