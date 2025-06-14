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
    String? user_id = prefs.getString('user_name');
    final url = Uri.parse(
        '${FrappeService.baseUrl}/api/resource/Employee?filters={user_id=${user_id}}&fields=${jsonEncode([
          "*"
        ])}');
    final response = await http.get(url, headers: {
      'Authorization': '$token',
      'Content-Type': 'application/json',
    });
    print(url);
    print(response.statusCode);
    print(response.body);

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

  Widget _buildProfileRow(String label, String? value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 18, color: Colors.black54),
          if (icon != null) SizedBox(width: 8),
          Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
                      _buildProfileRow('Employee ID', employeeData!['name'],
                          icon: Icons.badge),
                      _buildProfileRow('Status', employeeData!['status'],
                          icon: Icons.verified_user),
                      _buildProfileRow('Company', employeeData!['company'],
                          icon: Icons.business),
                      _buildProfileRow(
                          'Department', employeeData!['department'],
                          icon: Icons.apartment),
                      _buildProfileRow('Branch', employeeData!['branch'],
                          icon: Icons.location_city),
                      _buildProfileRow(
                          'Date of Joining', employeeData!['date_of_joining'],
                          icon: Icons.calendar_today),
                      _buildProfileRow(
                          'Date of Birth', employeeData!['date_of_birth'],
                          icon: Icons.cake),
                      _buildProfileRow('Gender', employeeData!['gender'],
                          icon: Icons.wc),
                      _buildProfileRow(
                          'Blood Group', employeeData!['blood_group'],
                          icon: Icons.bloodtype),
                      _buildProfileRow(
                          'Reporting Manager', employeeData!['reports_to'],
                          icon: Icons.supervisor_account),
                      _buildProfileRow('Email', employeeData!['company_email'],
                          icon: Icons.email),
                      _buildProfileRow(
                          'Personal Email', employeeData!['personal_email'],
                          icon: Icons.alternate_email),
                      _buildProfileRow('Phone', employeeData!['cell_number'],
                          icon: Icons.phone),
                      _buildProfileRow('Emergency Contact',
                          employeeData!['emergency_phone_number'],
                          icon: Icons.contact_phone),
                      _buildProfileRow(
                          'Current Address', employeeData!['current_address'],
                          icon: Icons.home),
                      _buildProfileRow('Permanent Address',
                          employeeData!['permanent_address'],
                          icon: Icons.home_outlined),
                      _buildProfileRow(
                          'Nationality', employeeData!['nationality'],
                          icon: Icons.flag),
                      _buildProfileRow(
                          'Marital Status', employeeData!['marital_status'],
                          icon: Icons.family_restroom),
                      _buildProfileRow('PAN', employeeData!['pan_number'],
                          icon: Icons.credit_card),
                      _buildProfileRow(
                          'Aadhaar', employeeData!['aadhaar_number'],
                          icon: Icons.credit_card),
                      _buildProfileRow('Bank Name', employeeData!['bank_name'],
                          icon: Icons.account_balance),
                      _buildProfileRow(
                          'Bank Account', employeeData!['bank_ac_no'],
                          icon: Icons.account_balance_wallet),
                      _buildProfileRow('IFSC', employeeData!['ifsc_code'],
                          icon: Icons.qr_code),
                    ],
                  ),
                ),
    );
  }
}
