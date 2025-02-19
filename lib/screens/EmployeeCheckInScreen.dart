import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:mkamesh/services/frappe_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeCheckInScreen extends StatefulWidget {
  @override
  _EmployeeCheckInScreenState createState() => _EmployeeCheckInScreenState();
}

class _EmployeeCheckInScreenState extends State<EmployeeCheckInScreen> {
  GoogleMapController? mapController;
  Location location = Location();
  LatLng currentLocation = LatLng(0, 0);
  bool isCheckedIn = false;
  DateTime? checkInTime;
  String formattedCheckInTime = "--:--";
  String duration = "--:--:--";

  final FrappeService _frappeService = FrappeService();
  Timer? _timer;
  bool _isRefreshing = false;
  Map<String, dynamic> userdata = {};

  bool _isTracking = false;

  static const platform = MethodChannel('com.example.mkamesh/location');

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _getCurrentLocation();
    _fetchLastRecord();
    checkLoginStatus();
    _checkLoginStatus();
    _loadCheckInData();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (isCheckedIn) {
          duration = _calculateDuration();
        }
      });
    });
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (kDebugMode) {
      print('my token: $token');
    }

    await Future.delayed(const Duration(seconds: 2));

    if (token != null && token.isNotEmpty) {
      // Navigate to the Session page if needed
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadCheckInData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      isCheckedIn = prefs.getBool('is_checked_in') ?? false;
      if (isCheckedIn) {
        String? checkInTimeString = prefs.getString('check_in_time');
        if (checkInTimeString != null) {
          checkInTime = DateTime.parse(checkInTimeString);
          formattedCheckInTime = _formatDate(checkInTime!);
        }
      }
    });
  }

  Future<void> _startTracking() async {
    try {
      await platform.invokeMethod('startTracking');
      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      print("Error starting tracking: $e");
    }
  }

  Future<void> _stopTracking() async {
    try {
      await platform.invokeMethod('stopTracking');
      setState(() {
        _isTracking = false;
      });
    } catch (e) {
      print("Error stopping tracking: $e");
    }
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      print('${json.decode(userDataString)}');

      setState(() {
        userdata = json.decode(userDataString);
      });
    } else {
      print('No user data found in SharedPreferences.');
    }
  }

  void _refreshData() async {
    checkLoginStatus();
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _frappeService.fetchUserData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data refreshed successfully! $userdata'),
      ));
    } catch (e) {
      print('error:${e}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to refresh data: ${e.toString()}'),
      ));
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat("d MMM y HH:mm").format(dateTime);
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationData locationData = await location.getLocation();
      setState(() {
        currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _fetchLastRecord() async {
    try {
      final response = await _frappeService.getLastCheckIn();
      print("Last Check-In Response: $response");

      if (response['message']['status']) {
        final lastLog = response['message']['data'];
        print("lastLog Response: $lastLog");

        if (lastLog != null && lastLog['log_type'] == 'IN') {
          final eventDate = lastLog['event_date'];
          final combinedDateTime = "$eventDate";
          print("Parsed datetime: $combinedDateTime");
          _startTracking();

          setState(() {
            isCheckedIn = true;
            checkInTime = DateTime.parse(combinedDateTime);
            formattedCheckInTime = _formatDate(checkInTime!);
          });
        } else if (lastLog != null && lastLog['log_type'] == 'OUT') {
          _stopTracking();
          setState(() {
            isCheckedIn = false;
            formattedCheckInTime = "--:--";
            duration = "--:--:--";
          });
        } else {
          setState(() {
            isCheckedIn = false;
            formattedCheckInTime = "--:--";
            duration = "--:--:--";
          });
        }
      }
    } catch (e) {
      print("Error fetching last record: $e");
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location services are disabled.")),
        );
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions are denied.")),
        );
        return;
      }
    }

    LocationData locationData = await location.getLocation();
    setState(() {
      currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
    });

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLng(currentLocation),
      );
    }
  }

  Future<void> _handleCheckInOut(String logType) async {
    final String latlong =
        "${currentLocation.latitude},${currentLocation.longitude}";

    SharedPreferences prefs = await SharedPreferences.getInstance();

    final req = {
      "latlong": latlong,
      "log_type": logType,
    };

    try {
      final response = await _frappeService.CheckIn(req);

      print("Response from API: $response");

      if (response['message']?['status'] == true) {
        setState(() {
          isCheckedIn = logType == "IN";
          if (logType == "IN") {
            checkInTime = DateTime.now();
            _startTracking();

            prefs.setString('check_in_time', checkInTime!.toIso8601String());
            prefs.setString('check_in_location', latlong);
            prefs.setBool('is_checked_in', true);
          } else if (logType == "OUT") {
            checkInTime = null;
            _stopTracking();

            prefs.remove('check_in_time');
            prefs.remove('check_in_location');
            prefs.setBool('is_checked_in', false);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "${logType == 'IN' ? 'Check-In' : 'Check-Out'} successful.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Failed to $logType: ${response['message']?['message']}")),
        );
      }
    } catch (e) {
      print("Error during $logType: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to $logType: $e")),
      );
    }
  }

  String _calculateDuration() {
    if (checkInTime == null) {
      return "--:--:--";
    }

    final now = DateTime.now();
    final duration = now.difference(checkInTime!);

    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _logout() {
    print("Logged Out");
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _gotohome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else if (hour < 20) {
      return "Good Evening";
    } else {
      return "Good Night";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: currentLocation,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('currentLocation'),
                  position: currentLocation,
                ),
              },
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildEmployeeDetails(),
                SizedBox(height: 5),
                _buildTimeDisplay(),
                SizedBox(height: 20),
                _buildClockOutButton(),
                SizedBox(height: 20),
                if (isCheckedIn)
                  ElevatedButton(
                    onPressed: _gotohome,
                    child: Text('Go to Home'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _logout,
                  child: Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 251, 17, 1),
                    padding: EdgeInsets.symmetric(horizontal: 80, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                _buildWorkHours(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDetails() {
    String name = userdata['name'] ?? 'Unknown Name';
    String employeeName = userdata['employee_name'] ?? 'Unknown Employee';
    String greeting = _getGreetingMessage();

    return Column(
      children: [
        SizedBox(height: 10),
        Text(
          greeting,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        SizedBox(height: 10),
        Text(
          'Welcome, $employeeName',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay() {
    return Column(
      children: [
        if (isCheckedIn)
          Text(
            '${_calculateDuration()}',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
        SizedBox(height: 1),
        if (isCheckedIn)
          Text(
            isCheckedIn ? formattedCheckInTime : 'Not Checked-In',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildClockOutButton() {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isCheckedIn
              ? [
                  const Color.fromARGB(255, 241, 72, 72),
                  const Color.fromARGB(255, 2, 35, 247),
                ]
              : [
                  const Color.fromARGB(255, 72, 241, 241),
                  const Color.fromARGB(255, 247, 2, 247),
                ],
        ),
      ),
      child: CustomPaint(
        child: ElevatedButton(
          onPressed: () => {
            if (isCheckedIn)
              {_handleCheckInOut('OUT')}
            else
              {_handleCheckInOut('IN')}
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: CircleBorder(),
            padding: EdgeInsets.all(40),
            elevation: 10,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint, color: Colors.white, size: 40),
              SizedBox(height: 10),
              if (isCheckedIn)
                Text(
                  'Check-OUT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              if (!isCheckedIn)
                Text(
                  'Check-IN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkHours() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeLabel('${formattedCheckInTime}', 'Check-IN Day'),
            _buildTimeLabel('--:--', 'Check-In Time'),
            _buildTimeLabel('${_calculateDuration()}', 'Go To Home'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeLabel(String time, String label) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
