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

  List homePageData = [];
  List homePageSectionData = [];

  late Future<List<dynamic>>
      _attendanceFuture; // <-- yahan future declare karein
  late Future<Map<String, List<dynamic>>> _workflowActionsFuture;
  @override
  void initState() {
    super.initState();
    _fetchCheckInData();
    checkLoginStatus();
    getHomepageData();
    gettasks_and_request_and_attendancedata();
    _attendanceFuture = fetchAttendanceRecords();
    _workflowActionsFuture = fetchWorkflowActions();
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
    return Scaffold(
      backgroundColor: Colors.white, // Set background to white
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting Section
                _buildGreetingSection(),
                SizedBox(height: 20),

                // Shift Timer Section
                _buildShiftTimerSection((context)),
                SizedBox(height: 20),

                _buildGridSection((context)),
                // Text(homePageData.toString()),

                // ...homePageData.map((section) {
                //   return _buildSection(
                //       section["section_name"], section["items"]);
                // }).to(),

                ...homePageData.map<Widget>((item) {
                  return _buildSection(item["section_name"] ?? 'Section name',
                      item["items"] ?? expenseItems);
                  // return Padding(
                  //   padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  //   child: ListTile(
                  //     title: Text(item['section_name']),
                  //     subtitle: Text(item['name']),
                  //   ),
                  // );
                }).toList(),

                // _buildSection("Expenses", expenseItems),
                // _buildSection("Management", managementItems),
                // _buildSection("Other Tools", otherItems),

                SizedBox(height: 20),
                // My Tasks Section
                Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeaderWithLink("My Tasks", "Task"),
                        SizedBox(height: 5),
                        _buildHorizontalTaskList(),
                      ],
                    ),
                  ),
                ),

                // My Requests Section
                Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("My Requests"),
                        SizedBox(height: 5),
                        _buildRequestCard(
                            "22 Aug 2024 - 25 Aug 2024", "Leave Request"),
                        SizedBox(height: 10),
                        _buildRequestCard("22 Aug 2024", "Day Off"),
                      ],
                    ),
                  ),
                ),

                // Track Attendance Section with Chart
                Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeaderWithLink(
                            "Track Attendance", "Attendance"),
                        SizedBox(height: 5),
                        FutureBuilder<List<dynamic>>(
                          future:
                              _attendanceFuture, // <-- yahan function call ki jagah variable use karein
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Column(
                                children: [
                                  Text('Error: ${snapshot.error}'),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _attendanceFuture =
                                            fetchAttendanceRecords(); // retry on error
                                      });
                                    },
                                    child: Text('Retry'),
                                  ),
                                ],
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              return Text('No attendance records found');
                            } else {
                              return _buildAttendanceCardWithData(
                                  snapshot.data!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Approval Requests Section
                Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Approval Requests"),
                        SizedBox(height: 5),
                        FutureBuilder<Map<String, List<dynamic>>>(
                          future: _workflowActionsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (!snapshot.hasData) {
                              return Text('No workflow actions found');
                            } else {
                              final sent = snapshot.data!['sent']!;
                              final toApprove = snapshot.data!['toApprove']!;
                              Color getStatusColor(String? status) {
                                switch ((status ?? '').toLowerCase()) {
                                  case 'pending':
                                    return Colors.orange;
                                  case 'completed':
                                    return Colors.green;
                                  case 'open':
                                    return Colors.blue;
                                  case 'rejected':
                                    return Colors.red;
                                  default:
                                    return Colors.grey;
                                }
                              }

                              Widget buildActionCard(dynamic action,
                                  {bool isSent = false}) {
                                return Card(
                                  color: Colors.white,
                                  margin: EdgeInsets.symmetric(vertical: 6),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // CircleAvatar(
                                        //   backgroundColor: isSent
                                        //       ? Colors.blue[50]
                                        //       : Colors.green[50],
                                        //   child: Icon(
                                        //     isSent ? Icons.send : Icons.approval,
                                        //     color: isSent ? Colors.blue : Colors.green,
                                        //   ),
                                        // ),
                                        SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${action['reference_doctype'] ?? ''}: ${action['reference_name'] ?? ''}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: getStatusColor(action[
                                                              'workflow_state'])
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      "${action['workflow_state'] ?? ''}",
                                                      style: TextStyle(
                                                        color: getStatusColor(
                                                            action[
                                                                'workflow_state']),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Icon(Icons.calendar_today,
                                                      size: 13,
                                                      color: Colors.grey[500]),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    "${action['creation'].toString().substring(0, 10)}",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                              if (action['status'] != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: Text(
                                                    "Status: ${action['status']}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: getStatusColor(
                                                          action['status']),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(height: 6),
                                              // Row(
                                              //   children: [
                                              //     ElevatedButton.icon(
                                              //       onPressed: () {
                                              //         // TODO: Navigate to details page if needed
                                              //       },
                                              //       icon: Icon(Icons.visibility,
                                              //           size: 16),
                                              //       label: Text("View Details",
                                              //           style: TextStyle(fontSize: 12)),
                                              //       style: ElevatedButton.styleFrom(
                                              //         backgroundColor: Colors.grey[200],
                                              //         foregroundColor: Colors.black87,
                                              //         elevation: 0,
                                              //         padding: EdgeInsets.symmetric(
                                              //             horizontal: 10, vertical: 4),
                                              //         shape: RoundedRectangleBorder(
                                              //           borderRadius:
                                              //               BorderRadius.circular(8),
                                              //         ),
                                              //       ),
                                              //     ),
                                              //   ],
                                              // ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TabBar(
                                          labelColor: Colors.white,
                                          unselectedLabelColor: Colors.black87,
                                          labelStyle: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                          unselectedLabelStyle: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13),
                                          indicator: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          indicatorSize:
                                              TabBarIndicatorSize.tab,
                                          tabs: [
                                            Tab(text: "Sent"),
                                            Tab(text: "To Approve"),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height:
                                            220, // Set height as per your card size
                                        child: TabBarView(
                                          children: [
                                            // Sent Tab
                                            sent.isNotEmpty
                                                ? ListView.builder(
                                                    itemCount: sent.length,
                                                    itemBuilder:
                                                        (context, idx) =>
                                                            buildActionCard(
                                                                sent[idx],
                                                                isSent: true),
                                                  )
                                                : Center(
                                                    child: Text(
                                                        "No sent requests.",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.grey)),
                                                  ),
                                            // To Approve Tab
                                            toApprove.isNotEmpty
                                                ? ListView.builder(
                                                    itemCount: toApprove.length,
                                                    itemBuilder:
                                                        (context, idx) =>
                                                            buildActionCard(
                                                                toApprove[idx],
                                                                isSent: false),
                                                  )
                                                : Center(
                                                    child: Text(
                                                        "No requests to approve.",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.grey)),
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Greeting Section
  Widget _buildGreetingSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_getGreetingMessage()}",
              style: TextStyle(
                  fontSize: 14, color: Colors.grey), // Font size adjusted
            ),
            Text(
              userdata['employee_name'] ?? 'Unknown Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeProfileScreen(
                    employeeId: '',
                  ),
                ));
          },
          borderRadius: BorderRadius.circular(30), // Adjust the border radius
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[400],
            child: Icon(Icons.person, color: Colors.white),
          ),
        )
      ],
    );
  }

  // Shift Timer Section
  Widget _buildShiftTimerSection(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width, // 100% width
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Started Your Shift at ${checkInTime}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${duration}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/checkin');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Check Out",
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
          SizedBox(height: 8),
          // ElevatedButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => FrappeCrudForm(
          //           doctype: 'Employee',
          //           docname: 'HR-EMP-00001',
          //           baseUrl: 'http://localhost:8000',
          //         ),
          //       ),
          //     );
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.black,
          //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(10),
          //     ),
          //   ),
          //   child: Text(
          //     "Doctype Form",
          //     style: TextStyle(fontSize: 14, color: Colors.white),
          //   ),
          // ),
          // ElevatedButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => DoctypeListView(doctype: 'Employee')),
          //     );
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.black,
          //     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(10),
          //     ),
          //   ),
          //   child: Text(
          //     "Doctype List",
          //     style: TextStyle(fontSize: 14, color: Colors.white),
          //   ),
          // ),
          // SizedBox(height: 8),
          // Text(
          //   "09:00 AM to 06:00 PM",
          //   style: TextStyle(
          //     fontSize: 12,
          //     fontWeight: FontWeight.w400,
          //     color: Colors.grey,
          //   ),
          // ),
        ],
      ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold), // Font size adjusted
        ),
        InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ApprovalRequestScreen(),
                ));
          },
          child: Text(
            "See all",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(201, 1, 79, 249),
            ),
          ),
        ),
      ],
    );
  }

  // Section Header
  Widget _buildSectionHeaderWithLink(String title, doctype) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold), // Font size adjusted
        ),
        InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctypeListView(
                    doctype: doctype,
                    prefilters: null,
                  ),
                ));
          },
          child: Text(
            "See all",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(201, 1, 79, 249),
            ),
          ),
        ),
      ],
    );
  }

