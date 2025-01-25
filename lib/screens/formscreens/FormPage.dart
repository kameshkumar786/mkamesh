import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrappeCrudForm extends StatefulWidget {
  final String doctype;
  final String baseUrl;

  const FrappeCrudForm({required this.doctype, required this.baseUrl});

  @override
  _FrappeCrudFormState createState() => _FrappeCrudFormState();
}

class _FrappeCrudFormState extends State<FrappeCrudForm> {
  List<dynamic> fields = [];
  Map<String, dynamic> formData = {};
  Map<String, dynamic> curFrm = {};
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
            'https://teamloser.in/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          curFrm = data;
          fields = data['docs'][0]['fields'];
          for (var field in fields) {
            formData[field['fieldname']] =
                null; // Initialize all fields with null
          }
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load Doctype fields');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError(e.toString());
    }
  }

  Future<List<dynamic>> fetchLinkOptions(
      String linkDoctype, String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          'https://teamloser.in/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query&reference_doctype=${widget.doctype}&filters=[]',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data['message']);
        return data['message'] ?? [];
      } else {
        throw Exception('Failed to fetch link options');
      }
    } catch (e) {
      showError(e.toString());
      return [];
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> createOrUpdateDocument() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('https://teamloser.in/api/resource/${widget.doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode(formData),
      );

      if (response.statusCode == 200) {
        showSuccess('Document saved successfully');
      } else {
        throw Exception('Failed to save document');
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CRUD Form: ${widget.doctype}'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: fields.map((field) {
                        final fieldType = field['fieldtype'];
                        final fieldName = field['fieldname'];
                        final label = field['label'];

                        if (fieldType == 'Section Break') {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              label ?? '',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          );
                        } else if (fieldType == 'Column Break') {
                          return SizedBox(width: 16); // Space between columns
                        } else if (fieldType == 'Data' ||
                            fieldType == 'Email') {
                          return TextField(
                            decoration: InputDecoration(labelText: label),
                            onChanged: (value) {
                              setState(() {
                                formData[fieldName] = value;
                              });
                            },
                          );
                        } else if (fieldType == 'Link') {
                          return LinkField(
                            fieldLabel: label,
                            fieldName: fieldName,
                            linkDoctype: field['options'],
                            fetchLinkOptions: fetchLinkOptions,
                            formData: formData,
                            onValueChanged: (value) {
                              setState(() {
                                formData[fieldName] = value;
                              });
                            },
                          );
                        } else if (fieldType == 'Select' &&
                            field['options'] != null) {
                          final options =
                              (field['options'] as String).split('\n');
                          return DropdownButtonFormField(
                            decoration: InputDecoration(labelText: label),
                            items: options
                                .map((option) => DropdownMenuItem(
                                      value: option,
                                      child: Text(option),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                formData[fieldName] = value;
                              });
                            },
                          );
                        }
                        return SizedBox
                            .shrink(); // Ignore unsupported field types
                      }).toList(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: createOrUpdateDocument,
                    child: Text('Save Document'),
                  ),
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
    required this.formData,
    required this.fetchLinkOptions,
    required this.onValueChanged,
  });

  @override
  _LinkFieldState createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  String? _selectedValue;
  String? _selectedDescription;

  void _openSearchModal(BuildContext context) async {
    final selectedItem = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return SearchModal(
          fieldLabel: widget.fieldLabel,
          fieldName: widget.fieldName,
          formData: widget.formData,
          linkDoctype: widget.linkDoctype,
          fetchLinkOptions: widget.fetchLinkOptions,
        );
      },
    );

    if (selectedItem != null) {
      setState(() {
        _selectedValue = selectedItem['value'];
        _selectedDescription =
            selectedItem['description'] ?? selectedItem['value'];
      });
      widget.onValueChanged(_selectedValue); // Notify parent of the change
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSearchModal(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fieldLabel,
            style: TextStyle(fontSize: 15, color: Colors.black),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Aligns items to the edges
              children: [
                Expanded(
                  // Allows the text to take up available space
                  child: Text(
                    '${widget.formData[widget.fieldName] ?? 'Select ${widget.fieldLabel}'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedDescription == null
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down, // Dropdown icon
                  color: Colors.black, // Icon color
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchModal extends StatefulWidget {
  final String fieldLabel;
  final String fieldName;
  final String linkDoctype;
  final Future<List<dynamic>> Function(String, String) fetchLinkOptions;
  final Map<String, dynamic> formData;

  const SearchModal({
    required this.fieldLabel,
    required this.fieldName,
    required this.linkDoctype,
    required this.fetchLinkOptions,
    required this.formData,
  });

  @override
  _SearchModalState createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _options = [];
  bool _isLoading = false;

  Future<void> _searchOptions(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results =
          await widget.fetchLinkOptions(widget.linkDoctype, query.trim());
      setState(() {
        _options = results;
      });
    } catch (e) {
      print('Error fetching options: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch options')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ${widget.fieldLabel}...',
                suffixIcon: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                        ),
                      )
                    : Icon(Icons.search, color: Colors.black),
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
              style: TextStyle(fontSize: 13, color: Colors.black),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _searchOptions(query);
                } else {
                  setState(() {
                    _options = [];
                  });
                }
              },
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_options.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return ListTile(
                      title: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: widget.formData[widget.fieldName] ==
                                  option['value']
                              ? Colors.black
                              : Colors.grey[
                                  200], // Change background color based on selection
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black, // Bottom border color
                              width: 1.0, // Bottom border width
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['value'], // Display the value in bold
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.formData[widget.fieldName] ==
                                        option['value']
                                    ? Colors.white
                                    : Colors
                                        .black, // Change text color based on selection
                              ),
                            ),
                            SizedBox(
                                height: 4), // Adds some space between the rows
                            if (option['description'] != null &&
                                option['description'].isNotEmpty)
                              Text(
                                option[
                                    'description'], // Display the description
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.formData[widget.fieldName] ==
                                          option['value']
                                      ? Colors.white
                                      : Colors
                                          .black, // Change text color based on selection
                                ),
                              ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(
                          context,
                          {
                            'value': option['value'].toString(),
                            'description':
                                (option['description'] ?? option['value'])
                                    .toString(),
                          },
                        );
                      },
                    );
                  },
                ),
              )
            else
              Text(
                'No results found',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
