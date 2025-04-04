import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/services/frappe_service.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeProfileScreen({super.key, required this.employeeId});

  @override
  _EmployeeProfileScreenState createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  Map<String, dynamic>? employeeData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmployeeData();
  }

  Future<void> fetchEmployeeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    final url = Uri.parse(
        '${FrappeService.baseUrl}/api/resource/Employee/HR-EMP-00001');
    final response = await http.get(url, headers: {
      'Authorization': '$token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      setState(() {
        employeeData = json.decode(response.body)['data'];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Profile',
            style: Theme.of(context).textTheme.titleLarge),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : employeeData == null
              ? const Center(child: Text('Failed to load employee data'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: employeeData!['image'] != null
                              ? NetworkImage(employeeData!['image'])
                              : null,
                          child: employeeData!['image'] == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Name: ${employeeData!['employee_name']}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Designation: ${employeeData!['designation']}',
                          style: const TextStyle(fontSize: 14)),
                      Text('Department: ${employeeData!['department']}',
                          style: const TextStyle(fontSize: 14)),
                      Text('Email: ${employeeData!['company_email']}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Phone: ${employeeData!['cell_number'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 13)),
                      Text(
                          'Date of Joining: ${employeeData!['date_of_joining']}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
    );
  }
}
