import 'package:flutter/material.dart';
import 'package:mkamesh/screens/AuthScreens/login_page.dart';
import 'package:mkamesh/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frappe Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // Set splash screen as the initial screen
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
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
    String? cookies = prefs.getString('cookies');

    // Wait for 2 seconds to simulate loading (optional, just for UX)
    await Future.delayed(Duration(seconds: 2));

    if (cookies != null && cookies.isNotEmpty) {
      // If cookies exist, navigate to the home page
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // If no cookies, navigate to the login page
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(), // Show loading indicator while checking status
      ),
    );
  }
}
