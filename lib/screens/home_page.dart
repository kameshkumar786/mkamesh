import 'package:flutter/material.dart';
import 'package:mkamesh/screens/CategoryScreen.dart';
import 'package:mkamesh/screens/ChatListPage.dart';
import 'package:mkamesh/screens/ChatScreen.dart';
import 'package:mkamesh/screens/CheckInScreen.dart';
import 'package:mkamesh/screens/DashboardScreen.dart';
import 'package:mkamesh/screens/ModuleCategoriesScreen.dart';
import 'package:mkamesh/screens/MyHomeScreen.dart';
// import 'package:mkamesh/screens/formscreens/ReportDetailsScreen.dart';
import 'package:mkamesh/screens/formscreens/ReportScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/frappe_service.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _checkLocationPermission(); // Check permission on init
  }

  final FrappeService _frappeService = FrappeService();
  int _selectedIndex = 0; // Track the selected tab index
  bool _isRefreshing = false; // State for refreshing
  String? userId = '';

  Future<void> _checkLocationPermission() async {
    var status = await Permission.location.status;

    if (status.isGranted) {
      // Location permission is granted, you can access location
      print("Location permission granted.");
    } else if (status.isDenied) {
      // Location permission is denied, request permission
      print("Location permission denied. Requesting permission...");
      _requestLocationPermission();
    } else if (status.isPermanentlyDenied) {
      // Location permission is permanently denied, open app settings
      print("Location permission permanently denied. Opening app settings...");
      openAppSettings();
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();

    if (status.isGranted) {
      // Location permission granted after request
      print("Location permission granted after request.");
    } else if (status.isDenied) {
      // Location permission denied after request
      print("Location permission denied after request.");
    }
    // Optionally handle other statuses
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userid');
    });
  }

  // List of screens corresponding to each tab
  final List<Widget> _screens = [
    MyHomeScreen(),
    // Dashboardscreen(), // Tab 1: Project Dashboard
    // TimesheetScreen(), // Tab 2: Timesheets
    ProductScreen(),
    ModuleCategoriesScreen(),
    // CheckInScreen(),
    ChatListScreen(),
    // TeamChatScreen(), // Tab 4: Team Chat
    ReportScreen(), // Tab 5: Reports
  ];

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

  // Function to handle tab selection
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Update selected index
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Show selected tab content
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Set background color to white
          border: Border(
              top: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1)), // Optional: Add a border to separate from content
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'Category',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'Modules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Team Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart),
              label: 'Reports',
            ),
          ],
          currentIndex: _selectedIndex, // Current selected tab
          onTap: _onItemTapped, // Handle tab change
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type:
              BottomNavigationBarType.fixed, // Ensures background color applies
          backgroundColor: Colors.white, // Set background color
          elevation: 0, // Remove any shadow if present
        ),
      ),
      backgroundColor: Colors.white, // Ensure scaffold background is white
    );
  }
}

class TimesheetScreen extends StatelessWidget {
  const TimesheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: const Center(
        child: Text(
          'Timesheet Management',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// class ReportsScreen extends StatelessWidget {
//   const ReportsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white, // Set your desired background color here
//       child: const Center(
//         child: Text(
//           'Reports',
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
// }
