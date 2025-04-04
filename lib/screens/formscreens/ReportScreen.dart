import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/screens/formscreens/FormPage.dart';
import 'package:mkamesh/screens/formscreens/ReportDetailsScreen.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReportScreen extends StatefulWidget {
  ReportScreen();

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String doctype = 'Report';
  List<Map<String, dynamic>> doctypeData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<String> selectedFields = [];
  List<Map<String, dynamic>> availableFields = [];
  Map<String, dynamic> filters = {};
  String sortBy = 'name';
  bool ascending = true;

  String searchInput = '';
  String selectedFieldName = '';
  String selectedOperator = '=';
  Map<String, List<Map<String, dynamic>>> allFilters =
      {}; // Store multiple filters per field

  List<Map<String, dynamic>> filtersList = [];
  final TextEditingController _searchController = TextEditingController();

  List<String> excludedFieldTypes = [
    "Attach",
    "Attach Image",
    "Autocomplete",
    "Barcode",
    "Button",
    "Column Break",
    "Fold",
    "Geolocation",
    "Heading",
    "HTML",
    "HTML Editor",
    "Icon",
    "Image",
    "Markdown Editor",
    "Password",
    "Section Break",
    "Signature",
    "Tab Break",
    "Table",
    "Table MultiSelect",
    "Text Editor"
  ];

  @override
  void initState() {
    super.initState();
    fetchDoctypeFields();
    fetchDoctypeData();
  }

  bool _isFieldVisible(Map<String, dynamic> field) {
    // Add conditions to filter out hidden fields, e.g.:
    // Exclude fields with type 'image', 'section_break', 'tab', etc.
    List<String> excludedTypes = ['image', 'section_break', 'tab'];
    return !excludedTypes.contains(field['type']);
  }

  Future<void> fetchDoctypeFields() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/resource/DocType/${doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // print(data['data']['fields']);
        setState(() {
          availableFields =
              List<Map<String, dynamic>>.from(data['data']['fields']);

          availableFields = availableFields.where((field) {
            return !excludedFieldTypes.contains(field['fieldtype']) &&
                field['hidden'] != 1;
          }).toList();

          selectedFields = availableFields
              .where((field) => field['in_list_view'] == 1)
              .map((field) => field['fieldname'].toString())
              .toList();

          if (!selectedFields.contains('name')) {
            selectedFields.insert(0, 'name');
            availableFields.insert(
              0,
              {'fieldname': 'name', 'label': 'ID', 'in_list_view': 1},
            );
          }
        });
      } else {
        throw Exception('Failed to load fields');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> fetchDoctypeData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      // final String filtersJson = [] as String;
      // final String encodedFilters = Uri.encodeComponent(filtersJson);

      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/resource/${doctype}?filters={}&fields=["*"]'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          doctypeData = List<Map<String, dynamic>>.from(data['data']);
          applyFiltersAndSort();
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print(e);
    }
  }

  void applyFiltersAndSort() {
    setState(() {
      filteredData = doctypeData.where((doc) {
        for (var field in filters.keys) {
          if (doc[field] != filters[field]) return false;
        }
        return true;
      }).toList();

      filteredData.sort((a, b) {
        int compare = ascending
            ? a[sortBy].toString().compareTo(b[sortBy].toString())
            : b[sortBy].toString().compareTo(a[sortBy].toString());
        return compare;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes back button

        // title: Text(
        //   'All Report List',
        //   style: TextStyle(
        //     fontSize: 18,
        //     fontWeight: FontWeight.bold,
        //     color: Colors.black,
        //   ),
        // ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   'Report List',
            //   style: TextStyle(
            //     fontSize: 18,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.black,
            //   ),
            // ),
            // Text(
            //   'Module Screen',
            //   style: TextStyle(fontSize: 16, color: Colors.black),
            // ),
            // SizedBox(height: 8), // Spacing between title and TextField
            Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.black,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {}); // Update UI after clearing text
                          },
                        )
                      : null,
                  // labelText: 'Search anything...',
                  // labelStyle: TextStyle(fontSize: 14, color: Colors.black),
                  hintText: 'Search Reports...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        actions: [],
      ),
      body: ListView.builder(
        itemCount: filteredData.length,
        itemBuilder: (context, index) {
          final doc = filteredData[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportDetailsScreen(
                      report_name: doc['name'],
                    ),
                  ),
                );
              },
              child: Card(
                color: Colors.white, // Set the background color to white
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      10), // Optional: rounded corners for card
                ),
                elevation: 1, // Optional: slight elevation for card shadow
                shadowColor: Colors.blue, // Set the color of the shadow to blue
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: selectedFields.map((field) {
                      final label = availableFields.firstWhere(
                          (f) => f['fieldname'] == field,
                          orElse: () => {'label': field})['label'];
                      String fieldValue =
                          doc.containsKey(field) && doc[field] != null
                              ? doc[field].toString()
                              : 'N/A';
                      return Text(
                        label == 'ID' ? '$fieldValue' : '$label: $fieldValue',
                        style: TextStyle(
                          fontSize: label == 'ID'
                              ? 15
                              : 14, // Larger font size for 'Name' field
                          fontWeight: label == 'ID'
                              ? FontWeight.bold
                              : FontWeight.normal, // Make 'Name' field bold
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LinkField extends StatefulWidget {
  final String linkDoctype;
  final void Function(String?) onSelected;
  final String? initialValue;

  const LinkField({
    required this.linkDoctype,
    required this.onSelected,
    this.initialValue,
  });

  @override
  _LinkFieldState createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _options = [];
  List<dynamic> _filteredOptions = [];
  String _selectedValue = '';

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue ?? '';
    fetchOptions('');
  }

  Future<void> fetchOptions(String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
          'http://localhost:8000/api/method/frappe.desk.search.search_link?doctype=${widget.linkDoctype}&txt=$query',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _options = data['message'] ?? [];
          _filteredOptions = _options;
        });
      } else {
        throw Exception('Failed to fetch link options');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showLinkSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (query) async {
                      await fetchOptions(query);
                      setState(() {
                        _filteredOptions = _options.where((option) {
                          return option['value']
                              .toString()
                              .toLowerCase()
                              .contains(query.toLowerCase());
                        }).toList();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Search ${widget.linkDoctype}',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        return ListTile(
                          title: Text(
                            option['value'],
                            style: TextStyle(
                              color: _selectedValue == option['value']
                                  ? Colors.blue
                                  : Colors.black,
                              fontWeight: _selectedValue == option['value']
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: option['description'] != null
                              ? Text(option['description'])
                              : null,
                          onTap: () {
                            Navigator.pop(context, option['value']);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selectedValue) {
      if (selectedValue != null) {
        setState(() {
          _selectedValue = selectedValue;
          widget.onSelected(_selectedValue);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showLinkSelectionModal,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Select ${widget.linkDoctype}',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          _selectedValue.isEmpty ? 'Tap to select' : _selectedValue,
          style: TextStyle(
            color: _selectedValue.isEmpty ? Colors.grey : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
