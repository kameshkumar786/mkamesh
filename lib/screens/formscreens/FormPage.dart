import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mkamesh/screens/formscreens/FileViewer.dart';
import 'package:mkamesh/screens/formscreens/FrappeTableField.dart';
import 'package:mkamesh/screens/formscreens/TextEditor.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class FrappeCrudForm extends StatefulWidget {
  final String doctype;
  final String docname;
  final String baseUrl;

  const FrappeCrudForm(
      {required this.doctype, required this.docname, required this.baseUrl});

  @override
  _FrappeCrudFormState createState() => _FrappeCrudFormState();
}

class _FrappeCrudFormState extends State<FrappeCrudForm> {
  List<Map<String, dynamic>> fields = [];
  Map<String, dynamic> formData = {};
  Map<String, dynamic> cur_frm = {};
  Map<String, dynamic> metaData = {};
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;
  bool updateAble = false;

  @override
  void initState() {
    super.initState();
    fetchDoctypeFields();
  }

  Future<void> fetchDoctypeFields() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // print('metaData $data');
        setState(() {
          metaData = data;
          fields = List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
          for (var field in fields) {
            String fieldName = field['fieldname'];
            formData[fieldName] = null; // Initialize fields
            controllers[fieldName] =
                TextEditingController(); // Create controllers
          }
          isLoading = false;
        });

