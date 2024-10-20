import 'package:flutter/material.dart';
import 'package:mkamesh/screens/DashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/frappe_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FrappeService _frappeService = FrappeService();
  int _selectedIndex = 0; // Track the selected tab index
  bool _isRefreshing = false; // State for refreshing
  String? userId = '';

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userid');
    });
  }

  // List of screens corresponding to each tab
  final List<Widget> _screens = [
    Dashboardscreen(), // Tab 1: Project Dashboard
    TimesheetScreen(), // Tab 2: Timesheets
    CustomerChatScreen(), // Tab 3: Customer Chat
    TeamChatScreen(), // Tab 4: Team Chat
    ReportsScreen(), // Tab 5: Reports
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
      appBar: AppBar(
        title: Text('Customer Handling'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData, // Refresh user data
          ),
          IconButton(
            icon: Icon(Icons.logout),
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
      body: _screens[_selectedIndex], // Show selected tab content
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Timesheet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Customer Chat',
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
        unselectedItemColor: const Color.fromARGB(255, 113, 113, 113),
        showUnselectedLabels: true,
        backgroundColor: Colors.blue[100],
      ),
      backgroundColor: Colors.white,
      // Set your desired background color here
    );
  }
}

// Example screens for each tab with background color
class ProjectDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: Center(
        child: Text(
          'Project Dashboard',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class TimesheetScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: Center(
        child: Text(
          'Timesheet Management',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class CustomerChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: Center(
        child: Text(
          'Customer Chat',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class TeamChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: Center(
        child: Text(
          'Team Chat',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set your desired background color here
      child: Center(
        child: Text(
          'Reports',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
