import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrappeService {
  static const String baseUrl = 'https://uatss.erpdesks.com';
  static const String baseUrl1 = 'https://uatss.erpdesks.com/api/method';
  static const String baseUrl2 = 'https://uatss.erpdesks.com/api/resource';

  // Store cookies locally for reuse
  Future<void> _saveCookies(String cookies) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  // Retrieve stored cookies
  Future<String?> _getCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies');
  }

  // Login function
  Future<bool> login(String email, String password) async {
    String url = '$baseUrl1/login';

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

        if (responseData['message'] == 'Logged In') {
          // Save cookies from headers
          String? rawCookie = response.headers['set-cookie'];
          if (rawCookie != null) {
            await _saveCookies(rawCookie); // Store cookies locally
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          // Save important details
          await prefs.setString('full_name', responseData['full_name']);
          await prefs.setString('home_page', responseData['home_page']);

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
  Future<String?> getLoggedUser() async {
    String url = '$baseUrl1/frappe.auth.get_logged_user';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookies, // Add cookies to request headers
        },
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('userid', json.encode(responseData['message']));
        return responseData['message']; // Return the logged-in user
      } else {
        throw Exception('Failed to get logged user.');
      }
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  // Fetch the user doctype data after login and store locally
  Future<void> fetchUserData() async {
    String url = '$baseUrl2/Employee';

    try {
      String? cookies = await _getCookies();
      if (cookies == null) {
        throw Exception('No authentication cookies found.');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookies, // Add cookies to request headers
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

  // Logout function to clear user data
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved user data
  }
}
