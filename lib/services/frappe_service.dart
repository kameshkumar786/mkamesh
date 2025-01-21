import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/services/showErrorDialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrappeService {
  static const String baseUrl = 'https://teamloser.in';
  static const String baseUrl1 = 'https://teamloser.in/api/method';
  static const String baseUrl2 = 'https://teamloser.in/api/resource';

  // Retrieve stored cookies
  Future<String?> _getCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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

  // Fetch the user doctype data after login and store locally
  Future<void> fetchUserData() async {
    String url = '$baseUrl1/employee_details';

    try {
      String? cookies = await _getCookies();
      // print('cookies :$cookies');

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
      String doctye, String filters, String fields) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$doctye?filters=$filters&fields=$fields'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']; // List of timesheets
    } else {
      throw Exception('Failed to load timesheets');
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
}
