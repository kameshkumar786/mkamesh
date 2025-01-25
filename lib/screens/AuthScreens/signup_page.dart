import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> formFields = [
    {
      "label": "Company Name",
      "hint": "Enter your company name",
      "type": "text",
      "width": 1.0, // Full width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Company Name is required.";
        }
        return null;
      },
    },
    {
      "label": "Company Email",
      "hint": "Enter your company email",
      "type": "email",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        final emailRegex =
            RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
        if (value == null || value.isEmpty) {
          return "Email is required.";
        } else if (!emailRegex.hasMatch(value)) {
          return "Enter a valid email address.";
        }
        return null;
      },
    },
    {
      "label": "Contact Person Name",
      "hint": "Enter contact person name",
      "type": "text",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Contact Person Name is required.";
        }
        return null;
      },
    },
    {
      "label": "Contact Person Email",
      "hint": "Enter contact person email",
      "type": "email",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        final emailRegex =
            RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
        if (value == null || value.isEmpty) {
          return "Email is required.";
        } else if (!emailRegex.hasMatch(value)) {
          return "Enter a valid email address.";
        }
        return null;
      },
    },
    {
      "label": "Mobile Number",
      "hint": "Enter your mobile number",
      "type": "number",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Mobile Number is required.";
        } else if (value.length != 10) {
          return "Enter a valid 10-digit mobile number.";
        }
        return null;
      },
    },
    {
      "label": "Company Mobile Number",
      "hint": "Enter company mobile number",
      "type": "number",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Company Mobile Number is required.";
        } else if (value.length != 10) {
          return "Enter a valid 10-digit mobile number.";
        }
        return null;
      },
    },
    {
      "label": "GSTIN",
      "hint": "Enter GSTIN",
      "type": "text",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        final gstRegex = RegExp(
            r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{1}[Z]{1}[A-Z0-9]{1}$");
        if (value == null || value.isEmpty) {
          return "GSTIN is required.";
        } else if (!gstRegex.hasMatch(value)) {
          return "Enter a valid GSTIN.";
        }
        return null;
      },
    },
    {
      "label": "City",
      "hint": "Enter city",
      "type": "text",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "City is required.";
        }
        return null;
      },
    },
    {
      "label": "State",
      "hint": "Enter state",
      "type": "text",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "State is required.";
        }
        return null;
      },
    },
    {
      "label": "Country",
      "hint": "Enter country",
      "type": "text",
      "width": 0.8, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Country is required.";
        }
        return null;
      },
    },
    {
      "label": "Pincode",
      "hint": "Enter pincode",
      "type": "number",
      "width": 0.5, // Half width
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Pincode is required.";
        }
        return null;
      },
    },
    {
      "label": "Number of Employees",
      "hint": "Select employee range",
      "type": "dropdown",
      "width": 1.0, // Full width
      "options": ["1-5", "5-8", "8-12", "12 and more"],
      "controller": TextEditingController(),
      "validator": (value) {
        if (value == null || value.isEmpty) {
          return "Please select the number of employees.";
        }
        return null;
      },
    },
  ];

  Widget buildFormField(Map<String, dynamic> field) {
    if (field["type"] == "dropdown") {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: field["label"],
          hintText: field["hint"],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        items: (field["options"] as List<String>)
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (value) {
          field["controller"].text = value!;
        },
        validator: field["validator"],
      );
    } else {
      return TextFormField(
        controller: field["controller"],
        decoration: InputDecoration(
          labelText: field["label"],
          hintText: field["hint"],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        keyboardType: field["type"] == "email"
            ? TextInputType.emailAddress
            : field["type"] == "number"
                ? TextInputType.number
                : TextInputType.text,
        inputFormatters: field["type"] == "number"
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: field["validator"],
      );
    }
  }

  void handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final formData = formFields.map((field) {
        return {field["label"]: field["controller"].text};
      }).toList();

      print("Form Data: $formData");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Form submitted successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fix the errors in the form.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Wrap(
                  spacing: 20.0,
                  runSpacing: 20.0,
                  children: formFields.map((field) {
                    return SizedBox(
                      width: MediaQuery.of(context).size.width * field["width"],
                      child: buildFormField(field),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Signup",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  "Already Registered? Login",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
