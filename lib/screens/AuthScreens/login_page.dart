import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../services/frappe_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false; // Toggle to show/hide password
  String? _errorMessage; // Error message for wrong password
  final FrappeService _frappeService = FrappeService();

  void _login() async {
    setState(() {
      _isLoading = true; // Start loading
      _errorMessage = null; // Reset error message
    });

    try {
      // Attempt login
      bool success = await _frappeService.login(
        context,
        _emailController.text,
        _passwordController.text,
      );

      if (success) {
        // Fetch user data and store locally
        await _frappeService.fetchUserData();

        OneSignal.login(_emailController.text);
        OneSignal.User.addEmail(_emailController.text);
        // OneSignal.User.addSms("+11234567890");

        // Navigate to home page if login is successful
        Navigator.pushReplacementNamed(context, '/checkin');
      } else {
        setState(() {
          _errorMessage = 'Invalid email or password'; // Show error message
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}'; // Show error message
      });
    } finally {
      setState(() {
        _isLoading = false; // Stop loading spinner
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Center top logo
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0), // Adjust top padding
                child: Column(
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logo.png', // Replace with your logo's asset path
                      height: 100, // Set logo height
                      width: 100, // Set logo width
                      fit: BoxFit.contain, // Ensure it fits the available space
                    ),
                    const SizedBox(height: 10), // Space between logo and text
                    // Text below the logo
                    const Text(
                      'Welcome to Our App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const Text(
                      'Enter tour login details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Enter Email OR Username',
                labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
                hintText: 'Enter Email or Username',
                hintStyle: const TextStyle(
                    fontSize: 14, color: Colors.grey), // Placeholder font size

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), // Rounded corners
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Enter Your Password',
                labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
                hintText: '********',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
              style: const TextStyle(fontSize: 13, color: Colors.black),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/forgot_password');
              },
              child: const Text(
                'Forgot Password',
                style: TextStyle(color: Color.fromARGB(255, 241, 2, 2)),
              ),
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 5),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity, // Full width of the parent
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16), // Medium height
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(25), // Rounded corners
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 10), // Space between the buttons

            SizedBox(
              width: double.infinity, // Full width of the parent
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text('Create A New Account'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black, // Text color
                  backgroundColor: Colors.white, // Button background color
                  elevation: 0, // Remove shadow
                  side: const BorderSide(
                      color: Colors.black, width: 1), // Border color and width
                  padding:
                      const EdgeInsets.symmetric(vertical: 16), // Medium height
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25), // Rounded corners
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