        if (widget.docname.isNotEmpty) {
          await fetchDocumentData(token);
        }
      } else {
        throw Exception('Failed to load fields');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError(e.toString());
    }
  }

  Future<void> fetchDocumentData(String? token) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.load.getdoc?doctype=${widget.doctype}&name=${widget.docname}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print(data);
        setState(() {
          cur_frm = data;

          // Populate formData and controllers with the fetched document data
          for (var field in fields) {
            String fieldName = field['fieldname'];
            if (data['docs'][0][fieldName] != null) {
              // formData[fieldName] = data['docs'][0][fieldName];
              // controllers[fieldName]?.text =
              //     formData[fieldName].toString(); // Set the controller text

              if (field['fieldtype'] == 'Check') {
                // Convert integer to boolean for checkbox fields
                formData[fieldName] =
                    data['docs'][0][fieldName] == 1; // Assuming 1 is true
              } else {
                formData[fieldName] = data['docs'][0][fieldName];
              }
              controllers[fieldName]?.text = formData[fieldName].toString();
            }
          }
          isLoading = false; // Set loading to false after fetching data
        });
      } else {
        throw Exception('Failed to load document data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError(e.toString());
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget buildField(Map<String, dynamic> field) {
    bool evaluateCondition(String condition) {
      try {
        // Replace field references with actual values
        String parsedCondition = condition;

        formData.forEach((key, value) {
          parsedCondition = parsedCondition.replaceAll(key, value.toString());
        });

        // Simple evaluation (this does not support full JS expressions)
        return parsedCondition.contains("true");
      } catch (e) {
        return false; // Default to false if an error occurs
      }
    }

    String fieldType = field['fieldtype'] ?? '';
    String fieldName = field['fieldname'] ?? '';
    String depends_on = field['depends_on'] ?? '';
    String mandatory_depends_on = field['mandatory_depends_on'] ?? '';
    String read_only_depends_on = field['read_only_depends_on'] ?? '';
    // String permlevel = field['permlevel'] ?? '';
    String? label = field['label'];
    bool readOnly = _convertToBool(field['read_only']);
    bool hidden = _convertToBool(field['hidden']);
    bool required = _convertToBool(field['reqd']);

    void _updateDependentFields(Map field) {
      for (var field in fields) {
        if (field['options'] == fieldName || field['depends_on'] == fieldName) {
          print(
              '$fieldName $fieldName $fieldName $fieldName $fieldName $fieldName');
          setState(() {});
        }
      }
    }

    // if (field['fieldtype'] == 'Dynamic Link') {
    //   hidden = true;
    //   if (formData[field['options']] != null) {
    //     hidden = false;
    //   }
    // }
    if (mandatory_depends_on.isNotEmpty) {
      readOnly = evaluateCondition(mandatory_depends_on);
    }

    if (read_only_depends_on.isNotEmpty) {
      readOnly = evaluateCondition(read_only_depends_on);
    }

    if (depends_on.isNotEmpty) {
      readOnly = evaluateCondition(depends_on);
    }

    final controller = controllers[fieldName];

    if (field['depends_on'] != null ||
        (field['depends_on'] is String && field['depends_on'].isNotEmpty)) {
      // print('nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn');
      if (formData[field['depends_on']] == null ||
          (formData[field['depends_on']] is String &&
              formData[field['depends_on']].isEmpty)) {
        // print(
        //     'mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm');
        setState(() {
          hidden = true;
        });
      }
    }
    if (hidden) {
      return SizedBox.shrink(); // Return an empty widget for hidden fields
    }
    // else if (fieldType == 'Link') {
    //   try {
    //     // Wrap LinkField in SizedBox/Container to constrain its size
    //     return SizedBox(
    //         // height: 1000, // Adjust based on your UI needs
    //         child:
    //             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    //       LinkField(
    //         fieldLabel: label ?? '',
    //         fieldName: fieldName,
    //         linkDoctype: field['options'] ?? '',
    //         fetchLinkOptions: fetchLinkOptions,
    //         formData: formData,
    //         onValueChanged: (value) {
    //           // Guard against unnecessary rebuilds
    //           if (formData[fieldName] != value) {
    //             setState(() {
    //               formData[fieldName] = value;
    //               // controller?.text = value ?? '';
    //               _updateDependentFields(field);
    //             });
    //           }
    //         },
    //       ),
    //       Text(
    //           field["description"] is String && field["description"].isNotEmpty
    //               ? '${field["description"]}'
    //               : '',
    //           style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    //     ]));
    //   } catch (e) {
    //     // SizedBox(
    //     //   height: 5000,
    //     // );
    //     // Log the error and return a fallback widget
    //     print("Error rendering LinkField: $e");
    //     return Text("Failed to load field: ${field['label']}");
    //   }
    // }

    else {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fieldType == 'Data' || fieldType == 'Email')
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = value;
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Text')
                TextFormField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = value;
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Int' || fieldType == 'Float')
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = double.tryParse(value);
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Currency')
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = double.tryParse(value);
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Select' && field['options'] != null)
                DropdownButtonFormField<String>(
                  value: formData[fieldName] ??
                      (field['options'] as String).split('\n').first,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  items: (field['options'] as String)
                      .split('\n')
                      .map((option) => DropdownMenuItem(
                            value: option,
                            child: Text(option, style: TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (value) {
                          setState(() {
                            formData[fieldName] = value;
                            _updateDependentFields(field);
                          });
                        },
                ),
              if (fieldType == 'Date')
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: true,
                  onTap: () async {
                    if (!readOnly) {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1950),
                        lastDate: DateTime(2101),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              primaryColor: Colors.black, // Header color
                              hintColor: Colors.black, // Selected color
                              colorScheme: ColorScheme.light(
                                  primary: Colors.black), // Primary color
                              buttonTheme: ButtonThemeData(
                                  textTheme: ButtonTextTheme
                                      .primary), // Button text color
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        String formattedDate =
                            pickedDate.toIso8601String().split('T')[0];
                        setState(() {
                          formData[fieldName] = formattedDate;
                          controller?.text = formattedDate;
                          _updateDependentFields(field);
                        });
                      }
                    }
                  },
                ),
              if (fieldType == 'Link')
                LinkField(
                  fieldLabel: label ?? '',
                  fieldName: fieldName,
                  linkDoctype: field['options'] ?? '',
                  fetchLinkOptions: fetchLinkOptions,
                  formData: formData,
                  onValueChanged: (value) {
                    setState(() {
                      formData[fieldName] = value;
                      controller?.text = value ?? '';
                      _updateDependentFields(field);
                    });
                  },
                ),

              if (fieldType == 'Check')
                CheckboxListTile(
                  title: Text(label ?? ''),
                  value: formData[fieldName] ?? false,
                  onChanged: readOnly
                      ? null
                      : (value) {
                          setState(() {
                            formData[fieldName] = value;
                            _updateDependentFields(field);
                          });
                        },
                ),
              if (fieldType == 'Image')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: readOnly
                          ? null
                          : () async {
                              // Implement image picker logic here
                            },
                      child: Text('Upload Image'),
                    ),
                    // Display the uploaded image if available
                    if (formData[fieldName] != null)
                      Image.network(formData[fieldName]),
                  ],
                ),
              if (fieldType == 'File')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: readOnly
                          ? null
                          : () async {
                              // Implement file picker logic here
                            },
                      child: Text('Upload File'),
                    ),
                    // Display the uploaded file link if available
                    if (formData[fieldName] != null)
                      TextButton(
                        onPressed: () {
                          // Open the file link
                        },
                        child: Text('View Uploaded File'),
                      ),
                  ],
                ),
              if (fieldType == 'Text Editor')
                // QuillEditorField(
                //     controller: controller,
                //     label: label ?? '',
                //     required: required,
                //     readOnly: readOnly,
                //     formData: formData,
                //     fieldName: fieldName),

                TextFormField(
                  controller: controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = value;
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'HTML')
                Container(
                  height: 200,
                  child: TextFormField(
                    controller: controller,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: required ? '$label *' : label,
                      filled: true,
                      fillColor: readOnly ? Colors.grey[300] : Colors.white,
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 14),
                    ),
                    readOnly: readOnly,
                    onChanged: (value) {
                      setState(() {
                        formData[fieldName] = value;
                        _updateDependentFields(field);
                      });
                    },
                  ),
                ),
              if (fieldType == 'Rate')
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] =
                          double.tryParse(value); // Store as a double
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Password')
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = value; // Store password
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Duration')
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] = value; // Store duration as a string
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Percentage')
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: required ? '$label *' : label,
                    filled: true,
                    fillColor: readOnly ? Colors.grey[300] : Colors.white,
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  readOnly: readOnly,
                  onChanged: (value) {
                    setState(() {
                      formData[fieldName] =
                          double.tryParse(value); // Store as a double
                      _updateDependentFields(field);
                    });
                  },
                ),
              if (fieldType == 'Table')
                FrappeTableField(
                  label: label ?? '',
                  childTableDoctype: field['options'] ?? '',
                  formData: formData,
                  field: field,
                  onValueChanged: (value) {
                    // print(value);
                    setState(() {
                      formData[fieldName] = value;
                      _updateDependentFields(field);
                    });
                  },
                ),

              // Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     Text('need to create Table: ${field.toString()}'),
              //   ],
              // ),
              if (fieldType == 'Dynamic Link')
                if (formData[field['options']] != null)
                  LinkField(
                    fieldLabel: label ?? '',
                    fieldName: fieldName,
                    linkDoctype: formData[field['options']] ?? '',
                    fetchLinkOptions: fetchLinkOptions,
                    formData: formData,
                    onValueChanged: (value) {
                      setState(() {
                        formData[fieldName] = value;
                        controller?.text = value ?? '';
                        _updateDependentFields(field);
                      });
                    },
                  ),

              Text(
                  field["description"] is String &&
                          field["description"].isNotEmpty
                      ? '${field["description"]}'
                      : '',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }
  }

  Future<List<dynamic>> fetchLinkOptions(
      String linkDoctype, String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? [];
      } else {
        throw Exception('Failed to fetch link options');
      }
    } catch (e) {
      showError(e.toString());
      return [];
    }
  }

  bool _convertToBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return false; // Default to false if value is neither bool nor int
  }

  Future<void> createOrUpdateDocument() async {
    try {} catch (e) {
      showError(e.toString());
    }
  }

  Widget buildFieldsWithSections(List<Map<String, dynamic>> fields) {
    List<Widget> sections = []; // Holds all sections
    List<Widget> currentSectionRows = []; // Holds rows in the current section
    List<Widget> currentRowFields = []; // Holds fields in the current row

    for (var field in fields) {
      String fieldType = field['fieldtype'] ?? '';

      if (fieldType == 'Section Break') {
        // Finalize the current section before starting a new one
        if (currentRowFields.isNotEmpty) {
          currentSectionRows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: currentRowFields,
            ),
          );
          currentRowFields = [];
        }
        if (currentSectionRows.isNotEmpty) {
          sections.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: currentSectionRows,
              ),
            ),
          );
          currentSectionRows = [];
        }

        // Add the section label and divider as a standalone row
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (field['label'] != null)
                  Text(
                    field['label'],
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                Divider(thickness: 2, color: Colors.grey[300]),
              ],
            ),
          ),
        );
      } else if (fieldType == 'Column Break') {
        // Finalize the current row and start a new column in the same section
        if (currentRowFields.isNotEmpty) {
          currentSectionRows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: currentRowFields,
            ),
          );
          currentRowFields = [];
        }
      } else {
        // Add the field to the current row
        currentRowFields.add(
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
              child: buildField(field),
            ),
          ),
        );
      }
    }

    // Finalize any remaining fields in the last row and section
    if (currentRowFields.isNotEmpty) {
      currentSectionRows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: currentRowFields,
        ),
      );
    }
    if (currentSectionRows.isNotEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: currentSectionRows,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Future<void> _submit() async {
    // Check if required fields are filled

    for (var field in fields) {
      if (field['required'] && formData[field['fieldname']].isEmpty) {
        _showAlertDialog('Please fill ${field['label']} its a required field.');
        return; // Stop the submission process
      }
    }

    String apiUrl = 'https://teamloser.in/api/resource/${widget.doctype}';

    try {
      http.Response response;

      if (widget.docname.isNotEmpty) {
        // If docname exists, make a PUT request
        response = await http.put(
          Uri.parse('$apiUrl/${widget.docname}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );
      } else {
        // If docname does not exist, make a POST request
        response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle successful response
        final responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Success: ${responseData['message']}')),
        );
      } else {
        // Handle error response
        throw Exception('Failed to submit data: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Validation Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docname.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('CRUD Form: ${widget.doctype}'),
        ),
        backgroundColor: Colors.white,
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildFieldsWithSections(fields),

                      SizedBox(height: 10), // Add some space before the button
                      SizedBox(
                        width: double.infinity, // Full width of the parent
                        child: ElevatedButton(
                          onPressed: () {
                            _submit();
                          },
                          child: const Text('Save'),
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
                    ],
                  ),
                ),
              ),
      );
    } else {
      return DefaultTabController(
        length: 4, // Number of tabs
        child: Scaffold(
          appBar: AppBar(
            title: Text('Top Tab View'),
            bottom: TabBar(
              tabs: [
                Tab(text: 'Form'),
                Tab(text: 'Comments'),
                Tab(text: 'Share'),
                Tab(text: 'Connections'),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          body: isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildFieldsWithSections(fields),
                          SizedBox(
                              height: 10), // Add some space before the button
                          SizedBox(
                            width: double.infinity, // Full width of the parent
                            child: ElevatedButton(
                              onPressed: () {
                                // _submit();
                                print(formData);
                              },
                              child: updateAble
                                  ? const Text('Update Now')
                                  : (formData['docstatus'] == 0
                                      ? const Text('Submit')
                                      : const Text('not updateable')),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16), // Medium height
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      25), // Rounded corners
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                      SingleChildScrollView(
                        child: TabContent2(
                          doctype: widget.doctype,
                          docname: widget.docname,
                          baseUrl: widget.baseUrl,
                          cur_frm: cur_frm,
                        ),
                      ),
                      SingleChildScrollView(
                        child: TabContent3(
                          doctype: widget.doctype,
                          docname: widget.docname,
                          baseUrl: widget.baseUrl,
                          cur_frm: cur_frm,
                        ),
                      ),
                      SingleChildScrollView(
                        child: TabContent4(
                          doctype: widget.doctype,
                          docname: widget.docname,
                          baseUrl: widget.baseUrl,
                          cur_frm: cur_frm,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
  }
}

class TabContent2 extends StatefulWidget {
  final String doctype;
  final Map cur_frm;
  final String docname;
  final String baseUrl;

  const TabContent2({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
    required this.cur_frm,
  });

  @override
  _TabContent2State createState() => _TabContent2State();
}

class _TabContent2State extends State<TabContent2>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // fetchComments();
    getComments();
  }

  void getComments() {
    var fetchedComments = widget.cur_frm['docinfo']['comments'];
    print(widget.cur_frm['docinfo']);
    print(widget.cur_frm['docinfo']['user_info']);

    if (fetchedComments is List) {
      comments = List<Map<String, dynamic>>.from(fetchedComments.map((comment) {
        // Ensure each comment is a Map<String, dynamic>
        if (comment is Map<String, dynamic>) {
          return comment;
        } else {
          // Handle the case where the comment is not a Map
          return {}; // or handle it as needed
        }
      }));
    } else {
      comments = []; // Default to an empty list if no comments
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchComments() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.utils.get_comments?doctype=${widget.doctype}&docname=${widget.docname}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          comments = List<Map<String, dynamic>>.from(data['message']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> saveComment() async {
    if (_messageController.text.isEmpty) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.utils.add_comment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({
          'reference_doctype': widget.doctype,
          'reference_name': widget.docname,
          'content':
              '<div class="ql-editor read-mode"><p>${_messageController.text}</p></div>',
          'comment_email': '',
          'comment_by': ''
        }),
      );

      if (response.statusCode == 200) {
        _messageController.clear();
        var mdata = jsonDecode(response.body);
        print(mdata['message']);
        comments.insert(0, mdata['message']);
        fetchComments(); // Refresh comments
      } else {
        throw Exception('Failed to save comment');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Comments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Add a comment',
              hintText: 'Type your comment here...',
            ),
          ),
          SizedBox(height: 4),
          ElevatedButton(
            onPressed: saveComment,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
            ),
            child: Text('Save Comment'),
          ),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final owner = comment['owner'];

                    // Access user info based on the owner
                    final userInfo =
                        widget.cur_frm['docinfo']['user_info'][owner];

                    String formattedDate = '';
                    String formattedTime = '';
                    if (comment['creation'] != null) {
                      DateTime dateTime = DateTime.parse(comment['creation']);
                      formattedDate = DateFormat('d MMM yyyy')
                          .format(dateTime); // Format as "2 Jan 2025"
                      formattedTime = DateFormat('HH:mm')
                          .format(dateTime); // Format as "14:45"
                    }

                    return Card(
                      color: Colors.white,
                      // Optional: Wrap in a Card for better UI
                      // margin:
                      //     EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      child: ListTile(
                        // title: Text(comment['name'] ??
                        //     'No Name'), // Use null-aware operator
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row to display avatar, full name, and email
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green[50],
                                  backgroundImage: userInfo != null &&
                                          userInfo['image'] != null
                                      ? NetworkImage(userInfo['image'])
                                      : null, // Use null if no image
                                  child: userInfo != null &&
                                          userInfo['image'] == null
                                      ? Icon(Icons.person,
                                          color: Colors.black) // Default icon
                                      : null,
                                  radius: 20, // Set radius for the avatar
                                ),
                                SizedBox(width: 8.0), // Add some spacing
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userInfo != null
                                                ? userInfo['fullname']
                                                : 'Unknown User', // Display fullname
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (userInfo != null &&
                                              userInfo['email'] != null)
                                            Text(
                                              userInfo['email'],
                                              style: TextStyle(
                                                  fontSize: 12.0,
                                                  color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                      // Column to display the date and time
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            comment['creation'] != null
                                                ? formattedDate
                                                : 'No Date',
                                            style: TextStyle(
                                                fontSize: 12.0,
                                                color: Colors.grey),
                                          ),
                                          Text(
                                            comment['creation'] != null
                                                ? formattedTime
                                                : '',
                                            style: TextStyle(
                                                fontSize: 12.0,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // SizedBox(height: 1.0), // Add some spacing
                            Html(
                                data: comment['content'] ??
                                    ''), // Use a package to render HTML content
                            // SizedBox(height: 1.0), // Add some spacing
                          ],
                        ),
                      ),
                    );
                  },
                )
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TabContent3 extends StatefulWidget {
  final String doctype;
  final String docname;
  final String baseUrl;
  final Map cur_frm;

  const TabContent3({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
    required this.cur_frm,
  });

  @override
  _TabContent3State createState() => _TabContent3State();
}

class _TabContent3State extends State<TabContent3> {
  List<Map<String, dynamic>> attachments = [];
  List<Map<String, dynamic>> shared = [];
  List<Map<String, dynamic>> assignments = [];
  bool isLoading = true;
  bool isAttachmentLoading = false;

  @override
  void initState() {
    super.initState();
    getAttachments();
  }

  void getAttachments() {
    var docInfo = widget.cur_frm['docinfo'];
    attachments = List<Map<String, dynamic>>.from(docInfo['attachments'] ?? []);
    shared = List<Map<String, dynamic>>.from(docInfo['shared'] ?? []);
    assignments = List<Map<String, dynamic>>.from(docInfo['assignments'] ?? []);
    setState(() => isLoading = false);
  }

  Future<void> addAttachment(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      String? mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';

      bool? confirmUpload =
          await _showFilePreviewDialog(context, filePath, fileName);

      if (confirmUpload != null) {
        await _uploadFile(context, filePath, fileName, mimeType, confirmUpload);
      }
    }
  }

  Future<bool?> _showFilePreviewDialog(
      BuildContext context, String filePath, String fileName) async {
    bool isPrivate = false;
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text("Preview File"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("File: $fileName"),
                  Row(
                    children: [
                      Checkbox(
                        value: isPrivate,
                        onChanged: (value) {
                          setState(() {
                            isPrivate = value ?? false;
                          });
                        },
                      ),
                      Text("Make Private")
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(isPrivate),
                  child: Text("Upload"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _uploadFile(BuildContext context, String filePath,
      String fileName, String mimeType, bool isPrivate) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text("Uploading..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Uploading $fileName"),
              ],
            ),
          );
        },
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      var uri = Uri.parse('https://teamloser.in/api/method/upload_file');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'multipart/form-data',
        'Authorization': '$token',
      });

      request.fields['is_private'] = isPrivate ? '1' : '0';
      request.fields['doctype'] = widget.doctype;
      request.fields['docname'] = widget.docname;
      request.fields['file_url'] = '';

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));

      var response = await request.send();
      Navigator.of(context).pop();
      print('request : ${request.fields}');

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File uploaded successfully"),
            backgroundColor: Colors.green,
          ),
        );
        attachments.add({'file_name': fileName, 'file_url': filePath});

        print("File uploaded successfully: $responseBody");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "File upload failed ${response.reasonPhrase}  ${await response.stream.bytesToString()}"),
            backgroundColor: Colors.green,
          ),
        );
        print("File upload failed: ${response.reasonPhrase}");
        print("Response status code: ${response.statusCode}");
        print("Response body: ${await response.stream.bytesToString()}");
        throw Exception("File upload failed");
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("File upload error ${e}"),
          backgroundColor: Colors.green,
        ),
      );
      print("Error: $e");
    }
  }

  void shareWithUser(String userEmail) {
    setState(() {
      shared.add({'user': userEmail});
    });
  }

  void assignToUser(String userEmail, String description) {
    setState(() {
      assignments.add({
        'assigned_to': userEmail,
        'description': description,
        'status': 'Open'
      });
    });
  }

  void _showImagePreview(String imageUrl) async {
    setState(() => isAttachmentLoading = true);
    await Future.delayed(Duration(seconds: 2));

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(imageUrl),
      headers: {'Authorization': '$token'},
    );

    if (response.statusCode == 200) {
      await Future.delayed(Duration(seconds: 2));
      setState(() => isAttachmentLoading = false);

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: Image.memory(response.bodyBytes, fit: BoxFit.cover),
          );
        },
      );
    } else {
      await Future.delayed(Duration(seconds: 2));

      setState(() => isAttachmentLoading = false);
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: (Text('This image is not available try again')),
          );
        },
      );
    }
  }

  void _showUserDetails(Map? user, Map? permissions) {
    if (user == null || user.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user['fullname'] ?? user['user'] ?? 'Unknown User'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user['email'] != null)
                Text('Email: ${user['email']}', style: TextStyle(fontSize: 14)),
              if (permissions != null && permissions.isNotEmpty)
                Text('Permissions: ${permissions.toString()}',
                    style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openUserSelectionModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return UserSelectionModal(
            cur_frm: widget.cur_frm,
            onSubmit: (selectedUser, permissions) {
              // Handle the submission of selected user and permissions
              // You can call your shareWithUser  function here if needed
              print("Selected User: $selectedUser ");
              print("Permissions: $permissions");
              Navigator.pop(context);
            });
      },
    );
  }

  void _openUserAssignmentSelectionModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return UserAssignmentSelectionModal(
            cur_frm: widget.cur_frm,
            onSubmit: (selectedUser, permissions) {
              // Handle the submission of selected user and permissions
              // You can call your shareWithUser  function here if needed
              print("Selected User: $selectedUser ");
              print("Permissions: $permissions");
              Navigator.pop(context);
            });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var userInfo = widget.cur_frm['docinfo']['user_info'];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Attachments'),

            isAttachmentLoading
                ? Center(child: CircularProgressIndicator())
                : isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _buildGridAttachments(),
            SizedBox(height: 10),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black background
                padding: EdgeInsets.symmetric(horizontal: 14), // Padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
              ),
              onPressed: () {
                addAttachment(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min, // Use minimum size for the row
                children: [
                  Icon(
                    Icons.attach_file, // Use the desired icon
                    color: Colors.white, // Icon color
                    size: 14, // Icon size
                  ),
                  SizedBox(width: 2), // Space between icon and text
                  Text(
                    "Add Attachment",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white, // White font color
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _sectionTitle('Shared With'),
            _buildSharedList(userInfo),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black background
                padding: EdgeInsets.symmetric(horizontal: 14), // Padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
              ),
              onPressed: _openUserSelectionModal,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Use minimum size for the row
                children: [
                  Icon(
                    Icons.share, // Share icon
                    color: Colors.white, // Icon color
                    size: 18, // Icon size
                  ),
                  SizedBox(width: 8), // Space between icon and text
                  Text(
                    "+ Add User",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white, // White font color
                    ),
                  ),
                ],
              ),
            ),
            // TextField(
            //   decoration:
            //       InputDecoration(labelText: "Enter user email to share"),
            //   onSubmitted: shareWithUser,
            // ),
            SizedBox(height: 20),
            _sectionTitle('Assigned To'),
            _buildAssignmentList(userInfo),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black background
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                ), // Padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
              ),
              onPressed: _openUserAssignmentSelectionModal,
              child: Text(
                "+ Assign to",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white, // White font color
                ),
              ),
            ),
            // TextField(
            //   decoration:
            //       InputDecoration(labelText: "Enter user email to assign"),
            //   onSubmitted: (email) => assignToUser(email, "New Task"),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAttachments() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        String fileUrl = 'https://teamloser.in${attachment['file_url']}';
        String fileName = attachment['file_name'];

        // if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {
        //   return GestureDetector(
        //     onTap: () => _showImagePreview(fileUrl),
        //     child: Image.network(fileUrl, fit: BoxFit.cover),
        //   );
        // } else if (fileName.endsWith('.pdf')) {
        //   return _fileIcon(Icons.picture_as_pdf, fileUrl);
        // } else if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
        //   return _fileIcon(Icons.description, fileUrl);
        // } else if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) {
        //   return _fileIcon(Icons.table_chart, fileUrl);
        // } else {
        //   return _fileIcon(Icons.insert_drive_file, fileUrl);
        // }

        if (fileName.endsWith('.jpg') || fileName.endsWith('.png')) {
          return GestureDetector(
            onTap: () => _showImagePreview(fileUrl),
            child: Image.network(fileUrl, fit: BoxFit.cover),
          );
        } else {
          // Use FileViewerWidget for all other file types
          return FileViewerWidget(
            fileUrl: fileUrl,
            fileIcon: _getFileIcon(fileName),
            isPrivate: false, // Set to true if the file requires authentication
          );
        }
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      return Icons.description;
    } else if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) {
      return Icons.table_chart;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Widget _fileIcon(IconData icon, String fileUrl) {
    return GestureDetector(
      onTap: () => _openFile(fileUrl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.black),
          SizedBox(height: 5),
          Text("Open", style: TextStyle(fontSize: 12, color: Colors.black)),
        ],
      ),
    );
  }

  // void _openFile(String url) async {
  //   final Uri uri = Uri.parse(url);

  //   if (await canLaunchUrl(uri)) {
  //     await launchUrl(uri);
  //   } else {
  //     OpenFile.open(url);
  //   }
  // }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);

    // Check if the URL can be launched
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // If the URL cannot be launched, try to open it as a file
      // Assuming the file is already downloaded to a local path
      String? localPath = await _downloadFile(url);
      if (localPath != null) {
        OpenFilex.open(localPath);
      } else {
        print('Failed to download the file.');
      }
    }
  }

  Future<String?> _downloadFile(String url) async {
    try {
      // Get the directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/file.pdf'; // Change the file name as needed

      // Download the file (you can use http package for this)
      // Here, you would typically use an HTTP client to download the file
      // For example:
      // final response = await http.get(Uri.parse(url));
      // if (response.statusCode == 200) {
      //   final File file = File(filePath);
      //   await file.writeAsBytes(response.bodyBytes);
      //   return filePath;
      // }

      // For demonstration, just return the file path
      return filePath; // Return the path where the file would be saved
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  // Widget _buildSharedList(Map userInfo) {
  //   return ListView.builder(
  //     shrinkWrap: true,
  //     physics: NeverScrollableScrollPhysics(),
  //     itemCount: shared.length,
  //     itemBuilder: (context, index) {
  //       final user = shared[index];
  //       final userDetails = userInfo[user['user']];

  //       return ListTile(
  //         leading: _avatar(userDetails),
  //         title: GestureDetector(
  //           onTap: () =>
  //               _showUserDetails(userDetails ?? {'user': user['user']}, user),
  //           child: _styledText(
  //               userDetails?['fullname'] ?? user['user'], 14, FontWeight.bold),
  //         ),
  //         subtitle: _styledText(
  //             userDetails?['email'] ?? 'No email', 12, FontWeight.normal),
  //       );
  //     },
  //   );
  // }

  Widget _buildSharedList(Map userInfo) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: shared.length,
      itemBuilder: (context, index) {
        final user = shared[index];
        final userDetails = userInfo[user['user']];

        return ListTile(
          leading: _avatar(userDetails),
          title: GestureDetector(
            onTap: () =>
                _showUserDetails(userDetails ?? {'user': user['user']}, user),
            child: _styledText(
                userDetails?['fullname'] ?? user['user'], 14, FontWeight.bold),
          ),
          subtitle: _styledText(
              userDetails?['email'] ?? 'No email', 12, FontWeight.normal),
          trailing: IconButton(
            icon: Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () => _confirmRemove(user['user']),
          ),
        );
      },
    );
  }

  void _confirmRemove(String user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Remove"),
          content: Text("Are you sure you want to remove access for $user?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _removeSharedUser(user);
              },
              child: Text("Remove", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeSharedUser(String user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final Map<String, dynamic> params = {
      "doctype": widget.cur_frm['docs'][0]['doctype'],
      "name": widget.cur_frm['docs'][0]['name'], // Replace with actual doc.name
      "user": user,
      "read": 0,
      "share": 0,
      "write": 0,
      "submit": 0,
    };

    try {
      final response = await http.post(
        Uri.parse("https://teamloser.in/api/method/share_remove"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        setState(() {
          shared.removeWhere((element) => element['user'] == user);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("User removed successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove user"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An unexpected error occurred"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAssignmentList(Map userInfo) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        final assignedUserDetails = userInfo[assignment['assigned_to']];

        return ListTile(
          leading: _avatar(assignedUserDetails),
          title: GestureDetector(
            onTap: () => _showUserDetails(
                assignedUserDetails ?? {'user': assignment['assigned_to']},
                assignment),
            child: _styledText(assignment['description'], 14, FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _styledText(
                  '${assignment['owner'] ?? 'N/A'}', 12, FontWeight.normal),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showRemoveConfirmation(context, assignment),
          ),
        );
      },
    );
  }

  void _showRemoveConfirmation(BuildContext context, Map assignment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Removal"),
          content: Text("Are you sure you want to remove this assignment?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAssignment(assignment);
              },
              child: Text("Remove", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeAssignment(Map assignment) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    print('assignment:${assignment}');
    try {
      final response = await http.delete(
        Uri.parse(
            'https://teamloser.in/api/method/remove_assignment?name=${assignment['name']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          assignments.remove(assignment);
        });
      } else {
        throw Exception("Failed to remove assignment");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Widget _avatar(Map? userDetails) {
    return CircleAvatar(
      backgroundColor: Colors.green[50],
      backgroundImage: userDetails?['image'] != null
          ? NetworkImage(userDetails!['image'])
          : null,
      child: userDetails?['image'] == null
          ? Icon(Icons.person, color: Colors.black)
          : null,
    );
  }

  Widget _styledText(String text, double size, FontWeight weight) {
    return Text(
      text,
      style: TextStyle(fontSize: size, fontWeight: weight, color: Colors.black),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
    );
  }
}

class TabContent4 extends StatefulWidget {
  final String doctype;
  final String docname;
  final String baseUrl;
  final dynamic cur_frm;

  TabContent4({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
    required this.cur_frm,
  });

  @override
  _TabContent4State createState() => _TabContent4State();
}

class _TabContent4State extends State<TabContent4> {
  int? externalLinksCount;
  int? internalLinksCount;
  String? errorMessage;
  List<dynamic> externalLinks = []; // To store external links data

  @override
  void initState() {
    super.initState();
    fetchOpenCount();
  }

  Future<void> fetchOpenCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final url =
        'https://teamloser.in/api/method/frappe.desk.notifications.get_open_count?doctype=Opportunity&name=CRM-OPP-2025-00001';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Parse the response
        setState(() {
          externalLinksCount = data['message']['count']['external_links_found']
              .map((link) => link['open_count'])
              .reduce((a, b) => a + b);
          internalLinksCount =
              data['message']['count']['internal_links_found'].length;
          externalLinks = data['message']['count']
              ['external_links_found']; // Store external links
          errorMessage = null; // Clear any previous error message
        });
      } else {
        setState(() {
          errorMessage = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: $e';
      });
    }
  }

  void function01(String doctype) {
    // This function will be called when an item or the plus button is tapped
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('function01 Tapped on: $doctype')),
    );
  }

  void function02(String doctype) {
    // This function will be called when an item or the plus button is tapped
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('function02 Tapped on: $doctype')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set background color to black
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text(
            //   'This is Tab Content 4',
            //   style: TextStyle(fontSize: 24, color: Colors.black), // White text
            // ),
            SizedBox(height: 20),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              )
            else ...[
              Text('External Links Open Count: ${externalLinksCount ?? 0}',
                  style: TextStyle(color: Colors.black)),
              SizedBox(height: 20),
              if (externalLinks.isNotEmpty) ...[
                Text('External Links Found:',
                    style: TextStyle(color: Colors.black)),
                ...externalLinks.map<Widget>((link) {
                  return Container(
                    margin: EdgeInsets.all(5), // Add margin around each button
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => function01(link['doctype']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.black, // Button background color
                            foregroundColor: Colors.white, // Text color
                          ),
                          child: Text(
                              '${link['doctype']}: Count: ${link['open_count']}'),
                        ),
                        ElevatedButton(
                          onPressed: () => {
                            function01('Add New Link for ${link['doctype']}')
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.black, // Button background color
                            foregroundColor: Colors.white, // Text color
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  color: Colors.white), // Plus icon color
                              SizedBox(width: 8),
                              Text('Add'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              Text('Internal Links Count: ${internalLinksCount ?? 0}',
                  style: TextStyle(color: Colors.white)),
            ],
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class UserSelectionModal extends StatefulWidget {
  final Function(String, List<String>) onSubmit;
  final Map cur_frm;

  const UserSelectionModal(
      {Key? key, required this.onSubmit, required this.cur_frm})
      : super(key: key);

  @override
  _UserSelectionModalState createState() => _UserSelectionModalState();
}

class _UserSelectionModalState extends State<UserSelectionModal> {
  final TextEditingController _userController = TextEditingController();
  final List<String> permissions = [];
  List<Map<String, dynamic>> filteredUsers = [];
  String? selectedUser; // To store selected user

  Future<List<dynamic>> fetchLinkOptions(String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          'https://teamloser.in/api/method/frappe.desk.search.search_link?doctype=User&txt=$query',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? [];
      } else {
        throw Exception('Failed to fetch link options');
      }
    } catch (e) {
      return [];
    }
  }

  void _filterUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        filteredUsers = [];
      });
    } else {
      List<dynamic> users = await fetchLinkOptions(query);
      setState(() {
        filteredUsers = users
            .map((user) => {
                  "value": user["value"].toString(),
                  "description": user["description"]?.toString() ?? "",
                })
            .toList();
      });
    }
  }

  Future<void> shareDocument() async {
    if (selectedUser == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a user")),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final Map<String, dynamic> params = {
      "doctype": widget.cur_frm['docs'][0]['doctype'],
      "name": widget.cur_frm['docs'][0]['name'], // Replace with actual doc.name
      "user": selectedUser,
      "read": permissions.contains("read") ? 1 : 0,
      "share": permissions.contains("share") ? 1 : 0,
      "write": permissions.contains("write") ? 1 : 0,
      "submit": permissions.contains("submit") ? 1 : 0,
    };
    try {
      final response = await http.post(
        Uri.parse("https://teamloser.in/api/method/frappe.share.add"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode(params),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Document shared successfully")),
        );
      } else {
        Navigator.pop(context);

        /// Extract error message from `_server_messages`
        String errorMessage = "Failed to share document";

        if (responseData["_server_messages"] != null) {
          List<dynamic> serverMessages =
              jsonDecode(responseData["_server_messages"]);
          if (serverMessages.isNotEmpty) {
            errorMessage = serverMessages[0]["message"] ?? errorMessage;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage, style: TextStyle(color: Colors.red))),
        );
      }
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share document with'),

            TextField(
              controller: _userController,
              decoration: InputDecoration(labelText: "Select User"),
              onChanged: _filterUsers,
            ),

            /// Show filtered user list
            filteredUsers.isNotEmpty
                ? Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(filteredUsers[index]["value"]),
                          subtitle: Text(filteredUsers[index]["description"]),
                          onTap: () {
                            setState(() {
                              selectedUser = filteredUsers[index]["value"];
                              _userController.text = selectedUser!;
                              filteredUsers = [];
                            });
                          },
                        );
                      },
                    ),
                  )
                : SizedBox(),

            /// Two checkboxes per row
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text("Write", style: TextStyle(fontSize: 14)),
                    value: permissions.contains("write"),
                    activeColor: Colors.black,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          permissions.add("write");
                        } else {
                          permissions.remove("write");
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text("Submit", style: TextStyle(fontSize: 13)),
                    value: permissions.contains("submit"),
                    activeColor: Colors.black,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          permissions.add("submit");
                        } else {
                          permissions.remove("submit");
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

            /// Second row of checkboxes
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text("Share", style: TextStyle(fontSize: 14)),
                    value: permissions.contains("share"),
                    activeColor: Colors.black,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          permissions.add("share");
                        } else {
                          permissions.remove("share");
                        }
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text("Read", style: TextStyle(fontSize: 13)),
                    value: permissions.contains("read"),
                    activeColor: Colors.black,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          permissions.add("read");
                        } else {
                          permissions.remove("read");
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            /// Submit Button (Black Background, White Text, Full Width)
            SizedBox(
              width: double.infinity, // Full width
              child: ElevatedButton(
                onPressed: shareDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Black background
                  padding: EdgeInsets.symmetric(vertical: 14), // Padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                  ),
                ),
                child: Text(
                  "Submit",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white, // White font color
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

class UserAssignmentSelectionModal extends StatefulWidget {
  final Function(String, List<String>) onSubmit;
  final Map cur_frm;

  const UserAssignmentSelectionModal({
    Key? key,
    required this.onSubmit,
    required this.cur_frm,
  }) : super(key: key);

  @override
  _UserAssignmentSelectionModalState createState() =>
      _UserAssignmentSelectionModalState();
}

class _UserAssignmentSelectionModalState
    extends State<UserAssignmentSelectionModal> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> filteredUsers = [];
  List<String> selectedUsers = [];
  String? selectedPriority;
  DateTime? completedByDate;

  Future<List<dynamic>> fetchLinkOptions(String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            'https://teamloser.in/api/method/frappe.desk.search.search_link?doctype=User&txt=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
    return [];
  }

  void _filterUsers(String query) async {
    if (query.isEmpty) {
      setState(() => filteredUsers = []);
      return;
    }

    List<dynamic> users = await fetchLinkOptions(query);
    setState(() {
      filteredUsers = users
          .map((user) => {
                "value": user["value"].toString(),
                "description": user["description"]?.toString() ?? "",
              })
          .toList();
    });
  }

  Future<void> shareDocument() async {
    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one user")),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final params = {
      "doctype": widget.cur_frm['docs'][0]['doctype'],
      "name": widget.cur_frm['docs'][0]['name'],
      "assign_to_me": 0,
      "description": _commentController.text,
      "assign_to": selectedUsers,
      "bulk_assign": false,
      "re_assign": false,
    };

    try {
      final response = await http.post(
        Uri.parse(
            "https://teamloser.in/api/method/frappe.desk.form.assign_to.add"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document assigned successfully")),
        );
      } else {
        String errorMessage = "Failed to assign document";
        final responseData = jsonDecode(response.body);
        if (responseData["_server_messages"] != null) {
          List<dynamic> serverMessages =
              jsonDecode(responseData["_server_messages"]);
          if (serverMessages.isNotEmpty) {
            errorMessage = serverMessages[0]["message"] ?? errorMessage;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage, style: TextStyle(color: Colors.red))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred")),
      );
    }
  }

  void _toggleUserSelection(String user) {
    setState(() {
      selectedUsers.contains(user)
          ? selectedUsers.remove(user)
          : selectedUsers.add(user);
    });
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: completedByDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => completedByDate = picked);
    }
  }

  void _removeUser(String user) {
    setState(() {
      selectedUsers.remove(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add to ToDo'),
            Wrap(
              spacing: 4.0, // Space between chips
              runSpacing: 4.0, // Space between rows of chips
              children: selectedUsers.map((user) {
                return Chip(
                  label: Text(
                    user,
                    style: const TextStyle(fontSize: 12), // Smaller font size
                  ),
                  deleteIcon:
                      const Icon(Icons.close, size: 16), // Smaller delete icon
                  onDeleted: () => _removeUser(user),
                  backgroundColor: Colors.blueAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0), // Smaller padding
                );
              }).toList(),
            ),
            TextField(
              controller: _userController,
              decoration: InputDecoration(
                labelText: "Select User",
                labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
                hintText: "Enter Username",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black),
              onChanged: _filterUsers,
            ),
            if (filteredUsers.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(filteredUsers[index]["value"]!),
                    subtitle: Text(filteredUsers[index]["description"]!),
                    trailing: Checkbox(
                      value: selectedUsers
                          .contains(filteredUsers[index]["value"]!),
                      onChanged: (_) =>
                          _toggleUserSelection(filteredUsers[index]["value"]!),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: "Comment",
                labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
                hintText: "Enter Comment",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              maxLines: 6,
              minLines: 5,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Priority",
                labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
                hintText: "Select Priority",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              value: selectedPriority,
              onChanged: (newValue) =>
                  setState(() => selectedPriority = newValue),
              items: ["High", "Medium", "Low"]
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                              fontSize: 13,
                              color: value == "High"
                                  ? Colors.red
                                  : value == "Medium"
                                      ? Colors.orange
                                      : Colors.green,
                              fontWeight: FontWeight.w500),
                        ),
                      ))
                  .toList(),
              isExpanded: true,
              dropdownColor: Colors.grey[200],
              // Makes the dropdown take the full width
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity, // Makes the button take the full width
              child: ElevatedButton(
                onPressed: shareDocument,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20), // Medium height
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25), // Rounded corners
                  ),
                ),
                child:
                    const Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class LinkField extends StatefulWidget {
  final String fieldLabel;
  final String fieldName;
  final String linkDoctype;
  final Future<List<dynamic>> Function(String, String) fetchLinkOptions;
  final Map<String, dynamic> formData;
  final Function(String?) onValueChanged;

  const LinkField({
    required this.fieldLabel,
    required this.fieldName,
    required this.linkDoctype,
    required this.fetchLinkOptions,
    required this.formData,
    required this.onValueChanged,
  });

  @override
  _LinkFieldState createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  String? _selectedValue;
  List<dynamic> _options = [];
  List<dynamic> _filteredOptions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize the selected value from formData
    _selectedValue =
        widget.formData[widget.fieldName]; // Ensure this is set correctly
    _fetchOptions(); // Fetch options on initialization
  }

  Future<void> _fetchOptions() async {
    _options = await widget.fetchLinkOptions(widget.linkDoctype, _searchQuery);
    setState(() {
      _filteredOptions = _options; // Initialize filtered options
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Show the options in a modal bottom sheet
        await _fetchOptions(); // Fetch options when tapped
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white, // Set modal background color to white
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Select ${widget.fieldLabel}',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        onChanged: (query) async {
                          setState(() {
                            _searchQuery = query; // Update the search query
                          });
                          // Call the API to fetch options based on the query
                          if (query.isNotEmpty) {
                            _options = await widget.fetchLinkOptions(
                                widget.linkDoctype, query);
                            setState(() {
                              _filteredOptions =
                                  _options; // Update filtered options
                            });
                          } else {
                            // If the query is empty, reset the filtered options
                            _filteredOptions = _options;
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Search ${widget.fieldLabel}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: _filteredOptions.map((option) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey
                                        .shade300), // Bottom border for each item
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                option['value'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedValue == option['value']
                                      ? Colors.blue
                                      : Colors
                                          .black, // Change color if selected
                                ),
                              ),
                              subtitle: option['description'] != null
                                  ? Text(option['description'])
                                  : null,
                              onTap: () {
                                Navigator.pop(context, option['value']);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ).then((selected) {
          if (selected != null) {
            setState(() {
              _selectedValue = selected;
              widget.formData[widget.fieldName] =
                  _selectedValue; // Update formData with the selected value
              widget.onValueChanged(
                  _selectedValue); // Notify parent of the change
            });
          }
        });
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.fieldLabel,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        child: Text(
          (_selectedValue ?? widget.formData[widget.fieldName]) ??
              'Select ${widget.fieldLabel} ',
          style: TextStyle(
              color:
                  (_selectedValue ?? widget.formData[widget.fieldName]) == null
                      ? Colors.grey
                      : Colors.black),
        ),
      ),
    );
  }
}
