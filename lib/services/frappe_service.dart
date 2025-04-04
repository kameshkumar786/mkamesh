import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/services/showErrorDialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrappeService {
  static const String baseUrl = 'http://localhost:8000';
  static const String baseUrl1 = 'http://localhost:8000/api/method';
  static const String baseUrl2 = 'http://localhost:8000/api/resource';

  // Retrieve stored cookies
  Future<String?> _getCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      await logout();
      return null;
    }
    return token;
  }

  Future<bool> login(
      BuildContext context, String email, String password) async {
    // String url = '$baseUrl1/login';
    String url = '$baseUrl1/rishta.rishtavishta_api.login_user';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'usr': email,
          'pwd': password,
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        print('${responseData['message']}');

        if (responseData['message']['status']) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'user_name', responseData['message']['data']['user']);
          await prefs.setString(
              'token', '${responseData['message']['data']['token']}');
          return true;
        } else {
          showErrorDialog(context, 'Login failed. Please try again.');
          return false;
        }
      } else {
        showErrorDialog(context, 'Server error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      showErrorDialog(context, 'An error occurred: ${e.toString()}');
      return false;
    }
  }

  // Signup function
  Future<bool> signup(String username, String email, String password) async {
    String url = '$baseUrl1/chat_signup';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': username,
          'password': password,
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        if (responseData['message'] == 'Logged In') {
          return true;
        } else {
          return false; // Login failed
        }
      } else {
        throw Exception('Login failed: Invalid credentials or server error.');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Function to check if the user is logged in
  // Function to check if the user is logged in
  Future<String?> getLoggedUser() async {
    String url = '$baseUrl1/frappe.auth.get_logged_user';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('getLoggedUser No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies, // Add cookies to request headers
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('userid', json.encode(responseData['message']));
        return responseData['message']; // Return the logged-in user
      } else {
        var responseData = json.decode(response.body);
        print(
            'Error response: $responseData'); // Log error details for debugging
        return null; // Explicitly return null if the status code is not 200
      }
    } catch (e) {
      print('Error in getLoggedUser: ${e.toString()}'); // Log the error
      return null; // Return null if an exception occurs
    }
  }

  Future<String?> reset_password() async {
    String url = '$baseUrl1/frappe.auth.get_logged_user';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('reset_password No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies, // Add cookies to request headers
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('userid', json.encode(responseData['message']));
        return responseData['message']; // Return the logged-in user
      } else {
        var responseData = json.decode(response.body);
        print(
            'Error response: $responseData'); // Log error details for debugging
        return null; // Explicitly return null if the status code is not 200
      }
    } catch (e) {
      print('Error in getLoggedUser: ${e.toString()}'); // Log the error
      return null; // Return null if an exception occurs
    }
  }

  // Fetch the user doctype data after login and store locally
  Future<void> fetchUserData() async {
    String url = '$baseUrl1/employee_details';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('fetchUserData No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies, // Add cookies to request headers
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        if (responseData['message']['status']) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          // Save user data locally (assuming user data is in the 'data' field)
          await prefs.setString(
              'user_data', json.encode(responseData['message']['data']));
          // print('userdata :$responseData');
        } else {
          throw Exception(
              'Failed to fetch user data. ${responseData['message']['message']}');
        }
      } else {
        var responseData = json.decode(response.body);

        throw Exception('Failed to fetch user data. $responseData');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  Future<void> Chat_fetchchatUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('userid');

    String url = '$baseUrl2/User/$email';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception(
            'Chat_fetchchatUserData No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies, // Add cookies to request headers
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        // Save user data locally (assuming user data is in the 'data' field)
        await prefs.setString('user_data', json.encode(responseData['data']));
        print('userdata :$responseData');
      } else {
        var responseData = json.decode(response.body);

        throw Exception('Failed to fetch user data. $responseData');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Fetch timesheets created by the user
  Future<List<dynamic>> get_all(
      String doctype, List filters, List fields) async {
    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('fetchUserData No authentication cookies found.');
      }
      print('$baseUrl/$doctype?filters=${(filters)}&fields=${(fields)}' as Uri);
      final response = await http.get(
        '$baseUrl/$doctype?filters=${(filters)}&fields=${(fields)}' as Uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']; // List of items
      } else {
        // Handle different status codes
        switch (response.statusCode) {
          case 400:
            throw Exception('Bad Request: ${response.body}');
          case 401:
            throw Exception('Unauthorized: ${response.body}');
          case 403:
            throw Exception('Forbidden: ${response.body}');
          case 404:
            throw Exception('Not Found: ${response.body}');
          case 500:
            throw Exception('Internal Server Error: ${response.body}');
          default:
            throw Exception(
                'Failed to load data: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      // Handle any other errors (e.g., network issues, JSON parsing errors)
      print('Error occurred: $e');
      throw Exception('An error occurred: $e');
    }
  }

  // Fetch timesheets created by the user
  Future<List<dynamic>> new_doc(String doctype, Object req) async {
    final response =
        await http.post(Uri.parse('$baseUrl2/$doctype?'), body: req);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']; // List of timesheets
    } else {
      throw Exception('Failed to load timesheets');
    }
  }

  Future<dynamic> CheckIn(Object req) async {
    String url = '$baseUrl1/employee_checkin';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('No authentication cookies found.');
      }

      final response = await http.post(
        Uri.parse(url),
        body: json.encode(req), // Ensure the body is properly encoded
        headers: {
          'Content-Type': 'application/json',
          'Authorization': cookies,
        },
      );

      var responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        print('Check-in successful: $responseData');
        return responseData; // Return the decoded response
      } else {
        print('Check-in failed: $responseData');
        return responseData; // Return error response for further handling
      }
    } catch (e) {
      print('Error during check-in: $e');
      throw Exception('Error: ${e.toString()}');
    }
  }

  Future<dynamic> getLastCheckIn() async {
    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('No authentication cookies found.');
      }
      final response = await http.get(
        Uri.parse('$baseUrl1/employee_checkin_status'),
        headers: {'Authorization': cookies},
      );
      return json.decode(response.body);
    } catch (e) {
      print('Error during check-in: $e');
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Logout function to clear user data
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved user data
  }

  Future<List<dynamic>> fetchReportData() async {
    String? cookies = await _getCookies();
    if (cookies == null) {
      throw Exception('No authentication cookies found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/resource/Sales Invoice?fields=["name","total"]'),
      headers: {'Authorization': cookies},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<List<dynamic>> fetchReportScript(String reportName) async {
    String? cookies = await _getCookies();
    if (cookies == null) {
      throw Exception('No authentication cookies found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl1/frappe.desk.query_report.get_script'),
      headers: {'Authorization': cookies},
      body: {'report_name': reportName},
    );

    if (response.statusCode == 200) {
      // print(jsonDecode(response.body)['message']);
      return jsonDecode(response.body)['message'];
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<Map<String, dynamic>> runReport(
      String reportName, Map<String, dynamic> filters) async {
    String? cookies = await _getCookies();
    if (cookies == null) {
      throw Exception('No authentication cookies found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/method/frappe.desk.query_report.run'),
      headers: {'Authorization': cookies},
      body: jsonEncode({
        'report_name': reportName,
        'filters': filters,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to run report: ${response.statusCode}');
    }
  }
}
