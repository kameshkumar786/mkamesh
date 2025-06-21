import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/services/frappe_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeProfileScreen({super.key, required this.employeeId});

  @override
  _EmployeeProfileScreenState createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  Map<String, dynamic>? employeeData;
  bool isLoading = true;
  String? errorMessage;

  // Theme Colors
  static const Color primaryColor = Colors.black;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1E293B);
  static const Color textSecondaryColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    fetchEmployeeData();
  }

  Future<void> fetchEmployeeData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? userId = prefs.getString('user_name');

      if (token == null || userId == null) {
        throw Exception('Authentication data not found');
      }

      final url = Uri.parse(
          '${FrappeService.baseUrl}/api/resource/Employee?filters=[["user_id","=","$userId"]]&fields=${jsonEncode([
            "*"
          ])}');

      final response = await http.get(
        url,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
      );
      print(json.decode(response.body));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          setState(() {
            employeeData = data['data'][0];
            isLoading = false;
          });
        } else {
          throw Exception('No employee data found');
        }
      } else {
        throw Exception('Failed to load employee data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching employee data: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableFields = employeeData ?? {};
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        foregroundColor: textPrimaryColor,
        surfaceTintColor: cardColor,
        scrolledUnderElevation: 0,
        title: Text(
          'Employee Profile',
          style: TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh, color: primaryColor),
        //     onPressed: fetchEmployeeData,
        //   ),
        // ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load profile',
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchEmployeeData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchEmployeeData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Header
                        Container(
                          margin: EdgeInsets.all(16),
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: primaryColor.withOpacity(0.08),
                                child: (() {
                                  final img = availableFields['image'];
                                  final hasImage = img != null &&
                                      img is String &&
                                      img.isNotEmpty;
                                  if (hasImage) {
                                    final imageUrl = img.startsWith('http')
                                        ? img
                                        : 'http://localhost:8000$img';
                                    return ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            CircularProgressIndicator(
                                          color: primaryColor,
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Icon(
                                          Icons.person,
                                          size: 48,
                                          color: primaryColor,
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Icon(
                                      Icons.person,
                                      size: 48,
                                      color: primaryColor,
                                    );
                                  }
                                })(),
                              ),
                              SizedBox(height: 12),
                              Text(
                                availableFields['employee_name'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                availableFields['designation'] ?? 'none',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textSecondaryColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  availableFields['status'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _sectionCard(
                          context,
                          icon: Icons.person,
                          title: 'Personal Information',
                          children: [
                            _infoTile(Icons.badge, 'Employee ID',
                                availableFields['name']),
                            _infoTile(Icons.cake, 'Date of Birth',
                                availableFields['date_of_birth']),
                            _infoTile(
                                Icons.wc, 'Gender', availableFields['gender']),
                            _infoTile(Icons.bloodtype, 'Blood Group',
                                availableFields['blood_group']),
                            _infoTile(Icons.family_restroom, 'Marital Status',
                                availableFields['marital_status']),
                            _infoTile(Icons.flag, 'Nationality',
                                availableFields['nationality']),
                          ],
                        ),
                        // Always show Contact Information section

                        _sectionCard(
                          context,
                          icon: Icons.email,
                          title: 'Contact Information',
                          children: [
                            _infoTile(Icons.email, 'Company Email',
                                availableFields['company_email'] ?? 'N/A',
                                forceShow: true),
                            _infoTile(Icons.alternate_email, 'Personal Email',
                                availableFields['personal_email'] ?? 'N/A',
                                forceShow: true),
                            _infoTile(Icons.phone, 'Phone',
                                availableFields['cell_number'] ?? 'N/A',
                                forceShow: true),
                            _infoTile(
                                Icons.contact_phone,
                                'Emergency Contact',
                                availableFields['emergency_phone_number'] ??
                                    'N/A',
                                forceShow: true),
                          ],
                        ),

                        _sectionCard(
                          context,
                          icon: Icons.business_center,
                          title: 'Work Information',
                          children: [
                            _infoTile(Icons.apartment, 'Department',
                                availableFields['department']),
                            _infoTile(Icons.business, 'Company',
                                availableFields['company']),
                            _infoTile(Icons.location_city, 'Branch',
                                availableFields['branch']),
                            _infoTile(Icons.calendar_today, 'Date of Joining',
                                availableFields['date_of_joining']),
                            _infoTile(
                                Icons.supervisor_account,
                                'Reporting Manager',
                                availableFields['reports_to']),
                          ],
                        ),
                        _sectionCard(
                          context,
                          icon: Icons.home,
                          title: 'Address Information',
                          children: [
                            _infoTile(Icons.home, 'Current Address',
                                availableFields['current_address']),
                            _infoTile(Icons.home_outlined, 'Permanent Address',
                                availableFields['permanent_address']),
                          ],
                        ),
                        _sectionCard(
                          context,
                          icon: Icons.account_balance,
                          title: 'Bank Information',
                          children: [
                            _infoTile(Icons.account_balance, 'Bank Name',
                                availableFields['bank_name']),
                            _infoTile(
                                Icons.account_balance_wallet,
                                'Account Number',
                                availableFields['bank_ac_no']),
                            _infoTile(Icons.qr_code, 'IFSC Code',
                                availableFields['ifsc_code']),
                          ],
                        ),
                        _sectionCard(
                          context,
                          icon: Icons.credit_card,
                          title: 'Document Information',
                          children: [
                            _infoTile(Icons.credit_card, 'PAN Number',
                                availableFields['pan_number']),
                            _infoTile(Icons.credit_card, 'Aadhaar Number',
                                availableFields['aadhaar_number']),
                          ],
                        ),
                        if (availableFields.isNotEmpty)
                          // _sectionCard(
                          //   context,
                          //   icon: Icons.info_outline,
                          //   title: 'Other Information',
                          //   children: availableFields.entries
                          //       .where((e) =>
                          //           !_shownKeys.contains(e.key) &&
                          //           e.value != null &&
                          //           e.value.toString().isNotEmpty)
                          //       .map((e) => _infoTile(Icons.info_outline, e.key,
                          //           e.value.toString()))
                          //       .toList(),
                          // ),
                          SizedBox(height: 24),
                        // Logout Button at the bottom
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32.0, vertical: 8),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.logout, color: Colors.white),
                            label: Text('Logout',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();
                              if (mounted) {
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  // Helper for section cards
  Widget _sectionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    if (children.isEmpty) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  // Helper for info rows
  Widget _infoTile(IconData icon, String label, dynamic value,
      {bool forceShow = false}) {
    if (!forceShow && (value == null || value.toString().isEmpty))
      return SizedBox.shrink();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(icon, color: Colors.grey[700], size: 20),
      title: Text(
        label,
        style: TextStyle(
            fontSize: 13,
            color: textSecondaryColor,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        (value == null || value.toString().isEmpty) ? 'N/A' : value.toString(),
        style: TextStyle(
            fontSize: 14, color: textPrimaryColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Keys already shown in sections
  static const Set<String> _shownKeys = {
    'image',
    'employee_name',
    'designation',
    'status',
    'company_email',
    'personal_email',
    'cell_number',
    'emergency_phone_number',
    'name',
    'date_of_birth',
    'gender',
    'blood_group',
    'marital_status',
    'nationality',
    'department',
    'company',
    'branch',
    'date_of_joining',
    'reports_to',
    'current_address',
    'permanent_address',
    'bank_name',
    'bank_ac_no',
    'ifsc_code',
    'pan_number',
    'aadhaar_number',
  };
}
