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
                  child: buildFieldsWithSections(fields),
                ),
              ),
      );
    } else {
      return DefaultTabController(
        length: 3, // Number of tabs
        child: Scaffold(
          appBar: AppBar(
            title: Text('Top Tab View'),
            bottom: TabBar(
              tabs: [
                Tab(text: 'Form'),
                Tab(text: 'Comments'),
                Tab(text: 'Attachments & Assigning'),
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
                        child: TabContent2(
                          doctype: widget.doctype,
                          docname: widget.docname,
                          baseUrl: widget.baseUrl,
                        ),
                      ),
                      SingleChildScrollView(
                        child: TabContent3(
                          doctype: widget.doctype,
                          docname: widget.docname,
                          baseUrl: widget.baseUrl,
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
  final String docname;
  final String baseUrl;

  const TabContent2({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
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
    fetchComments();
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
            '${widget.baseUrl}/api/method/frappe.desk.form.utils.save_comment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({
          'doctype': widget.doctype,
          'docname': widget.docname,
          'comment': _messageController.text,
        }),
      );

      if (response.statusCode == 200) {
        _messageController.clear();
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
          SizedBox(height: 16),
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
                    return ListTile(
                      title: Text(comment['comment_by']),
                      subtitle: Text(comment['content']),
                    );
                  },
                ),
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

  const TabContent3({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
  });

  @override
  _TabContent3State createState() => _TabContent3State();
}

class _TabContent3State extends State<TabContent3> {
  List<Map<String, dynamic>> attachments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAttachments();
  }

  Future<void> fetchAttachments() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.utils.get_attachments?doctype=${widget.doctype}&docname=${widget.docname}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          attachments = List<Map<String, dynamic>>.from(data['message']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load attachments');
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Attachments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    return ListTile(
                      title: Text(attachment['file_name']),
                      subtitle: Text(attachment['file_url']),
                      onTap: () {
                        // Open the attachment URL
                      },
                    );
                  },
                ),
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
