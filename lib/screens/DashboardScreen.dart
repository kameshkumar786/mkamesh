import 'package:flutter/material.dart';
import 'package:mkamesh/services/location_service.dart';

class Dashboardscreen extends StatelessWidget {
  bool _isTracking = false;

  Dashboardscreen({super.key});

  void _toggleTracking() {
    if (_isTracking) {
      LocationService.stopTracking();
    } else {
      LocationService.startTracking();
    }

    // setState(() {
    _isTracking = !_isTracking;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Background Location Tracking'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleTracking,
              child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}
