import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mkamesh/screens/ApprovalRequestScreen.dart';
import 'package:mkamesh/screens/EmployeeProfileScreen.dart';
import 'package:mkamesh/screens/formscreens/DoctypeListView.dart';
import 'package:mkamesh/screens/formscreens/FormPage.dart';
import 'package:mkamesh/services/frappe_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For the chart
import 'package:cached_network_image/cached_network_image.dart';

class MyHomeScreen extends StatefulWidget {
  @override
  _MyHomeScreenState createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  DateTime? checkInTime;
  bool isCheckedIn = false;
  String formattedCheckInTime = "--:--";
  String duration = "";
  Timer? timer;
  Map<String, dynamic> userdata = {}; // Corrected type
  final FrappeService _frappeService = FrappeService();
  bool _isRefreshing = false;
  bool _isLoading = true;

  List homePageData = [];
  List homePageSectionData = [];

  Future<List<dynamic>>? _attendanceFuture;
  Future<Map<String, List<dynamic>>>? _workflowActionsFuture;

  // Theme Colors
  static const Color primaryColor = Colors.black;
  static const Color secondaryColor = Colors.grey;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1E293B);
  static const Color textSecondaryColor = Color(0xFF64748B);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  // Quick Actions Grid Items
  final List<Map<String, dynamic>> gridItems = [
    {
      "icon": Icons.attach_money,
      "label": "Expense",
      "onPressed": () => print("Expense Pressed")
    },
    {
      "icon": Icons.beach_access,
      "label": "Holiday",
      "onPressed": () => print("Holiday Pressed")
    },
    {
      "icon": Icons.shopping_cart,
      "label": "Orders",
      "onPressed": () => print("Orders Pressed")
    },
    {
      "icon": Icons.insert_drive_file,
      "label": "Quotation",
      "onPressed": () => print("Quotation Pressed")
    },
    {
      "icon": Icons.airline_seat_recline_normal,
      "label": "Leave",
      "onPressed": () => print("Leave Pressed")
    },
    {
      "icon": Icons.calendar_today,
      "label": "Attendance",
      "onPressed": () => print("Attendance Pressed")
    },
    {
      "icon": Icons.location_on,
      "label": "Visit",
      "onPressed": () => print("Visit Pressed")
    },
    {
      "icon": Icons.access_time,
      "label": "Time Sheet",
      "onPressed": () => print("Time Sheet Pressed")
    },
    {
      "icon": Icons.payment,
      "label": "Payroll",
      "onPressed": () => print("Payroll Pressed")
    },
    {
      "icon": Icons.credit_card,
      "label": "Payment",
      "onPressed": () => print("Payment Pressed")
    },
    {
      "icon": Icons.report_problem,
      "label": "Issue",
      "onPressed": () => print("Issue Pressed")
    },
  ];

  // Add missing expenseItems definition
  final List<Map<String, dynamic>> expenseItems = [
    {
      "icon": Icons.attach_money,
      "label": "Expense",
      "onPressed": () => print("Expense Pressed")
    },
    {
      "icon": Icons.shopping_cart,
      "label": "Orders",
      "onPressed": () => print("Orders Pressed")
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize all futures first
      _attendanceFuture = fetchAttendanceRecords();
      _workflowActionsFuture = fetchWorkflowActions();

      // Then wait for all data to load
      await Future.wait([
        _fetchCheckInData(),
        checkLoginStatus(),
        getHomepageData(),
        gettasks_and_request_and_attendancedata(),
      ]);

      // Wait for attendance and workflow data separately
      await Future.wait([
        _attendanceFuture!,
        _workflowActionsFuture!,
      ]);
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data. Please try again.'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _initializeData();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> getHomepageData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${FrappeService.baseUrl}/api/resource/Mobile App Dashboard/demo1?fields=["items","section_name"]'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('response data $data');
        setState(() {
          homePageData = [data['data']];

          _isRefreshing = false;
        });
      } else {
        print('response data failed to load ${response.toString()}');

        throw Exception('Failed to load document data');
      }
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
      // showError(e.toString());
    }
  }

  Future<void> gettasks_and_request_and_attendancedata() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${FrappeService.baseUrl}/api/method/gettasks_and_request_and_attendancedata'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('response data ${data['message']}');
        setState(() {
          homePageSectionData = [data['message']['data']];

          _isRefreshing = false;
        });
      } else {
        print('response data failed to load ${response.toString()}');

        throw Exception('Failed to load document data');
      }
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
      // showError(e.toString());
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

  Future<void> _fetchCheckInData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isCheckedIn = prefs.getBool('is_checked_in') ?? false;

    if (isCheckedIn) {
      String? checkInTimeString = prefs.getString('check_in_time');
      if (checkInTimeString != null) {
        checkInTime = DateTime.parse(checkInTimeString);
        _startTimer(); // Start the timer if checked in
      }
    } else {
      Navigator.pushNamed(context, '/checkin');
    }
  }

  void _startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        duration = _calculateDuration();
      });
    });
  }

  String _calculateDuration() {
    if (checkInTime == null) return "No check-in time available";

    final now = DateTime.now();
    final difference = now.difference(checkInTime!);

    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');

    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    timer?.cancel(); // Cancel the timer when disposing
    super.dispose();
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Loading...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Please wait while we fetch your data",
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: primaryColor,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: backgroundColor,
                foregroundColor: textPrimaryColor,
                surfaceTintColor: cardColor,
                elevation: 2,
                title: _buildGreetingSection(),
                actions: [
                  _buildProfileAvatar(),
                  SizedBox(width: 16),
                ],
              ),

              // Main Content

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift Timer Card
                      _buildShiftTimerCard(),
                      SizedBox(height: 24),

                      // Quick Actions Grid
                      _buildQuickActionsGrid(),
                      SizedBox(height: 16),

                      // Dynamic Sections
                      ...homePageData.map<Widget>((item) {
                        return Column(
                          children: [
                            _buildSection(
                                item["section_name"] ?? 'Section name',
                                item["items"] ?? expenseItems),
                            SizedBox(height: 16),
                          ],
                        );
                      }).toList(),

                      // Tasks Section
                      _buildTasksSection(),
                      SizedBox(height: 16),

                      // Leave Balance Section
                      _buildLeaveBalanceSection(),
                      SizedBox(height: 16),

                      // Requests Section
                      // _buildRequestsSection(),
                      // SizedBox(height: 24),

                      // Attendance Section
                      _buildAttendanceSection(),
                      SizedBox(height: 24),

                      // Approval Requests Section
                      _buildApprovalRequestsSection(),
                      SizedBox(height: 24),

                      // Trusted By Section
                      _buildTrustedBySection(),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreetingMessage(),
          style: TextStyle(
            fontSize: 13,
            color: textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          userdata['employee_name'] ?? 'Unknown Name',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeProfileScreen(employeeId: ''),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryColor, width: 2),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildShiftTimerCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Started Your Shift at ${checkInTime?.toString().substring(11, 16) ?? '--:--'}",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            duration,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/checkin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              "Check Out",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              final item = gridItems[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildQuickActionItem(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(Map<String, dynamic> item) {
    return InkWell(
      onTap: item["onPressed"],
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item["icon"], color: primaryColor, size: 22),
            ),
            SizedBox(height: 8),
            Text(
              item["label"],
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("My Tasks", "Task"),
        SizedBox(height: 12),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: (homePageSectionData[0]['tasks'] ?? []).length,
            itemBuilder: (context, index) {
              final task = homePageSectionData[0]['tasks'][index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTaskCard(task),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(task) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FrappeCrudForm(
              doctype: "Task",
              docname: task['name'],
              baseUrl: 'http://localhost:8000',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(
                    task['status'],
                    task['status'] == "Completed" ? successColor : warningColor,
                  ),
                  _buildPriorityChip(
                    task['priority'],
                    task['priority'] == "High" ? errorColor : primaryColor,
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                task['description'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
              Text(
                task['title'],
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                ),
              ),
              Spacer(),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14, color: textSecondaryColor),
                  SizedBox(width: 4),
                  Text(
                    task['created_by'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondaryColor,
                    ),
                  ),
                  Spacer(),
                  Text(
                    task['modified'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("My Requests", "Request"),
        SizedBox(height: 16),
        _buildRequestCard("22 Aug 2024 - 25 Aug 2024", "Leave Request"),
        SizedBox(height: 12),
        _buildRequestCard("22 Aug 2024", "Day Off"),
      ],
    );
  }

  Widget _buildRequestCard(String date, String type) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          date,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        subtitle: Text(
          type,
          style: TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Track Attendance", "Attendance"),
        SizedBox(height: 12),
        if (_attendanceFuture == null)
          _buildEmptyStateWidget("No attendance data available")
        else
          FutureBuilder<List<dynamic>>(
            future: _attendanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 12),
                        Text(
                          "Loading attendance data...",
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error.toString());
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyStateWidget("No attendance records found");
              } else {
                return _buildAttendanceCardWithData(snapshot.data!);
              }
            },
          ),
      ],
    );
  }

  Widget _buildApprovalRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Approval Requests", "Approval"),
        SizedBox(height: 12),
        if (_workflowActionsFuture == null)
          _buildEmptyStateWidget("No approval requests available")
        else
          FutureBuilder<Map<String, List<dynamic>>>(
            future: _workflowActionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 12),
                        Text(
                          "Loading approval requests...",
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error.toString());
              } else if (!snapshot.hasData) {
                return _buildEmptyStateWidget("No workflow actions found");
              } else {
                return _buildWorkflowActions(snapshot.data!);
              }
            },
          ),
      ],
    );
  }

  Widget _buildTrustedBySection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.verified,
            size: 36,
            color: primaryColor,
          ),
          SizedBox(height: 12),
          Text(
            "Trusted by",
            style: TextStyle(
              fontSize: 15,
              color: textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Open Source Team",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String doctype) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctypeListView(
                doctype: doctype,
                prefilters: null,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            children: [
              Text(
                "See all",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New helper widget for error states
  Widget _buildErrorWidget(String error) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 24,
                color: errorColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: Icon(Icons.refresh, size: 14),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New helper widget for empty states
  Widget _buildEmptyStateWidget(String message) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textSecondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 24,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'No Data Available',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 5),
          Card(
            color: cardColor,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DoctypeListView(
                                doctype: item['linked_doctype'] ?? 'home',
                                prefilters: [])),
                      );
                    },
                    child: Container(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50.0,
                            height: 50.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: backgroundColor,
                              border: Border.all(
                                color: Colors.black,
                                width: 0.5,
                              ),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl:
                                    'http://localhost:8000${item['image']}',
                                placeholder: (context, url) =>
                                    CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            item['label'] ?? 'no labels',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> fetchAttendanceRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    // Get current month range
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    // ERPNext filter for attendance_date between firstDay and lastDay
    final filters = jsonEncode([
      ["attendance_date", ">=", firstDay.toIso8601String().substring(0, 10)],
      ["attendance_date", "<=", lastDay.toIso8601String().substring(0, 10)],
      ["docstatus", "=", 1],
    ]);

    final url = Uri.parse('http://localhost:8000/api/resource/Attendance'
        '?fields=["employee","attendance_date","status"]'
        '&filters=$filters'
        '&limit_page_length=31');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? '',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load attendance records');
    }
  }

  Widget _buildAttendanceCardWithData(List<dynamic> attendanceRecords) {
    // Group by status dynamically
    Map<String, int> statusCounts = {};
    for (var record in attendanceRecords) {
      final status = (record['status'] ?? 'Unknown').toString();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    int total = statusCounts.values.fold(0, (a, b) => a + b);

    // Improved color palette with better contrast
    final Map<String, Color> statusColorMap = {
      'Present': Color(0xFF10B981), // Green
      'Absent': Color(0xFFEF4444), // Red
      'Late': Color(0xFFF59E0B), // Orange
      'Half Day': Color(0xFF8B5CF6), // Purple
      'Work From Home': Color(0xFF3B82F6), // Blue
      'On Leave': Color(0xFFEC4899), // Pink
      'Holiday': Color(0xFF06B6D4), // Cyan
      'Weekend': Color(0xFF84CC16), // Lime
    };

    // Assign colors to statuses
    Map<String, Color> statusColors = {};
    int colorIndex = 0;
    final List<Color> fallbackColors = [
      Color(0xFF10B981), // Green
      Color(0xFFEF4444), // Red
      Color(0xFFF59E0B), // Orange
      Color(0xFF8B5CF6), // Purple
      Color(0xFF3B82F6), // Blue
      Color(0xFFEC4899), // Pink
      Color(0xFF06B6D4), // Cyan
      Color(0xFF84CC16), // Lime
    ];

    for (var status in statusCounts.keys) {
      statusColors[status] = statusColorMap[status] ??
          fallbackColors[colorIndex % fallbackColors.length];
      colorIndex++;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header with total days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "This Month",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "$total Days",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: primaryColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Attendance",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Chart and Details Row
            Row(
              children: [
                // Donut Chart
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 25,
                        sections: statusCounts.entries.map((entry) {
                          final color = statusColors[entry.key]!;
                          final percentage =
                              (entry.value / total * 100).round();

                          String title = entry.key;
                          if (title.length > 5) {
                            title = title.substring(0, 5) + '...';
                          }

                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            color: color,
                            radius: 45,
                            title: percentage > 8 ? '$percentage%' : '',
                            titleStyle: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Attendance Details
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      ...statusCounts.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildAttendanceDetail(
                              color: statusColors[entry.key]!,
                              label: entry.key,
                              count: entry.value,
                              total: total,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),

            // Summary Row
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    "Present",
                    statusCounts['Present']?.toString() ?? '0',
                    Icons.check_circle,
                    Color(0xFF10B981),
                  ),
                  _buildSummaryItem(
                    "Absent",
                    statusCounts['Absent']?.toString() ?? '0',
                    Icons.cancel,
                    Color(0xFFEF4444),
                  ),
                  _buildSummaryItem(
                    "Late",
                    statusCounts['Late']?.toString() ?? '0',
                    Icons.schedule,
                    Color(0xFFF59E0B),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceDetail({
    required Color color,
    required String label,
    required int count,
    required int total,
  }) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  "$percentage%",
                  style: TextStyle(
                    fontSize: 10,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<Map<String, List<dynamic>>> fetchWorkflowActions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('user_name');
    String? userEmail = prefs.getString('user_email');

    print('Fetching workflow actions for user: $userId, email: $userEmail');

    try {
      // Method 1: Using next_user field (for approvals)
      final toApproveUrl = Uri.parse(
          'http://localhost:8000/api/resource/Workflow Action'
          '?fields=["name","workflow_state","creation","reference_name","reference_doctype","owner","user","status","workflow_action_name","action","next_user"]'
          '&filters=[["next_user","=","$userId"]]'
          '&order_by=creation desc'
          '&limit_page_length=5');

      // Method 2: Using owner field (for sent requests)
      final sentUrl = Uri.parse(
          'http://localhost:8000/api/resource/Workflow Action'
          '?fields=["name","workflow_state","creation","reference_name","reference_doctype","owner","user","status","workflow_action_name","action","next_user"]'
          '&filters=[["owner","=","$userId"]]'
          '&order_by=creation desc'
          '&limit_page_length=5');

      // Alternative Method: Using user field for approvals (if next_user doesn't work)
      final alternativeToApproveUrl = Uri.parse(
          'http://localhost:8000/api/resource/Workflow Action'
          '?fields=["name","workflow_state","creation","reference_name","reference_doctype","owner","user","status","workflow_action_name","action","next_user"]'
          '&filters=[["user","=","$userId"],["status","=","Open"]]'
          '&order_by=creation desc'
          '&limit_page_length=5');

      print('To Approve URL: $toApproveUrl');
      print('Sent URL: $sentUrl');
      print('Alternative To Approve URL: $alternativeToApproveUrl');

      final toApproveResponse = await http.get(
        toApproveUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
      );

      final sentResponse = await http.get(
        sentUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? '',
        },
      );

      print('To Approve Response Status: ${toApproveResponse.statusCode}');
      print('Sent Response Status: ${sentResponse.statusCode}');

      List<dynamic> toApproveData = [];
      List<dynamic> sentData = [];

      if (toApproveResponse.statusCode == 200) {
        toApproveData = jsonDecode(toApproveResponse.body)['data'];
        print('To Approve Data (next_user): ${toApproveData.length} items');
      }

      if (sentResponse.statusCode == 200) {
        sentData = jsonDecode(sentResponse.body)['data'];
        print('Sent Data: ${sentData.length} items');
      }

      // If no approvals found with next_user, try alternative method
      if (toApproveData.isEmpty) {
        print(
            'No approvals found with next_user, trying alternative method...');
        final alternativeResponse = await http.get(
          alternativeToApproveUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': token ?? '',
          },
        );

        if (alternativeResponse.statusCode == 200) {
          toApproveData = jsonDecode(alternativeResponse.body)['data'];
          print('Alternative To Approve Data: ${toApproveData.length} items');
        }
      }

      // Log sample data for debugging
      if (toApproveData.isNotEmpty) {
        print('Sample To Approve Item: ${toApproveData.first}');
      }
      if (sentData.isNotEmpty) {
        print('Sample Sent Item: ${sentData.first}');
      }

      return {
        'toApprove': toApproveData,
        'sent': sentData,
      };
    } catch (e) {
      print('Error fetching workflow actions: $e');
      throw Exception('Failed to load workflow actions: $e');
    }
  }

  Widget _buildWorkflowActions(Map<String, List<dynamic>> data) {
    final sent = data['sent']!;
    final toApprove = data['toApprove']!;

    Color getStatusColor(String? status) {
      switch ((status ?? '').toLowerCase()) {
        case 'pending':
          return primaryColor;
        case 'completed':
          return Color(0xFF10B981);
        case 'open':
          return Color(0xFF3B82F6);
        case 'rejected':
          return Color(0xFFEF4444);
        default:
          return textSecondaryColor;
      }
    }

    Widget buildActionCard(dynamic action, {bool isSent = false}) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: getStatusColor(action['workflow_state']),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${action['reference_doctype'] ?? ''}: ${action['reference_name'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: getStatusColor(action['workflow_state'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${action['workflow_state'] ?? ''}",
                            style: TextStyle(
                              color: getStatusColor(action['workflow_state']),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.calendar_today,
                            size: 12, color: textSecondaryColor),
                        SizedBox(width: 3),
                        Text(
                          "${action['creation'].toString().substring(0, 10)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    if (action['status'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          "Status: ${action['status']}",
                          style: TextStyle(
                            fontSize: 11,
                            color: getStatusColor(action['status']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (action['owner'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 12, color: textSecondaryColor),
                            SizedBox(width: 4),
                            Text(
                              "Owner: ${action['owner']}",
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (action['user'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Icon(Icons.account_circle_outlined,
                                size: 12, color: textSecondaryColor),
                            SizedBox(width: 4),
                            Text(
                              "User: ${action['user']}",
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: textSecondaryColor,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: textPrimaryColor,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: "Sent (${sent.length})"),
                  Tab(text: "To Approve (${toApprove.length})"),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: TabBarView(
                children: [
                  sent.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          itemCount: sent.length,
                          itemBuilder: (context, idx) =>
                              buildActionCard(sent[idx], isSent: true),
                        )
                      : _buildEmptyStateWidget("No sent requests."),
                  toApprove.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          itemCount: toApprove.length,
                          itemBuilder: (context, idx) =>
                              buildActionCard(toApprove[idx], isSent: false),
                        )
                      : _buildEmptyStateWidget("No requests to approve."),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Add Leave Balance Section
  Widget _buildLeaveBalanceSection() {
    // Sample leave balance data - Replace with actual data from your API
    final List<Map<String, dynamic>> leaveBalances = [
      {
        "type": "Annual Leave",
        "total": 20,
        "used": 8,
        "remaining": 12,
        "color": Color(0xFF3B82F6),
      },
      {
        "type": "Sick Leave",
        "total": 10,
        "used": 3,
        "remaining": 7,
        "color": Color(0xFFEF4444),
      },
      {
        "type": "Casual Leave",
        "total": 12,
        "used": 5,
        "remaining": 7,
        "color": Color(0xFF10B981),
      },
      {
        "type": "Work From Home",
        "total": 15,
        "used": 6,
        "remaining": 9,
        "color": Color(0xFFF59E0B),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Leave Balance", "Leave Application"),
        SizedBox(height: 12),
        Container(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: leaveBalances.length,
            itemBuilder: (context, index) {
              final leave = leaveBalances[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildLeaveBalanceCard(leave),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveBalanceCard(Map<String, dynamic> leave) {
    final double usedPercentage = (leave['used'] / leave['total']) * 100;
    final double remainingPercentage =
        (leave['remaining'] / leave['total']) * 100;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              leave['type'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      height: 80,
                      width: 80,
                      child: CircularProgressIndicator(
                        value: usedPercentage / 100,
                        backgroundColor: leave['color'].withOpacity(0.1),
                        color: leave['color'],
                        strokeWidth: 8,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${leave['remaining']}",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        Text(
                          "days left",
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLeaveStat("Total", leave['total'].toString()),
                _buildLeaveStat("Used", leave['used'].toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textSecondaryColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
      ],
    );
  }
}
