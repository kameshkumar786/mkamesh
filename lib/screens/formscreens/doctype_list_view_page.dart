import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DocTypeListViewPage extends StatefulWidget {
  final String docTypeName;

  DocTypeListViewPage({required this.docTypeName});

  @override
  _DocTypeListViewPageState createState() => _DocTypeListViewPageState();
}

class _DocTypeListViewPageState extends State<DocTypeListViewPage> {
  List<Map<String, dynamic>> fields = [];
  List<Map<String, dynamic>> keyValuePairs = [];
  Map<String, dynamic> formData = {};
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;

  final String baseUrl =
      'http://localhost:8000'; // Replace with your Frappe base URL

  @override
  void initState() {
    super.initState();
    fetchKeyValuePairs().then((_) {
      fetchDoctypeDetails();
    });
  }

  Future<void> fetchKeyValuePairs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/method/frappe.desk.reportview.get?doctype=${widget.docTypeName}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          keyValuePairs =
              List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
        });
      } else {
        throw Exception('Failed to load key-value pairs');
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> fetchDoctypeDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.docTypeName}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          fields = List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
          for (var field in fields) {
            String fieldName = field['fieldname'];
            formData[fieldName] = null; // Initialize fields
            controllers[fieldName] =
                TextEditingController(); // Create controllers
          }
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load DocType details');
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void applyFilters() {
    // Logic to apply filters based on formData
    // You can implement your filtering logic here
    print("Filters applied: $formData");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.docTypeName} Fields'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: fields.length,
                    itemBuilder: (context, index) {
                      var field = fields[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: controllers[field['fieldname']],
                          decoration: InputDecoration(
                            labelText: field['label'],
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            formData[field['fieldname']] =
                                value; // Update form data
                          },
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: applyFilters,
                  child: Text('Apply Filters'),
                ),
              ],
            ),
    );
  }
}

class Item {
  final String name;
  final String description;

  Item({required this.name, required this.description});

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'],
      description: json['description'],
    );
  }
}

class ApiService {
  final String baseUrl =
      'https://your-frappe-site.com'; // Replace with your Frappe base URL

  Future<List<Item>> fetchItems(String docTypeName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/resource/$docTypeName'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((item) => Item.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  Future<List<Map<String, dynamic>>> fetchKeyValuePairs(
      String docTypeName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/method/frappe.desk.reportview.get?doctype=$docTypeName'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception('Failed to load key-value pairs');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDoctypeDetails(
      String docTypeName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(
          '$baseUrl/api/method/frappe.desk.form.load.getdoctype?doctype=$docTypeName'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
    } else {
      throw Exception('Failed to load DocType details');
    }
  }
}
