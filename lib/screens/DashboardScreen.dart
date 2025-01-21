import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mkamesh/services/frappe_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  _DashboardscreenState createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  bool _isTracking = false;

  static const platform = MethodChannel('com.example.mkamesh/location');
  bool _isRefreshing = false; // State for refreshing
  String? userId = '';
  final FrappeService _frappeService = FrappeService();

  Future<void> _startTracking() async {
    try {
      await platform.invokeMethod('startTracking');
      setState(() {
        _isTracking = true; // Update state to true
      });
    } catch (e) {
      print("Error starting tracking: $e");
    }
  }

  Future<void> _stopTracking() async {
    try {
      await platform.invokeMethod('stopTracking');
      setState(() {
        _isTracking = false; // Update state to false
      });
    } catch (e) {
      print("Error stopping tracking: $e");
    }
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userid');
    });
  }

  // Function to refresh data
  void _refreshData() async {
    checkLoginStatus();
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _frappeService.fetchUserData(); // Re-fetch user data
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data refreshed successfully! $userId'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to refresh data: ${e.toString()}'),
      ));
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kamester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData, // Refresh user data
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Logout user
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Clear stored data
              Navigator.pushReplacementNamed(
                  context, '/login'); // Go to login page
            },
          )
        ],
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isTracking
                  ? 'Tracking Location...'
                  : 'Location Tracking Stopped',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : _startTracking,
              child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}
