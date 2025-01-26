import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;

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
    String fieldType = field['fieldtype'] ?? '';
    String fieldName = field['fieldname'] ?? '';
    String? label = field['label'];
    bool readOnly = _convertToBool(field['read_only']);
    bool hidden = _convertToBool(field['hidden']);
    bool required = _convertToBool(field['reqd']);

    final controller = controllers[fieldName];
    if (hidden) {
      return SizedBox.shrink(); // Return an empty widget for hidden fields
    }

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
                  });
                },
              ),
            if (fieldType == 'Select' && field['options'] != null)
              DropdownButtonFormField<String>(
                value: formData[fieldName],
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
                    formData[fieldName] =
                        value; // Update the form data with the selected value
                    controller?.text =
                        value ?? ''; // Update the controller text if applicable
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
                  });
                },
              ),
            if (fieldType == 'Table')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('need to create Table: $label'),
                  // Implement your table logic here
                  // For example, you can use a ListView to display rows
                  // and allow adding/removing rows
                ],
              ),
            if (fieldType == 'Dynamic Link')
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
                  });
                },
              ),
          ],
        ),
      ),
    );
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
              padding: const EdgeInsets.symmetric(vertical: 16.0),
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
            padding: const EdgeInsets.symmetric(vertical: 16.0),
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
              padding: const EdgeInsets.all(8.0),
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

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text('CRUD Form: ${widget.doctype}'),
  //     ),
  //     backgroundColor: Colors.white,
  //     body: isLoading
  //         ? Center(child: CircularProgressIndicator())
  //         : Padding(
  //             padding: const EdgeInsets.all(16.0),
  //             child: SingleChildScrollView(
  //               child: buildFieldsWithSections(fields),
  //             ),
  //           ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text('Top Tab View'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Tab 1'),
              Tab(text: 'Tab 2'),
              Tab(text: 'Tab 3'),
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
                      child: buildFieldsWithSections(fields),
                    ),
                    SingleChildScrollView(
                      child: TabContent2(),
                    ),
                    SingleChildScrollView(
                      child: buildFieldsWithSections(fields),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class TabContent2 extends StatefulWidget {
  @override
  _TabContent2State createState() => _TabContent2State();
}

class _TabContent2State extends State<TabContent2>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  List<String> messages = [];
  // final List<Comment> comments = []; // List to hold comments

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super.build to ensure the keep-alive works
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Comments and Messages',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Add a message',
              hintText: 'Type your message here...',
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                setState(() {
                  messages.add(
                      _messageController.text); // Add the message to the list
                  _messageController.clear(); // Clear the text field
                });
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black, // White text color
            ),
            child: Text('Save Message'),
          ),
          // Simulate comments/messages
          //  ListView.builder(
          // shrinkWrap: true,
          // physics: NeverScrollableScrollPhysics(), // Prevent scrolling
          // itemCount: comments.length,
          // itemBuilder: (context, index) {
          // final comment = comments[index];
          // return ListTile(
          //   title: Text(comment.username),
          //   subtitle: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(comment.message),
          //       SizedBox(height: 4),
          //       Text(
          //         '${comment.createdAt.toLocal()}'.split(' ')[0], // Display date
          //         style: TextStyle(fontSize: 12, color: Colors.grey),
          //       ),
          //     ],
          //   ),
          // );

          // Text area for adding messages
        ],
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
  Widget build(BuildContext context) {
    return TextFormField(
      controller: TextEditingController(text: _selectedValue),
      decoration: InputDecoration(
        labelText: widget.fieldLabel,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.arrow_drop_down), // Add the arrow icon here
      ),
      readOnly: true,
      onTap: () async {
        // Fetch link options and handle the selection logic
        _options = await widget.fetchLinkOptions(widget.linkDoctype, '');
        _filteredOptions = _options; // Initialize filtered options

        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white, // Set modal background color to white
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Select ${widget.fieldLabel}',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                          _filteredOptions = _options
                              .where((option) =>
                                  option['value']
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ||
                                  option['description']
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Search ${widget.fieldLabel}',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: _filteredOptions
                          .map((option) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey
                                            .shade300), // Bottom border for each item
                                  ),
                                ),
                                child: ListTile(
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option['value'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (option['description'] != null &&
                                          option['description'].isNotEmpty)
                                        Text(
                                          option['description'],
                                          style: TextStyle(
                                            fontSize:
                                                12, // Smaller font size for description
                                            color: Colors
                                                .grey, // Gray color for description
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    // Concatenate value and description for selected value
                                    String selectedValue = option['value'];
                                    String selectedDescription =
                                        option['description'] ?? '';
                                    Navigator.pop(context,
                                        '$selectedValue - $selectedDescription');
                                  },
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        );

        if (selected != null) {
          setState(() {
            _selectedValue = selected;
            widget.onValueChanged(_selectedValue);
          });
        }
      },
    );
  }
}
