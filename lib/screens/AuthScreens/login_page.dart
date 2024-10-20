import 'package:flutter/material.dart';
import '../../services/frappe_service.dart';

class LoginPage extends StatefulWidget {
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
        _emailController.text,
        _passwordController.text,
      );

      if (success) {
        // Fetch user data and store locally
        await _frappeService.fetchUserData();

        // Navigate to home page if login is successful
        Navigator.pushReplacementNamed(context, '/home');
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword, // Toggle password visibility
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword =
                          !_showPassword; // Toggle show/hide password
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            // Show error message below the password field if there's an error
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                  ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                  },
                  child: Text('Sign Up'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot_password');
                  },
                  child: Text('Forgot Password'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
