import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mkamesh/screens/formscreens/FormPage.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DoctypeListView extends StatefulWidget {
  final String doctype;
  final dynamic prefilters;

  DoctypeListView({required this.doctype, required dynamic this.prefilters});

  @override
  _DoctypeListViewState createState() => _DoctypeListViewState();
}

class _DoctypeListViewState extends State<DoctypeListView> {
  List<Map<String, dynamic>> doctypeData = [];
  List<Map<String, dynamic>> filteredData = [];
  List<String> selectedFields = [];
  List<Map<String, dynamic>> availableFields = [];
  Map<String, dynamic> filters = {};
  String sortBy = 'modified';
  bool ascending = false;
  int totalCount = 0; // Add count variable

  String searchInput = '';
  String selectedFieldName = '';
  String selectedOperator = '=';
  Map<String, List<Map<String, dynamic>>> allFilters =
      {}; // Store multiple filters per field

  List<Map<String, dynamic>> filtersList = [];

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
    fetchCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this screen
    fetchDoctypeData();
    fetchCount();
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
        Uri.parse(
            'http://localhost:8000/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allDocs = data['docs']; // Contains all DocTypes

        // Map to store fields by DocType name
        Map<String, List<Map<String, dynamic>>> doctypeFields = {};

        // Populate the map with fields from all DocTypes
        for (var doc in allDocs) {
          String doctypeName = doc['name'];
          List<dynamic> fields = doc['fields'];
          doctypeFields[doctypeName] =
              fields.map((field) => Map<String, dynamic>.from(field)).toList();
        }

        // Process fields for the parent DocType and its child tables
        List<Map<String, dynamic>> allFields = [];
        List<dynamic> parentFields = doctypeFields[widget.doctype] ?? [];

        for (var field in parentFields) {
          // Add parent-level fields to allFields
          if (!excludedFieldTypes.contains(field['fieldtype']) &&
              field['hidden'] != 1) {
            allFields.add(Map<String, dynamic>.from(field));
          }

          // Handle child tables for filters (but not for list UI)
          if (field['fieldtype'] == 'Table' && field['options'] != null) {
            String childDoctype = field['options']; // e.g., "Sales Order Item"
            List<Map<String, dynamic>> childFields =
                doctypeFields[childDoctype] ?? [];

            for (var childField in childFields) {
              if (!excludedFieldTypes.contains(childField['fieldtype']) &&
                  childField['hidden'] != 1) {
                childField['fieldname'] =
                    '$childDoctype,${childField['fieldname']}';
                childField['label'] =
                    '${childField['label'] ?? childField['fieldname']} (${field['label']})';
                allFields.add(Map<String, dynamic>.from(childField));
              }
            }
          }
        }

        setState(() {
          availableFields =
              allFields; // Includes both parent and child fields for filters

          // Ensure 'modified' is present for sorting
          if (!availableFields.any((f) => f['fieldname'] == 'modified')) {
            availableFields.insert(0, {
              'fieldname': 'modified',
              'fieldtype': 'Date',
              'label': 'Last Modified'
            });
            availableFields.insert(0, {
              'fieldname': 'creation',
              'fieldtype': 'Date',
              'label': 'Created On'
            });

            availableFields.insert(0, {
              'fieldname': 'owner',
              'fieldtype': 'Link',
              'options': 'User',
              'label': 'Created By'
            });
          }

          // Only include main DocType fields in selectedFields for the list UI
          selectedFields = parentFields
              .where((field) =>
                  !excludedFieldTypes.contains(field['fieldtype']) &&
                  field['hidden'] != 1 &&
                  field['in_list_view'] == 1)
              .map((field) => field['fieldname'].toString())
              .toList();

          // Ensure 'name' is included
          if (!selectedFields.contains('name')) {
            selectedFields.insert(0, 'name');
            if (!allFields.any((f) => f['fieldname'] == 'name')) {
              allFields.insert(
                0,
                {'fieldname': 'name', 'label': 'ID', 'in_list_view': 1},
              );
            }
          }
        });
      } else {
        throw Exception('Failed to load fields: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching fields: $e');
    }
  }

  Future<void> fetchDoctypeData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final String filtersJson = jsonEncode(widget.prefilters);
      final String encodedFilters = Uri.encodeComponent(filtersJson);

      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/resource/${widget.doctype}?filters=${encodedFilters}&fields=["*"]'),
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
          // Update count from actual data
          // totalCount = doctypeData.length;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> fetchCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // Prepare filters for the API (use filtersList if available, else widget.prefilters)
      List<List<dynamic>> filterList = [];
      if (filtersList.isNotEmpty) {
        for (var filter in filtersList) {
          filterList.add([
            filter['field'],
            filter['operator'],
            filter['value'],
          ]);
        }
      } else if (widget.prefilters != null && widget.prefilters is List) {
        filterList = List<List<dynamic>>.from(widget.prefilters);
      }

      final Map<String, String> payload = {
        'doctype': widget.doctype,
        'filters': jsonEncode(filterList),
        'fields': '[]',
        'distinct': 'false',
        'limit': '1001',
      };

      final response = await http.post(
        Uri.parse(
            'http://localhost:8000/api/method/frappe.desk.reportview.get_count'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': '$token',
        },
        body: payload,
      );

      print('Count API Response status: \\${response.statusCode}');
      print('Count API Response body: \\${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalCount = data['message'] ?? 0;
        });
      } else {
        print('Count API failed: \\${response.body}');
        setState(() {
          totalCount = filteredData.length;
        });
      }
    } catch (e) {
      print('Error in fetchCount: $e');
      setState(() {
        totalCount = filteredData.length;
      });
    }
  }

  // Alternative method to get count from actual data
  void updateCountFromData() {
    setState(() {
      // totalCount = filteredData.length;
    });
    print('Updated count from data: $totalCount');
  }

  void _selectDateRange(BuildContext context) async {
    DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: filters[selectedFieldName] != null
          ? DateTimeRange(
              start: DateTime.parse(filters[selectedFieldName]['from']),
              end: DateTime.parse(filters[selectedFieldName]['to']),
            )
          : DateTimeRange(start: now, end: now.add(Duration(days: 7))),
    );

    if (picked != null) {
      setState(() {
        filters[selectedFieldName] = {
          'from': picked.start.toIso8601String().split('T')[0],
          'to': picked.end.toIso8601String().split('T')[0],
        };
      });
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
        // Handle datetime fields (like 'modified', 'creation', etc.)
        if (sortBy == 'modified' || sortBy == 'creation') {
          DateTime? dateA = a[sortBy] != null
              ? DateTime.tryParse(a[sortBy].toString())
              : null;
          DateTime? dateB = b[sortBy] != null
              ? DateTime.tryParse(b[sortBy].toString())
              : null;

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return ascending ? -1 : 1;
          if (dateB == null) return ascending ? 1 : -1;

          return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        }

        // Handle other field types
        int compare = ascending
            ? a[sortBy].toString().compareTo(b[sortBy].toString())
            : b[sortBy].toString().compareTo(a[sortBy].toString());
        return compare;
      });

      // Update count based on filtered data
      // totalCount = filteredData.length;
    });
  }

  void showFieldSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Select Fields to Display'),
          content: SingleChildScrollView(
            child: Column(
              children: availableFields.map((field) {
                return CheckboxListTile(
                  title: Text(field['label'] ?? field['fieldname']),
                  value: selectedFields.contains(field['fieldname']),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedFields.add(field['fieldname']);
                      } else {
                        selectedFields.remove(field['fieldname']);
                      }
                    });
                  },
                  activeColor: Colors.black,
                  checkColor: Colors.white,
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                final selectedField = availableFields.firstWhere(
                  (field) => field['fieldname'] == selectedFieldName,
                  orElse: () => <String, dynamic>{},
                );
                final selectedFieldType = selectedField['fieldtype'];

                return Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'Add Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            children: [
                              // Add filter row
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add New Filter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    // Field selection
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: 'Field',
                                        labelStyle: TextStyle(
                                            fontSize: 12, color: Colors.black),
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      dropdownColor: Colors.white,
                                      value: selectedFieldName.isNotEmpty
                                          ? selectedFieldName
                                          : null,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedFieldName = value ?? '';
                                          filters[selectedFieldName] =
                                              null; // Reset value when field changes
                                        });
                                      },
                                      items: availableFields
                                          .map((field) =>
                                              DropdownMenuItem<String>(
                                                value: field['fieldname'],
                                                child: Text(
                                                  field['label'] ??
                                                      field['fieldname'],
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.black),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                    SizedBox(height: 12),
                                    // Operator selection
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        labelText: 'Operator',
                                        labelStyle: TextStyle(
                                            fontSize: 12, color: Colors.black),
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      dropdownColor: Colors.white,
                                      value: selectedOperator,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedOperator = value!;
                                          filters[selectedFieldName] =
                                              null; // Reset value when operator changes
                                        });
                                      },
                                      items: [
                                        {"value": "=", "label": "Equals"},
                                        {"value": "!=", "label": "Not Equals"},
                                        {"value": "like", "label": "Like"},
                                        {
                                          "value": "not like",
                                          "label": "Not Like"
                                        },
                                        {"value": "in", "label": "In"},
                                        {"value": "not in", "label": "Not In"},
                                        {"value": "is", "label": "Is"},
                                        {"value": ">", "label": ">"},
                                        {"value": "<", "label": "<"},
                                        {"value": ">=", "label": ">="},
                                        {"value": "<=", "label": "<="},
                                        {
                                          "value": "Between",
                                          "label": "Between"
                                        },
                                        if (selectedFieldType == 'Date' ||
                                            selectedFieldType == 'Datetime' ||
                                            selectedFieldType == 'Time')
                                          {
                                            "value": "Timespan",
                                            "label": "Timespan"
                                          },
                                        if (selectedFieldType == 'Link') ...[
                                          {
                                            "value": "descendants of",
                                            "label": "Descendants Of"
                                          },
                                          {
                                            "value": "not descendants of",
                                            "label": "Not Descendants Of"
                                          },
                                          {
                                            "value": "ancestors of",
                                            "label": "Ancestors Of"
                                          },
                                          {
                                            "value": "not ancestors of",
                                            "label": "Not Ancestors Of"
                                          },
                                        ],
                                      ]
                                          .map((item) =>
                                              DropdownMenuItem<String>(
                                                value: item['value']!,
                                                child: Text(item['label']!,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black)),
                                              ))
                                          .toList(),
                                    ),
                                    SizedBox(height: 12),
                                    // Value field
                                    Builder(
                                      builder: (context) {
                                        final selectedField =
                                            availableFields.firstWhere(
                                          (field) =>
                                              field['fieldname'] ==
                                              selectedFieldName,
                                          orElse: () => <String, dynamic>{},
                                        );
                                        if (selectedField.isEmpty) {
                                          return TextField(
                                            enabled: false,
                                            decoration: InputDecoration(
                                              labelText: 'Select a field first',
                                              labelStyle: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            style:
                                                TextStyle(color: Colors.black),
                                          );
                                        }
                                        final fieldType =
                                            selectedField['fieldtype'];
                                        // Handle "is" operator
                                        if (selectedOperator == 'is') {
                                          return DropdownButtonFormField<
                                              String>(
                                            decoration: InputDecoration(
                                              labelText: 'Value',
                                              labelStyle: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            dropdownColor: Colors.white,
                                            items: [
                                              DropdownMenuItem(
                                                  value: 'Set',
                                                  child: Text('Set',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.black))),
                                              DropdownMenuItem(
                                                  value: 'Not Set',
                                                  child: Text('Not Set',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.black))),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                filters[selectedFieldName] =
                                                    value;
                                              });
                                            },
                                          );
                                        }
                                        // Handle "Between" operator
                                        if (selectedOperator == 'Between') {
                                          if (fieldType == 'Date' ||
                                              fieldType == 'Datetime') {
                                            return Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () async {
                                                          final pickedDate =
                                                              await showDatePicker(
                                                            context: context,
                                                            initialDate:
                                                                DateTime.now(),
                                                            firstDate:
                                                                DateTime(1900),
                                                            lastDate:
                                                                DateTime(2100),
                                                            builder: (context,
                                                                    child) =>
                                                                Theme(
                                                              data: ThemeData
                                                                      .light()
                                                                  .copyWith(
                                                                primaryColor:
                                                                    Colors
                                                                        .white,
                                                                hintColor:
                                                                    Colors
                                                                        .black,
                                                                colorScheme: ColorScheme.light(
                                                                    primary: Colors
                                                                        .black,
                                                                    onPrimary:
                                                                        Colors
                                                                            .white,
                                                                    surface: Colors
                                                                        .white,
                                                                    onSurface:
                                                                        Colors
                                                                            .black),
                                                                dialogBackgroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                              child: child!,
                                                            ),
                                                          );
                                                          if (pickedDate !=
                                                              null) {
                                                            final formattedDate =
                                                                pickedDate
                                                                    .toIso8601String()
                                                                    .split(
                                                                        'T')[0];
                                                            setState(() {
                                                              filters[
                                                                  selectedFieldName] = {
                                                                'from':
                                                                    formattedDate,
                                                                'to': filters[
                                                                            selectedFieldName]
                                                                        ?[
                                                                        'to'] ??
                                                                    formattedDate
                                                              };
                                                            });
                                                          }
                                                        },
                                                        child: InputDecorator(
                                                          decoration:
                                                              InputDecoration(
                                                            labelText:
                                                                'From Date',
                                                            labelStyle:
                                                                TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black),
                                                            border:
                                                                OutlineInputBorder(),
                                                            filled: true,
                                                            fillColor:
                                                                Colors.white,
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8),
                                                            suffixIcon: Icon(
                                                                Icons
                                                                    .calendar_today,
                                                                size: 16,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                          child: Text(
                                                            filters[selectedFieldName]
                                                                    ?['from'] ??
                                                                'Select date',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () async {
                                                          final pickedDate =
                                                              await showDatePicker(
                                                            context: context,
                                                            initialDate:
                                                                DateTime.now(),
                                                            firstDate:
                                                                DateTime(1900),
                                                            lastDate:
                                                                DateTime(2100),
                                                            builder: (context,
                                                                    child) =>
                                                                Theme(
                                                              data: ThemeData
                                                                      .light()
                                                                  .copyWith(
                                                                primaryColor:
                                                                    Colors
                                                                        .white,
                                                                hintColor:
                                                                    Colors
                                                                        .black,
                                                                colorScheme: ColorScheme.light(
                                                                    primary: Colors
                                                                        .black,
                                                                    onPrimary:
                                                                        Colors
                                                                            .white,
                                                                    surface: Colors
                                                                        .white,
                                                                    onSurface:
                                                                        Colors
                                                                            .black),
                                                                dialogBackgroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                              child: child!,
                                                            ),
                                                          );
                                                          if (pickedDate !=
                                                              null) {
                                                            final formattedDate =
                                                                pickedDate
                                                                    .toIso8601String()
                                                                    .split(
                                                                        'T')[0];
                                                            setState(() {
                                                              filters[
                                                                  selectedFieldName] = {
                                                                'from': filters[
                                                                            selectedFieldName]
                                                                        ?[
                                                                        'from'] ??
                                                                    formattedDate,
                                                                'to':
                                                                    formattedDate
                                                              };
                                                            });
                                                          }
                                                        },
                                                        child: InputDecorator(
                                                          decoration:
                                                              InputDecoration(
                                                            labelText:
                                                                'To Date',
                                                            labelStyle:
                                                                TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black),
                                                            border:
                                                                OutlineInputBorder(),
                                                            filled: true,
                                                            fillColor:
                                                                Colors.white,
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8),
                                                            suffixIcon: Icon(
                                                                Icons
                                                                    .calendar_today,
                                                                size: 16,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                          child: Text(
                                                            filters[selectedFieldName]
                                                                    ?['to'] ??
                                                                'Select date',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          } else {
                                            // For other field types, show text inputs
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      labelText: 'From',
                                                      labelStyle: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black),
                                                      border:
                                                          OutlineInputBorder(),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8),
                                                    ),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black),
                                                    keyboardType: fieldType ==
                                                                'Int' ||
                                                            fieldType ==
                                                                'Float' ||
                                                            fieldType ==
                                                                'Currency'
                                                        ? TextInputType.number
                                                        : TextInputType.text,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        filters[
                                                            selectedFieldName] = {
                                                          'from': value,
                                                          'to':
                                                              filters[selectedFieldName]
                                                                      ?['to'] ??
                                                                  value
                                                        };
                                                      });
                                                    },
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      labelText: 'To',
                                                      labelStyle: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black),
                                                      border:
                                                          OutlineInputBorder(),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8),
                                                    ),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black),
                                                    keyboardType: fieldType ==
                                                                'Int' ||
                                                            fieldType ==
                                                                'Float' ||
                                                            fieldType ==
                                                                'Currency'
                                                        ? TextInputType.number
                                                        : TextInputType.text,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        filters[
                                                            selectedFieldName] = {
                                                          'from': filters[
                                                                      selectedFieldName]
                                                                  ?['from'] ??
                                                              value,
                                                          'to': value
                                                        };
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                        }
                                        // Handle "Timespan" operator
                                        if (selectedOperator == 'Timespan' &&
                                            (fieldType == 'Date' ||
                                                fieldType == 'Datetime')) {
                                          return DropdownButtonFormField<
                                              String>(
                                            decoration: InputDecoration(
                                              labelText: 'Timespan',
                                              labelStyle: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            dropdownColor: Colors.white,
                                            items: [
                                              {
                                                "value": "last week",
                                                "label": "Last Week"
                                              },
                                              {
                                                "value": "last month",
                                                "label": "Last Month"
                                              },
                                              {
                                                "value": "last quarter",
                                                "label": "Last Quarter"
                                              },
                                              {
                                                "value": "last 6 months",
                                                "label": "Last 6 months"
                                              },
                                              {
                                                "value": "last year",
                                                "label": "Last Year"
                                              },
                                              {
                                                "value": "yesterday",
                                                "label": "Yesterday"
                                              },
                                              {
                                                "value": "today",
                                                "label": "Today"
                                              },
                                              {
                                                "value": "tomorrow",
                                                "label": "Tomorrow"
                                              },
                                              {
                                                "value": "this week",
                                                "label": "This Week"
                                              },
                                              {
                                                "value": "this month",
                                                "label": "This Month"
                                              },
                                              {
                                                "value": "this quarter",
                                                "label": "This Quarter"
                                              },
                                              {
                                                "value": "this year",
                                                "label": "This Year"
                                              },
                                              {
                                                "value": "next week",
                                                "label": "Next Week"
                                              },
                                              {
                                                "value": "next month",
                                                "label": "Next Month"
                                              },
                                              {
                                                "value": "next quarter",
                                                "label": "Next Quarter"
                                              },
                                              {
                                                "value": "next 6 months",
                                                "label": "Next 6 months"
                                              },
                                              {
                                                "value": "next year",
                                                "label": "Next Year"
                                              }
                                            ]
                                                .map((item) =>
                                                    DropdownMenuItem<String>(
                                                      value: item['value']!,
                                                      child: Text(
                                                          item['label']!,
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .black)),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                filters[selectedFieldName] =
                                                    value;
                                              });
                                            },
                                          );
                                        }
                                        // Handle "Like" or "Not Like" operators
                                        if (selectedOperator == 'like' ||
                                            selectedOperator == 'not like') {
                                          return TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Enter Value',
                                              labelStyle: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black),
                                            keyboardType: fieldType == 'Int'
                                                ? TextInputType.number
                                                : TextInputType.text,
                                            onChanged: (value) {
                                              if (fieldType == 'Int') {
                                                if (int.tryParse(value) !=
                                                    null) {
                                                  setState(() {
                                                    filters[selectedFieldName] =
                                                        value;
                                                  });
                                                }
                                              } else {
                                                setState(() {
                                                  filters[selectedFieldName] =
                                                      value;
                                                });
                                              }
                                            },
                                          );
                                        }
                                        // Handle ">", "<", ">=", "<=" operators
                                        if (selectedOperator == '>' ||
                                            selectedOperator == '<' ||
                                            selectedOperator == '>=' ||
                                            selectedOperator == '<=') {
                                          return TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Enter Value',
                                              labelStyle: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black),
                                              border: OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.black),
                                            keyboardType: fieldType == 'Int' ||
                                                    fieldType == 'Float' ||
                                                    fieldType == 'Currency'
                                                ? TextInputType.number
                                                : TextInputType.text,
                                            onChanged: (value) {
                                              if (fieldType == 'Int' ||
                                                  fieldType == 'Float' ||
                                                  fieldType == 'Currency') {
                                                if (double.tryParse(value) !=
                                                    null) {
                                                  setState(() {
                                                    filters[selectedFieldName] =
                                                        value;
                                                  });
                                                }
                                              } else {
                                                setState(() {
                                                  filters[selectedFieldName] =
                                                      value;
                                                });
                                              }
                                            },
                                          );
                                        }
                                        // Handle other field types
                                        switch (fieldType) {
                                          case 'Select':
                                            return DropdownButtonFormField<
                                                String>(
                                              decoration: InputDecoration(
                                                labelText: 'Select Value',
                                                labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                              dropdownColor: Colors.white,
                                              items: (selectedField['options']
                                                      as String?)
                                                  ?.split('\n')
                                                  .map((option) {
                                                return DropdownMenuItem<String>(
                                                  value: option,
                                                  child: Text(option,
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.black)),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  filters[selectedFieldName] =
                                                      value;
                                                });
                                              },
                                            );
                                          case 'Link':
                                            return GestureDetector(
                                              onTap: () async {
                                                final result =
                                                    await showModalBottomSheet<
                                                        String>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  builder: (_) => LinkField(
                                                    linkDoctype: selectedField[
                                                        'options'],
                                                    initialValue: filters[
                                                            selectedFieldName]
                                                        as String?,
                                                    onSelected: (value) {
                                                      setState(() {
                                                        filters[selectedFieldName] =
                                                            value;
                                                      });
                                                    },
                                                  ),
                                                );
                                                if (result != null) {
                                                  setState(() {
                                                    filters[selectedFieldName] =
                                                        result;
                                                  });
                                                }
                                              },
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Search ${selectedField['label']}',
                                                  labelStyle: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black),
                                                  border: OutlineInputBorder(),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8),
                                                ),
                                                child: Text(
                                                  filters[selectedFieldName]
                                                          ?.toString() ??
                                                      'Tap to select',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        filters[selectedFieldName] ==
                                                                null
                                                            ? Colors.grey
                                                            : Colors.black,
                                                  ),
                                                ),
                                              ),
                                            );
                                          case 'Date':
                                            final dateController =
                                                TextEditingController();
                                            if (filters[selectedFieldName] !=
                                                null) {
                                              dateController.text =
                                                  filters[selectedFieldName];
                                            }
                                            return TextFormField(
                                              controller: dateController,
                                              readOnly: true,
                                              decoration: InputDecoration(
                                                labelText: 'Select Date',
                                                labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                suffixIcon: Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: Colors.black),
                                              ),
                                              style: TextStyle(
                                                  color: Colors.black),
                                              onTap: () async {
                                                final pickedDate =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime(2100),
                                                  builder: (context, child) =>
                                                      Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      primaryColor:
                                                          Colors.white,
                                                      hintColor: Colors.black,
                                                      colorScheme:
                                                          ColorScheme.light(
                                                              primary:
                                                                  Colors.black,
                                                              onPrimary:
                                                                  Colors.white,
                                                              surface:
                                                                  Colors.white,
                                                              onSurface:
                                                                  Colors.black),
                                                      dialogBackgroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: child!,
                                                  ),
                                                );
                                                if (pickedDate != null) {
                                                  final formattedDate =
                                                      pickedDate
                                                          .toIso8601String()
                                                          .split('T')[0];
                                                  setState(() {
                                                    filters[selectedFieldName] =
                                                        formattedDate;
                                                    dateController.text =
                                                        formattedDate;
                                                  });
                                                }
                                              },
                                            );
                                          case 'Datetime':
                                            return TextFormField(
                                              readOnly: true,
                                              decoration: InputDecoration(
                                                labelText: 'Select DateTime',
                                                labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                suffixIcon: Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: Colors.black),
                                              ),
                                              style: TextStyle(
                                                  color: Colors.black),
                                              onTap: () async {
                                                final pickedDateTime =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime(2100),
                                                  builder: (context, child) =>
                                                      Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      primaryColor:
                                                          Colors.white,
                                                      hintColor: Colors.black,
                                                      colorScheme:
                                                          ColorScheme.light(
                                                              primary:
                                                                  Colors.black,
                                                              onPrimary:
                                                                  Colors.white,
                                                              surface:
                                                                  Colors.white,
                                                              onSurface:
                                                                  Colors.black),
                                                      dialogBackgroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: child!,
                                                  ),
                                                );
                                                if (pickedDateTime != null) {
                                                  final formattedDateTime =
                                                      pickedDateTime
                                                          .toIso8601String();
                                                  setState(() {
                                                    filters[selectedFieldName] =
                                                        formattedDateTime;
                                                  });
                                                }
                                              },
                                            );
                                          case 'Int':
                                          case 'Float':
                                          case 'Currency':
                                            return TextField(
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Enter Value',
                                                labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black),
                                              onChanged: (value) {
                                                setState(() {
                                                  filters[selectedFieldName] =
                                                      fieldType == 'Int'
                                                          ? int.tryParse(value)
                                                          : double.tryParse(
                                                              value);
                                                });
                                              },
                                            );
                                          default:
                                            return TextField(
                                              decoration: InputDecoration(
                                                labelText: 'Enter Value',
                                                labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black),
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black),
                                              onChanged: (value) {
                                                setState(() {
                                                  filters[selectedFieldName] =
                                                      value;
                                                });
                                              },
                                            );
                                        }
                                      },
                                    ),
                                    SizedBox(height: 12),
                                    // Add button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                        ),
                                        onPressed: () {
                                          if (selectedFieldName.isNotEmpty &&
                                              selectedOperator.isNotEmpty &&
                                              filters[selectedFieldName] !=
                                                  null) {
                                            setState(() {
                                              filtersList.add({
                                                'field': selectedFieldName,
                                                'operator': selectedOperator,
                                                'value':
                                                    filters[selectedFieldName],
                                              });
                                              selectedFieldName = '';
                                              selectedOperator = '=';
                                              filters.clear();
                                            });
                                          }
                                        },
                                        child: const Icon(Icons.add,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              // Display current filters
                              if (filtersList.isNotEmpty) ...[
                                Text(
                                  'Current Filters',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Container(
                                  height: 200,
                                  color: Colors.white,
                                  child: ListView.builder(
                                    itemCount: filtersList.length,
                                    itemBuilder: (context, index) {
                                      final filter = filtersList[index];
                                      return Card(
                                        margin: EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 4),
                                        elevation: 2,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.all(8),
                                          title: Text(
                                            '${filter['field']} ${filter['operator']} ${filter['value']}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red, size: 20),
                                            onPressed: () {
                                              setState(() {
                                                filtersList.removeAt(index);
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      // Apply filters button
                      Padding(
                        padding: EdgeInsets.all(20.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              applyFilters();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25)),
                            ),
                            child: const Text('Apply Filters',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> applyFilters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    print(filtersList);
    List<List<dynamic>> filterList = [];

    filtersList.forEach((filter) {
      String fieldKey = filter['field'];
      if (fieldKey.contains(',')) {
        // Child table field: "ChildDoctype,child_fieldname"
        List<String> parts = fieldKey.split(',');
        String childDoctype = parts[0]; // e.g., "Sales Order Item"
        String childField = parts[1]; // e.g., "item_code"

        if (filter['operator'] == 'Between') {
          filterList.add([
            childDoctype, // e.g., "Sales Order Item"
            childField, // e.g., "item_code"
            filter['operator'],
            [filter['value']['from'], filter['value']['to']]
          ]);
        } else {
          filterList.add([
            childDoctype, // e.g., "Sales Order Item"
            childField, // e.g., "item_code"
            filter['operator'],
            filter['value']
          ]);
        }
      } else {
        // Parent field
        if (filter['operator'] == 'Between') {
          filterList.add([
            fieldKey,
            filter['operator'],
            [filter['value']['from'], filter['value']['to']]
          ]);
        } else {
          filterList.add([fieldKey, filter['operator'], filter['value']]);
        }
      }
    });

    print("Filters being sent: ${jsonEncode(filterList)}");

    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/resource/${widget.doctype}?filters=${Uri.encodeComponent(jsonEncode(filterList))}&fields=["*"]'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          filteredData = List<Map<String, dynamic>>.from(data['data']);
          // totalCount = filteredData.length; // Update count
        });
        print("Filtered data: ${filteredData.length} items");
        // Also fetch count with current filters
        fetchCount();
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Exception while fetching data: $e");
    }
  }

  // Function to add filters

  // Function to get selected filters for a specific field
  List<Map<String, dynamic>> _getSelectedFiltersForField(String fieldName) {
    return allFilters[fieldName] ?? [];
  }

  // Function to remove a filter
  void _removeFilter(String fieldName, Map<String, dynamic> filter) {
    allFilters[fieldName]?.remove(filter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.doctype} List',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: showFilterBottomSheet,
            ),
            IconButton(
              icon: Icon(Icons.view_list),
              onPressed: showFieldSelectionDialog,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FrappeCrudForm(
                  doctype: '${widget.doctype}',
                  docname: '',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
            // Refresh data after returning from form
            fetchDoctypeData();
            fetchCount();
          },
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        backgroundColor: Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: () async {
            await fetchDoctypeData();
            await fetchCount();
          },
          color: Colors.black,
          child: Container(
            padding: EdgeInsets.all(0),
            child: Column(
              children: [
                SizedBox(
                  height: 30,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      // borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Count section (left)
                        Text(
                          'Showing ${filteredData.length} of ${totalCount > 1000 ? '1000+' : totalCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        // Sort controls (right)
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.grey[400]!, width: 1),
                              ),
                              child: SizedBox(
                                height: 22,
                                child: DropdownButton<String>(
                                  dropdownColor: Colors.white,
                                  value: sortBy,
                                  underline: SizedBox(),
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.black, size: 16),
                                  isDense: true,
                                  items: availableFields.map((field) {
                                    return DropdownMenuItem<String>(
                                      value: field['fieldname'],
                                      child: Text(
                                        field['label'] ?? field['fieldname'],
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.black),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      sortBy = value!;
                                      applyFiltersAndSort();
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            SizedBox(
                              height: 25,
                              width: 25,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey[400]!, width: 1),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                child: Tooltip(
                                  message:
                                      ascending ? 'Ascending' : 'Descending',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.unfold_more,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        ascending = !ascending;
                                        applyFiltersAndSort();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    // constraints: BoxConstraints(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final doc = filteredData[index];
                      return Padding(
                        padding: const EdgeInsets.all(1.0),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FrappeCrudForm(
                                  doctype: widget.doctype,
                                  docname: doc['name'],
                                  baseUrl: 'http://localhost:8000',
                                ),
                              ),
                            );
                            fetchDoctypeData();
                            fetchCount();
                          },
                          child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...selectedFields.where((field) {
                                    final fieldData =
                                        availableFields.firstWhere(
                                            (f) => f['fieldname'] == field,
                                            orElse: () => {
                                                  'label': field,
                                                  'fieldtype': ''
                                                });
                                    return fieldData['label'] == 'ID';
                                  }).map((field) {
                                    String fieldValue =
                                        doc.containsKey(field) &&
                                                doc[field] != null
                                            ? doc[field].toString()
                                            : 'N/A';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        fieldValue,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }),
                                  Builder(builder: (context) {
                                    List<Widget> fieldWidgets = [];
                                    List selectedNonIdFields =
                                        selectedFields.where((field) {
                                      final fieldData =
                                          availableFields.firstWhere(
                                              (f) => f['fieldname'] == field,
                                              orElse: () => {
                                                    'label': field,
                                                    'fieldtype': ''
                                                  });
                                      return fieldData['label'] != 'ID';
                                    }).toList();
                                    for (int i = 0;
                                        i < selectedNonIdFields.length;
                                        i++) {
                                      final field = selectedNonIdFields[i];
                                      final fieldData =
                                          availableFields.firstWhere(
                                              (f) => f['fieldname'] == field,
                                              orElse: () => {
                                                    'label': field,
                                                    'fieldtype': ''
                                                  });
                                      final label = fieldData['label'];
                                      final fieldType = fieldData['fieldtype'];
                                      dynamic fieldValue =
                                          doc.containsKey(field) &&
                                                  doc[field] != null
                                              ? doc[field]
                                              : 'N/A';
                                      if (fieldType == 'Date' &&
                                          fieldValue != 'N/A') {
                                        fieldValue = DateFormat('dd-MM-yyyy')
                                            .format(DateTime.parse(fieldValue));
                                      } else if (fieldType == 'Currency' &&
                                          fieldValue != 'N/A') {
                                        fieldValue = NumberFormat.currency(
                                                locale: 'en_IN', symbol: '₹')
                                            .format(double.tryParse(
                                                    fieldValue.toString()) ??
                                                0);
                                      } else if ((fieldType == 'Float' ||
                                              fieldType == 'Int' ||
                                              fieldType == 'Number') &&
                                          fieldValue != 'N/A') {
                                        fieldValue = NumberFormat('#,##0.00')
                                            .format(double.tryParse(
                                                    fieldValue.toString()) ??
                                                0);
                                      }
                                      Widget fieldWidget;
                                      if (fieldType == 'Percent' &&
                                          fieldValue != 'N/A') {
                                        double percentValue = (double.tryParse(
                                                    fieldValue.toString()) ??
                                                0.0)
                                            .clamp(0.0, 100.0);
                                        fieldWidget = Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text('$label: ',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  AnimatedContainer(
                                                    duration: Duration(
                                                        milliseconds: 500),
                                                    curve: Curves.easeInOut,
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: percentValue / 100,
                                                      strokeWidth: 3,
                                                      backgroundColor:
                                                          Colors.grey[300],
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors
                                                                  .blueAccent),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${percentValue.round()}%',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      } else if (label == 'Status' ||
                                          label == 'Workflow State') {
                                        fieldWidget = Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('$label: ',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                fieldValue,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        fieldWidget = Text(
                                            '$label: $fieldValue',
                                            style:
                                                const TextStyle(fontSize: 13));
                                      }
                                      fieldWidgets.add(
                                        SizedBox(
                                          width: (MediaQuery.of(context)
                                                      .size
                                                      .width /
                                                  2) -
                                              30,
                                          child: fieldWidget,
                                        ),
                                      );
                                      if ((i + 1) % 4 == 0 &&
                                          (i + 1) <
                                              selectedNonIdFields.length) {
                                        fieldWidgets.add(
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 1),
                                            child: Divider(color: Colors.grey),
                                          ),
                                        );
                                      }
                                    }
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: fieldWidgets,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ));
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
        SnackBar(content: Text('Error: \\${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),
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
                  style: TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Search ${widget.linkDoctype}',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    focusColor: Colors.black,
                    fillColor: Colors.white, // Input background white
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    suffixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
                // SizedBox(height: 10),
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    itemCount: _filteredOptions.length,
                    itemBuilder: (context, index) {
                      final option = _filteredOptions[index];
                      final isSelected = _selectedValue == option['value'];
                      return ListTile(
                        tileColor: isSelected ? Colors.grey[200] : Colors.white,
                        title: Text(
                          option['value'],
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.normal,
                            fontSize: isSelected ? 15 : 13,
                          ),
                        ),
                        subtitle: option['description'] != null
                            ? Text(
                                option['description'],
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.w400
                                      : FontWeight.normal,
                                  fontSize: isSelected ? 13 : 12,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedValue = option['value'];
                          });
                          widget.onSelected(_selectedValue);
                          Navigator.pop(context, _selectedValue);
                        },
                        selected: isSelected,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
