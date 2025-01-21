import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  final String username;
  final String email;
  final bool isOnline;

  UserProfilePage({
    required this.username,
    required this.email,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueGrey,
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text("Username: $username", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Email: $email", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text(
              "Status: ${isOnline ? "Online" : "Offline"}",
              style: TextStyle(
                  fontSize: 18, color: isOnline ? Colors.green : Colors.red),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                // Add edit profile functionality here
              },
              child: Text("Edit Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
