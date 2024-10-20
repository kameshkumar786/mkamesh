import 'dart:convert';
// import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
//     as bg;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LocationService {
  static const String frappeApiUrl =
      'https://yourdomain.com/api/resource/Employee%20Location';
  static final Battery _battery = Battery();
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static final NetworkInfo _networkInfo = NetworkInfo();

  // Initialize background geolocation
  static Future<void> startTracking() async {
    // bg.BackgroundGeolocation.onLocation((bg.Location location) {
    //   _sendLocationAndDeviceInfo(
    //       location.coords.latitude, location.coords.longitude);
    // });

    // bg.BackgroundGeolocation.ready(
    //   bg.Config(
    //     desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
    //     distanceFilter: 10.0,
    //     stopOnTerminate: false,
    //     startOnBoot: true,
    //   ),
    // ).then((bg.State state) {
    //   if (!state.enabled) {
    //     bg.BackgroundGeolocation.start();
    //   }
    // });
  }

  static Future<void> stopTracking() async {
    // await bg.BackgroundGeolocation.stop();
  }

  // Collect and send location and device information
  static Future<void> _sendLocationAndDeviceInfo(
      double latitude, double longitude) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken =
        prefs.getString('auth_token'); // Use your saved login token here

    // Get battery level
    int batteryLevel = await _battery.batteryLevel;

    // Get device info
    final deviceData = await _deviceInfoPlugin.androidInfo;
    final String brand = deviceData.brand;
    final String model = deviceData.model;

    // Get network info
    String? ipAddress = await _networkInfo.getWifiIP();

    // Prepare API request
    final response = await http.post(
      Uri.parse(frappeApiUrl),
      headers: {
        'Authorization': 'token $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'employee': 'Employee Name or ID',
        'timestamp': DateTime.now().toIso8601String(),
        'battery_level': batteryLevel,
        'device_brand': brand,
        'device_model': model,
        'ip_address': ipAddress ?? 'Unknown',
      }),
    );

    if (response.statusCode == 200) {
      print("Location and device info sent successfully!");
    } else {
      print("Failed to send location: ${response.body}");
    }
  }
}
