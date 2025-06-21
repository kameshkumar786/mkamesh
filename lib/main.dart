import 'package:flutter/material.dart';
import 'package:mkamesh/screens/AuthScreens/forgot_password_page.dart';
import 'package:mkamesh/screens/AuthScreens/login_page.dart';
import 'package:mkamesh/screens/AuthScreens/signup_page.dart';
import 'package:mkamesh/screens/EmployeeCheckInScreen.dart';
import 'package:mkamesh/screens/formscreens/database_helper.dart';
import 'package:mkamesh/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("YOUR_ONESIGNAL_APP_ID");
  OneSignal.Notifications.requestPermission(true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MKamesh',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.black),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.black,
          indicatorColor: Colors.blue,
        ),
      ),
      // home: const InternetChecker(),
      home: HomePage(),
      routes: {
        '/permission-checker': (context) => EmployeeCheckInScreen(),
        '/home': (context) => HomePage(),
        '/login': (context) => const LoginPage(),
        '/no-permission': (context) => const NoPermissionPage(),
        '/signup': (context) => SignupPage(),
        '/forgot_password': (context) => ForgotPasswordPage(),
        '/checkin': (context) => EmployeeCheckInScreen(),
      },
    );
  }
}

class InternetChecker extends StatelessWidget {
  const InternetChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged.map(
            (event) => event.isNotEmpty ? event.first : ConnectivityResult.none,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData && snapshot.data == ConnectivityResult.none) {
            return const NoInternetScreen();
          }
          return HomePage();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("No Internet Connection")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "No Internet Connection",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Please check your internet settings and try again.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Connectivity().checkConnectivity(),
              child: const Text("Retry"),
            ),
          ],
        ),
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
