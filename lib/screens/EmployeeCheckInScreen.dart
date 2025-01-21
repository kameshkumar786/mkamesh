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
  DateTime? checkInTime; // To store the time of check-in
  String formattedCheckInTime = "--:--"; // To store the formatted check-in time
  String duration = "--:--:--"; // To store the duration as a string

  final FrappeService _frappeService = FrappeService();
  Timer? _timer;
  bool _isRefreshing = false; // State for refreshing
  Map<String, dynamic> userdata = {}; // Corrected type

  bool _isTracking = false;

  static const platform = MethodChannel('com.example.mkamesh/location');

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _getCurrentLocation();
    _fetchLastRecord();
    checkLoginStatus();

    _loadCheckInData();

    // Start a timer to update the UI every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (isCheckedIn) {
          duration = _calculateDuration(); // Update duration live
        }
      });
    });
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
    String? userDataString = prefs.getString('user_data');

    if (userDataString != null) {
      print('${json.decode(userDataString)}');

      setState(() {
        userdata = json.decode(userDataString); // Decode JSON string into a Map
      });
    } else {
      print('No user data found in SharedPreferences.');
    }
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

  // Get the current location
  Future<void> _getCurrentLocation() async {
    LocationData locationData = await location.getLocation();
    setState(() {
      currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
    });
  }

  // Fetch the last record from the API
  Future<void> _fetchLastRecord() async {
    try {
      final response = await _frappeService.getLastCheckIn();
      print("Last Check-In Response: $response");

      if (response['message']['status']) {
        final lastLog = response['message']['data'];
        print("lastLog Response: $lastLog");

        if (lastLog != null && lastLog['log_type'] == 'IN') {
          // Combine event_date and event_time into a valid DateTime string
          final eventDate = lastLog['event_date']; // e.g., "2025-01-19"
          // final eventTime = lastLog['event_time']; // e.g., "12:28:45.37161"
          // final formattedTime =
          //     eventTime.split('.').first; // Remove microseconds part

          final combinedDateTime = "$eventDate"; // Combine date and time
          print("Parsed datetime: $combinedDateTime");
          _startTracking();

          // Parse the combined string into a DateTime object
          setState(() {
            isCheckedIn = true;
            checkInTime = DateTime.parse(combinedDateTime);
            formattedCheckInTime =
                _formatDate(checkInTime!); // Store formatted time
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

    // Check if location service is enabled
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

    // Check for location permissions
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

    // Fetch current location
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

  // Handle Check-In or Check-Out
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

            // Store check-in details in local storage
            prefs.setString('check_in_time', checkInTime!.toIso8601String());
            prefs.setString('check_in_location', latlong);
            prefs.setBool('is_checked_in', true);
          } else if (logType == "OUT") {
            checkInTime = null;
            _stopTracking();

            prefs.remove('check_in_time');
            prefs.remove('check_in_location');
            prefs.setBool('is_checked_in', false);
          } else {
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

  // Calculate duration since check-in
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
    _timer?.cancel(); // Cancel the timer
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
      // appBar: AppBar(
      //   title: Text('Employee Check-In'),
      // ),
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
                // Employee name and time display
                _buildEmployeeDetails(),

                SizedBox(height: 5),

                // Current time and date
                _buildTimeDisplay(),

                SizedBox(height: 20),

                // Clock out button with grid background
                _buildClockOutButton(),

                SizedBox(height: 20),

                if (isCheckedIn)
                  ElevatedButton(
                    onPressed: () {
                      _gotohome();
                      // _refreshData();
                      // Navigate to the home screen or handle the "Go to Home" logic
                      // Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Text('Go to Home'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor:
                          Colors.green, // Set the text color to white
                      padding: EdgeInsets.symmetric(
                          horizontal: 50, vertical: 10), // Button padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                // SizedBox(height: 20),
                // if (!isCheckedIn)
                //   ElevatedButton(
                //     onPressed: () => _handleCheckInOut('IN'),
                //     child: Text('Check In'),
                //     style: ElevatedButton.styleFrom(
                //       foregroundColor: Colors.white,
                //       backgroundColor:
                //           Colors.black, // Set the text color to white
                //       padding: EdgeInsets.symmetric(
                //           horizontal: 50, vertical: 10), // Button padding
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(
                //             10), // Optional: Rounded corners
                //       ),
                //     ),
                //   ),
                // if (isCheckedIn)
                //   ElevatedButton(
                //     onPressed: () => _handleCheckInOut('OUT'),
                //     style: ElevatedButton.styleFrom(
                //       foregroundColor: Colors.white,
                //       backgroundColor:
                //           Colors.black, // Set the text color to white
                //       padding: EdgeInsets.symmetric(
                //           horizontal: 50, vertical: 10), // Button padding
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(
                //             10), // Optional: Rounded corners
                //       ),
                //     ),
                //     child: Text('Check Out'),
                //   ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _logout,
                  child: Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(
                        255, 251, 17, 1), // Set the text color to white
                    padding: EdgeInsets.symmetric(
                        horizontal: 80, vertical: 10), // Button padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          10), // Optional: Rounded corners
                    ),
                  ),
                ),

                // Work hours display
                _buildWorkHours(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Employee details (name and clock in time)
  Widget _buildEmployeeDetails() {
    String name = userdata['name'] ?? 'Unknown Name'; // Default value if null
    String employeeName = userdata['employee_name'] ?? 'Unknown Employee';
    String greeting = _getGreetingMessage();

    return Column(
      children: [
        // CircleAvatar(
        //   radius: 40,
        //   backgroundImage: AssetImage(
        //       'assets/employee_photo.jpg'), // Replace with actual photo
        // ),
        SizedBox(height: 10),
        Text(
          greeting, // Display the greeting message
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        SizedBox(height: 10),
        Text(
          'Welcome, $employeeName', // Display the user name
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        // SizedBox(height: 5),
        // Text(
        //   '$employeeName', // Display the employee name
        //   style: TextStyle(fontSize: 16, color: Colors.grey),
        // ),
      ],
    );
  }

  // Current time and date
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

// Clock out button with grid background using CustomPainter
  // Clock out button with gradient background
  Widget _buildClockOutButton() {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isCheckedIn
              ? [
                  const Color.fromARGB(
                      255, 241, 72, 72), // Red gradient when checked in
                  const Color.fromARGB(
                      255, 2, 35, 247), // Blue gradient when checked in
                ]
              : [
                  const Color.fromARGB(255, 72, 241,
                      241), // Light blue gradient when not checked in
                  const Color.fromARGB(
                      255, 247, 2, 247), // Purple gradient when not checked in
                ],
        ),
      ),
      child: CustomPaint(
        // painter: GridPainter(), // Optional: Draw the grid using CustomPainter
        child: ElevatedButton(
          onPressed: () => {
            if (isCheckedIn)
              {_handleCheckInOut('OUT')}
            else
              {_handleCheckInOut('IN')}
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors
                .transparent, // Transparent to show the gradient background
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

  // Work hours (Clock in, Clock out, Total hours)
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

  // Helper method for time labels
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
