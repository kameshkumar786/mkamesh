import 'package:flutter/material.dart';

class GroupCreationPage extends StatefulWidget {
  final Function(String groupName) onCreateGroup;

  GroupCreationPage({required this.onCreateGroup});

  @override
  _GroupCreationPageState createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Group"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Group Name"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onCreateGroup(_controller.text.trim());
                Navigator.pop(context);
              },
              child: Text("Create Group"),
            ),
          ],
        ),
      ),
    );
  }
}
