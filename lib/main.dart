import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'customer_dashboard.dart';
import 'shopkeeper_dashboard.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NearBuy App',

      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),

      initialRoute: '/',

      routes: {
        '/': (context) => SplashScreen(),

        // ✅ LoginScreen ab role parameter nahi leta
        '/login': (context) => const LoginScreen(),

        // Signup ke liye role required hota hai
        '/signup': (context) =>
            const SignupScreen(role: 'Customer'),

        '/customerDashboard': (context) =>
            const CustomerDashboard(),

        '/shopkeeperDashboard': (context) =>
            const ShopkeeperDashboard(),

        '/adminDashboard': (context) =>
            const AdminDashboard(),
      },
    );
  }
}