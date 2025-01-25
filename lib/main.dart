import 'package:flutter/material.dart';
import 'package:mkamesh/screens/AuthScreens/forgot_password_page.dart';
import 'package:mkamesh/screens/AuthScreens/login_page.dart';
import 'package:mkamesh/screens/AuthScreens/signup_page.dart';
import 'package:mkamesh/screens/EmployeeCheckInScreen.dart';
import 'package:mkamesh/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Permission App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(), // Initial screen
      routes: {
        '/permission-checker': (context) => const LocationPermissionChecker(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/no-permission': (context) => const NoPermissionPage(),
        '/signup': (context) => SignupPage(),
        '/forgot_password': (context) => ForgotPasswordPage(),
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

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token'); // Check for login token

    // Simulate loading for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (token != null && token.isNotEmpty) {
      // If the user is logged in, navigate to permission checker
      Navigator.pushReplacementNamed(context, '/permission-checker');
    } else {
      // If the user is not logged in, navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show a loading indicator
      ),
    );
  }
}

class LocationPermissionChecker extends StatefulWidget {
  const LocationPermissionChecker({Key? key}) : super(key: key);

  @override
  _LocationPermissionCheckerState createState() =>
      _LocationPermissionCheckerState();
}

class _LocationPermissionCheckerState extends State<LocationPermissionChecker> {
  bool _isPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkBackgroundLocationPermission();
  }

  Future<void> _checkBackgroundLocationPermission() async {
    var status = await Permission.locationAlways.status;

    if (status.isGranted) {
      if (!_isPermissionChecked) {
        _isPermissionChecked = true;
        Navigator.pushReplacementNamed(context, '/checkin');
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      var requestStatus = await Permission.locationAlways.request();
      if (requestStatus.isGranted) {
        if (!_isPermissionChecked) {
          _isPermissionChecked = true;
          Navigator.pushReplacementNamed(context, '/checkin');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/no-permission');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Permission Checker")),
      body: const Center(
        child: CircularProgressIndicator(), // Show a loader while checking
      ),
    );
  }
}

class NoPermissionPage extends StatelessWidget {
  const NoPermissionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Permission Required")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Background location permission is required to use this feature.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text("Open App Settings"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/permission-checker');
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _logoutUser(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // Clear the login token
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _logoutUser(context),
          child: const Text("Logout"),
        ),
      ),
    );
  }
}
