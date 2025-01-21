import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mkamesh/screens/AuthScreens/login_page.dart';
import 'package:mkamesh/screens/CheckInScreen.dart';
import 'package:mkamesh/screens/EmployeeCheckInScreen.dart';
import 'package:mkamesh/screens/OnboardingScreen/introduction_animation_screen.dart';
import 'package:mkamesh/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.white, // Status bar background color
    statusBarIconBrightness: Brightness.dark, // Icons and text dark
    statusBarBrightness:
        Brightness.light, // For iOS (light background, dark content)
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frappe Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // Set splash screen as the initial screen
      routes: {
        '/onboarding': (context) => const IntroductionAnimationScreen(),
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/checkin': (context) => EmployeeCheckInScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Check if the user is already logged in
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (kDebugMode) {
      print('my token: $token');
    }

    // Wait for 2 seconds to simulate loading (optional, just for UX)
    await Future.delayed(const Duration(seconds: 2));

    if (token != null && token.isNotEmpty) {
      // If token exists, navigate to the Sassion page
      Navigator.pushReplacementNamed(context, '/checkin');
    } else {
      // If no token, navigate to the login page
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(), // Show loading indicator while checking status
      ),
    );
  }
}