// Task Card Widget
  Widget _buildTaskCard(task) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FrappeCrudForm(
                doctype: "Task",
                docname: task['name'],
                baseUrl: 'http://localhost:8000',
              ),
            ));
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.white, // Set background color to white
        elevation: 3, // Slight elevation for shadow
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row with Badges for Status and Priority
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: task['status'] == "Completed"
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task['status'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: task['status'] == "Completed"
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                  // Priority Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: task['priority'] == "High"
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task['priority'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: task['priority'] == "High"
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Task Title
              Text(
                "created by ${task['created_by'] ?? ''}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                task['description'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              // Task Description
              Text(
                task['title'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              // Date and Time Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task['modified'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  // Row(
                  //   children: [
                  //     Icon(Icons.access_time, size: 14, color: Colors.grey),
                  //     SizedBox(width: 5),
                  //     Text(
                  //       "created by ${task['created_by'] ?? ''}",
                  //       style: TextStyle(
                  //         fontSize: 12,
                  //         color: Colors.grey,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Horizontal Task List
  Widget _buildHorizontalTaskList() {
    // List of tasks with title, description, status, and priority
    final List tasks = homePageSectionData[0]['tasks'] ?? [];

    return SizedBox(
      height: 140, // Fixed height for the horizontal scroll view
      child: tasks.length > 0
          ? ListView.builder(
              scrollDirection: Axis.horizontal, // Enable horizontal scrolling
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(
                      left: 4.0, right: 4.0), // Add spacing between cards
                  child: SizedBox(
                    width: 300, // Fixed width for each task card
                    child: _buildTaskCard(task),
                  ),
                );
              },
            )
          : Text('No Data Available'),
    );
  }

// Request Card
  Widget _buildRequestCard(String date, String type) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white, // Set the background color to white
      elevation: 3, // Optional: Add elevation for shadow effect
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold), // Font size adjusted
                ),
                SizedBox(height: 5),
                Text(
                  type,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey), // Font size adjusted
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white, // Set the background color to white
      elevation: 3, // Optional: Add elevation for shadow effect
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align everything to the top
          children: [
            // Donut Chart
            SizedBox(
              width: 170,
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 5,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      value: 8,
                      color: Colors.green,
                      radius: 50,
                      title: 'On Time',
                      titleStyle: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: 8,
                      color: Colors.red,
                      radius: 50,
                      title: 'Absent',
                      titleStyle: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: 8,
                      color: Colors.orange,
                      radius: 50,
                      title: 'Late',
                      titleStyle: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(width: 20), // Space between the chart and details

            // Attendance Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttendanceDetail(
                    color: Colors.green,
                    label: "On Time",
                    count: 8,
                  ),
                  SizedBox(height: 10),
                  _buildAttendanceDetail(
                    color: Colors.red,
                    label: "Absent",
                    count: 8,
                  ),
                  SizedBox(height: 10),
                  _buildAttendanceDetail(
                    color: Colors.orange,
                    label: "Late",
                    count: 8,
                  ),
                  SizedBox(height: 10),
                  Divider(),
                  SizedBox(height: 10),
                  _buildAttendanceDetail(
                    color: Colors.blueGrey,
                    label: "Total Days",
                    count: 24,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Attendance Detail Item
  Widget _buildAttendanceDetail({
    required Color color,
    required String label,
    required int count,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          "$count",
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildGridSection(BuildContext context) {
    // Sample data for the grid items
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

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 80, // Fixed height for horizontal scrolling
        child: ListView.builder(
          scrollDirection: Axis.horizontal, // Enable horizontal scrolling
          itemCount: gridItems.length,
          itemBuilder: (context, index) {
            final item = gridItems[index];
            return GestureDetector(
              onTap: item["onPressed"], // Handle the tap event
              child: Container(
                width: 80, // Width of each item
                margin:
                    const EdgeInsets.only(right: 10.0), // Space between items
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.black,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        item["icon"],
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    // Label
                    Text(
                      item["label"],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

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

  final List<Map<String, dynamic>> managementItems = [
    {
      "icon": Icons.beach_access,
      "label": "Holiday",
      "onPressed": () => print("Holiday Pressed")
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
  ];

  final List<Map<String, dynamic>> otherItems = [
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
  ];

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('Sectioned Grid Example'),
  //     ),
  //     body: Container(
  //       color: Colors.white,
  //       child: ListView(
  //         children: [
  //           _buildSection("Expenses", expenseItems),
  //           _buildSection("Management", managementItems),
  //           _buildSection("Other Tools", otherItems),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildSection(String title, items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              // crossAxisSpacing: 10,
              // mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                // onTap: item['onPressed'],
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
                  // decoration: BoxDecoration(
                  //   color: Colors.blue.shade100,
                  //   borderRadius: BorderRadius.circular(10),
                  //   boxShadow: [
                  //     BoxShadow(
                  //       color: Colors.grey.shade300,
                  //       blurRadius: 4,
                  //       offset: Offset(2, 2),
                  //     ),
                  //   ],
                  // ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon(
                      //   item['icon'] as IconData ?? Icons.shopping_cart,
                      //   size: 25,
                      //   color: const Color.fromARGB(255, 3, 3, 3),
                      // ),
                      Container(
                        width: 50.0, // Set your desired width
                        height: 50.0, // Set your desired height
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, // Make the container circular
                          border: Border.all(
                            color: Colors.black, // Set the border color
                            width: 0.5, // Set the border width
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: 'http://localhost:8000${item['image']}',
                            placeholder: (context, url) =>
                                CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error),
                            fit: BoxFit
                                .cover, // This will ensure the image covers the circular area
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

    // Use a list of distinct colors for each status
    final List<Color> colorPalette = [
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
      Colors.deepPurple,
      Colors.lightBlue,
    ];

    // Assign a color to each status
    Map<String, Color> statusColors = {};
    int colorIndex = 0;
    for (var status in statusCounts.keys) {
      statusColors[status] = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Donut Chart
            SizedBox(
              width: 170,
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 5,
                  centerSpaceRadius: 30,
                  sections: statusCounts.entries.map((entry) {
                    final color = statusColors[entry.key]!;
                    // Responsive font size: bigger for larger values
                    final double fontSize =
                        (entry.value / total * 18).clamp(10, 16);

                    String title = entry.key;
                    if (title.length > 8) {
                      title = title.substring(0, 8) + '...';
                    }
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: color,
                      radius: 50,
                      title: title,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(width: 20),
            // Attendance Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...statusCounts.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildAttendanceDetail(
                          color: statusColors[entry.key]!,
                          label: entry.key,
                          count: entry.value,
                        ),
                      )),
                  Divider(),
                  SizedBox(height: 10),
                  _buildAttendanceDetail(
                    color: Colors.blueGrey,
                    label: "Total Days",
                    count: total,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, List<dynamic>>> fetchWorkflowActions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId =
        prefs.getString('user_name'); // Store user_id in prefs at login

    // 1. Actions you need to approve
    final toApproveUrl = Uri.parse(
        'http://localhost:8000/api/resource/Workflow Action'
        '?fields=["name","workflow_state","creation","reference_name","reference_doctype","owner","user","status"]'
        '&order_by=creation desc'
        '&limit_page_length=2');

    // 2. Actions you have initiated (sent)
    final sentUrl = Uri.parse(
        'http://localhost:8000/api/resource/Workflow Action'
        '?fields=["name","workflow_state","creation","reference_name","reference_doctype","owner","user","status"]'
        '&order_by=creation desc'
        '&limit_page_length=2');

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

    if (toApproveResponse.statusCode == 200 && sentResponse.statusCode == 200) {
      final toApproveData = jsonDecode(toApproveResponse.body)['data'];
      final sentData = jsonDecode(sentResponse.body)['data'];
      return {
        'toApprove': toApproveData,
        'sent': sentData,
      };
    } else {
      throw Exception('Failed to load workflow actions');
    }
  }
}
