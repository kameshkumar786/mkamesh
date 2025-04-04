import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FrappeFormScreen extends StatefulWidget {
  final String doctype; // Pass the Doctype name
  const FrappeFormScreen({Key? key, required this.doctype}) : super(key: key);

  @override
  _FrappeFormScreenState createState() => _FrappeFormScreenState();
}

class _FrappeFormScreenState extends State<FrappeFormScreen> {
  Map<String, dynamic>? doctypeMeta;
  final Map<String, dynamic> formData = {};

  @override
  void initState() {
    super.initState();
    fetchDoctypeMeta();
  }

  Future<void> fetchDoctypeMeta() async {
    final url =
        Uri.parse("http://localhost:8000/api/resource/${widget.doctype}");
    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization":
              "token 01566cded55ec06:34fee1bbe29b1da", // Replace with your API key and secret
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          doctypeMeta = data["data"]; // Extract metadata of the Doctype
        });
      } else {
        throw Exception("Failed to fetch Doctype metadata: ${response.body}");
      }
    } catch (error) {
      print("Error fetching Doctype metadata: $error");
    }
  }

  Widget buildField(Map<String, dynamic> field) {
    final fieldType = field["fieldtype"];
    final fieldName = field["fieldname"];
    final label = field["label"] ?? fieldName;

    switch (fieldType) {
      case "Data":
        return TextFormField(
          decoration: InputDecoration(labelText: label),
          onChanged: (value) => formData[fieldName] = value,
        );
      case "Date":
        return TextFormField(
          decoration: InputDecoration(labelText: label),
          readOnly: true,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                formData[fieldName] = date.toIso8601String().split("T").first;
              });
            }
          },
          controller: TextEditingController(text: formData[fieldName] ?? ""),
        );
      case "Select":
        final options = field["options"]?.split("\n") ?? [];
        return DropdownButtonFormField(
          decoration: InputDecoration(labelText: label),
          items: options
              .map((option) =>
                  DropdownMenuItem(value: option, child: Text(option)))
              .toList(),
          onChanged: (value) => formData[fieldName] = value,
        );
      default:
        return Text("Unsupported field type: $fieldType");
    }
  }

  Future<void> submitForm() async {
    final url =
        Uri.parse("http://localhost:8000/api/resource/${widget.doctype}");
    final response = await http.post(
      url,
      headers: {
        "Authorization": "token 01566cded55ec06:34fee1bbe29b1da",
        "Content-Type": "application/json",
      },
      body: jsonEncode(formData),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Form submitted successfully!")),
      );
    } else {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit form: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Frappe Doctype: ${widget.doctype}"),
      ),
      body: doctypeMeta == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ...?doctypeMeta?["fields"]
                      ?.map<Widget>((field) => buildField(field)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitForm,
                    child: const Text("Submit"),
                  ),
                ],
              ),
            ),
    );
  }
}
