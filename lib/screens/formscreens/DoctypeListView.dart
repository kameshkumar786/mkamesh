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
  String sortBy = 'name';
  bool ascending = true;

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
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print(e);
    }
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
        int compare = ascending
            ? a[sortBy].toString().compareTo(b[sortBy].toString())
            : b[sortBy].toString().compareTo(a[sortBy].toString());
        return compare;
      });
    });
  }

  void showFieldSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final selectedField = availableFields.firstWhere(
              (field) => field['fieldname'] == selectedFieldName,
              orElse: () => <String, dynamic>{},
            );
            final selectedFieldType = selectedField['fieldtype'];

            return Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'Add Filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Add filter row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Field',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
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
                              .map((field) => DropdownMenuItem<String>(
                                    value: field['fieldname'],
                                    child: Text(
                                      field['label'] ?? field['fieldname'],
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Operator',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
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
                            {"value": "not like", "label": "Not Like"},
                            {"value": "in", "label": "In"},
                            {"value": "not in", "label": "Not In"},
                            {"value": "is", "label": "Is"},
                            {"value": ">", "label": ">"},
                            {"value": "<", "label": "<"},
                            {"value": ">=", "label": ">="},
                            {"value": "<=", "label": "<="},
                            {"value": "Between", "label": "Between"},
                            if (selectedFieldType == 'Date' ||
                                selectedFieldType == 'Datetime')
                              {"value": "Timespan", "label": "Timespan"},
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
                              .map((item) => DropdownMenuItem<String>(
                                    value: item['value']!,
                                    child: Text(
                                      item['label']!,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Builder(
                          builder: (context) {
                            final selectedField = availableFields.firstWhere(
                              (field) =>
                                  field['fieldname'] == selectedFieldName,
                              orElse: () => <String, dynamic>{},
                            );

                            if (selectedField.isEmpty) {
                              return TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Select a field first',
                                  labelStyle: TextStyle(fontSize: 11),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              );
                            }

                            final fieldType = selectedField['fieldtype'];

                            // Handle "is" operator
                            if (selectedOperator == 'is') {
                              return DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Value',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: [
                                  DropdownMenuItem(
                                      value: 'Set',
                                      child: Text('Set',
                                          style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(
                                      value: 'Not Set',
                                      child: Text('Not Set',
                                          style: TextStyle(fontSize: 11))),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    filters[selectedFieldName] = value;
                                  });
                                },
                              );
                            }

                            // Handle "Between" operator
                            if (selectedOperator == 'Between' &&
                                (selectedFieldType == 'Date' ||
                                    selectedFieldType == 'Datetime')) {
                              return GestureDetector(
                                onTap: () async {
                                  DateTime now = DateTime.now();
                                  final DateTimeRange? picked =
                                      await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    initialDateRange:
                                        filters[selectedFieldName] != null
                                            ? DateTimeRange(
                                                start: DateTime.parse(
                                                    filters[selectedFieldName]
                                                        ['from']),
                                                end: DateTime.parse(
                                                    filters[selectedFieldName]
                                                        ['to']),
                                              )
                                            : DateTimeRange(
                                                start: now,
                                                end:
                                                    now.add(Duration(days: 7))),
                                  );

                                  if (picked != null) {
                                    setState(() {
                                      filters[selectedFieldName] = {
                                        'from': picked.start
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                        'to': picked.end
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                      };
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Select Date Range',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    filters[selectedFieldName] != null
                                        ? '${filters[selectedFieldName]['from']} to ${filters[selectedFieldName]['to']}'
                                        : 'Tap to select date range',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black),
                                  ),
                                ),
                              );
                            } else if (selectedOperator == 'Between') {
                              return Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'From',
                                        labelStyle: TextStyle(fontSize: 12),
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      style: TextStyle(fontSize: 11),
                                      keyboardType: fieldType == 'Int' ||
                                              fieldType == 'Float' ||
                                              fieldType == 'Currency'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      onChanged: (value) {
                                        setState(() {
                                          filters[selectedFieldName] = {
                                            'from': value,
                                            'to': filters[selectedFieldName]
                                                ?['to']
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
                                        labelStyle: TextStyle(fontSize: 12),
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      style: TextStyle(fontSize: 11),
                                      keyboardType: fieldType == 'Int' ||
                                              fieldType == 'Float' ||
                                              fieldType == 'Currency'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      onChanged: (value) {
                                        setState(() {
                                          filters[selectedFieldName] = {
                                            'from': filters[selectedFieldName]
                                                ?['from'],
                                            'to': value
                                          };
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Handle "Timespan" operator
                            if (selectedOperator == 'Timespan' &&
                                (fieldType == 'Date' ||
                                    fieldType == 'Datetime')) {
                              return DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Timespan',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: [
                                  {"value": "last week", "label": "Last Week"},
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
                                  {"value": "last year", "label": "Last Year"},
                                  {"value": "yesterday", "label": "Yesterday"},
                                  {"value": "today", "label": "Today"},
                                  {"value": "tomorrow", "label": "Tomorrow"},
                                  {"value": "this week", "label": "This Week"},
                                  {
                                    "value": "this month",
                                    "label": "This Month"
                                  },
                                  {
                                    "value": "this quarter",
                                    "label": "This Quarter"
                                  },
                                  {"value": "this year", "label": "This Year"},
                                  {"value": "next week", "label": "Next Week"},
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
                                  {"value": "next year", "label": "Next Year"}
                                ]
                                    .map((item) => DropdownMenuItem<String>(
                                          value: item['value']!,
                                          child: Text(item['label']!,
                                              style: TextStyle(fontSize: 11)),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    filters[selectedFieldName] = value;
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
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: TextStyle(fontSize: 11),
                                keyboardType: fieldType == 'Int'
                                    ? TextInputType.number
                                    : TextInputType.text,
                                onChanged: (value) {
                                  if (fieldType == 'Int') {
                                    // Validate if the input is a number
                                    if (int.tryParse(value) != null) {
                                      setState(() {
                                        filters[selectedFieldName] = value;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      filters[selectedFieldName] = value;
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
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: TextStyle(fontSize: 11),
                                keyboardType: fieldType == 'Int' ||
                                        fieldType == 'Float' ||
                                        fieldType == 'Currency'
                                    ? TextInputType.number
                                    : TextInputType.text,
                                onChanged: (value) {
                                  if (fieldType == 'Int' ||
                                      fieldType == 'Float' ||
                                      fieldType == 'Currency') {
                                    // Validate if the input is a number
                                    if (double.tryParse(value) != null) {
                                      setState(() {
                                        filters[selectedFieldName] = value;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      filters[selectedFieldName] = value;
                                    });
                                  }
                                },
                              );
                            }

                            // Handle other field types
                            switch (fieldType) {
                              case 'Select':
                                return DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Select Value',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: (selectedField['options'] as String?)
                                      ?.split('\n')
                                      .map((option) {
                                    return DropdownMenuItem<String>(
                                      value: option,
                                      child: Text(option,
                                          style: TextStyle(fontSize: 11)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      filters[selectedFieldName] = value;
                                    });
                                  },
                                );

                              case 'Link':
                                return GestureDetector(
                                  onTap: () async {
                                    final result =
                                        await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (_) => LinkField(
                                        linkDoctype: selectedField['options'],
                                        initialValue: filters[selectedFieldName]
                                            as String?,
                                        onSelected: (value) {
                                          setState(() {
                                            filters[selectedFieldName] = value;
                                          });
                                        },
                                      ),
                                    );
                                    if (result != null) {
                                      setState(() {
                                        filters[selectedFieldName] = result;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText:
                                          'Search ${selectedField['label']}',
                                      labelStyle: TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    child: Text(
                                      filters[selectedFieldName]?.toString() ??
                                          'Tap to select',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            filters[selectedFieldName] == null
                                                ? Colors.grey
                                                : Colors.black,
                                      ),
                                    ),
                                  ),
                                );

                              case 'Date':
                                final dateController = TextEditingController();
                                if (filters[selectedFieldName] != null) {
                                  dateController.text =
                                      filters[selectedFieldName];
                                }

                                return TextFormField(
                                  controller: dateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Date',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon:
                                        Icon(Icons.calendar_today, size: 16),
                                  ),
                                  onTap: () async {
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime(2100),
                                    );

                                    if (pickedDate != null) {
                                      final formattedDate = pickedDate
                                          .toIso8601String()
                                          .split('T')[0];
                                      setState(() {
                                        filters[selectedFieldName] =
                                            formattedDate;
                                        dateController.text = formattedDate;
                                      });
                                    }
                                  },
                                );

                              case 'Datetime':
                                return TextFormField(
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select DateTime',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon:
                                        Icon(Icons.calendar_today, size: 16),
                                  ),
                                  onTap: () async {
                                    final pickedDateTime = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime(2100),
                                    );
                                    if (pickedDateTime != null) {
                                      final formattedDateTime =
                                          pickedDateTime.toIso8601String();
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
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Enter Value',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: TextStyle(fontSize: 11),
                                  onChanged: (value) {
                                    setState(() {
                                      filters[selectedFieldName] =
                                          fieldType == 'Int'
                                              ? int.tryParse(value)
                                              : double.tryParse(value);
                                    });
                                  },
                                );

                              default:
                                return TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Enter Value',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: TextStyle(fontSize: 11),
                                  onChanged: (value) {
                                    setState(() {
                                      filters[selectedFieldName] = value;
                                    });
                                  },
                                );
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedFieldName.isNotEmpty &&
                              selectedOperator.isNotEmpty &&
                              filters[selectedFieldName] != null) {
                            setState(() {
                              filtersList.add({
                                'field': selectedFieldName,
                                'operator': selectedOperator,
                                'value': filters[selectedFieldName],
                              });
                              selectedFieldName = '';
                              selectedOperator = '=';
                              filters.clear();
                            });
                          }
                        },
                        child: Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Display current filters
                  if (filtersList.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtersList.length,
                        itemBuilder: (context, index) {
                          final filter = filtersList[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(12),
                              title: Text(
                                '${filter['field']} ${filter['operator']} ${filter['value']}',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(filter.toString()),
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

                  // Apply filters button
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Apply filters logic
                      applyFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
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
        });
        print("Filtered data: ${filteredData.length} items");
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Exception while fetching data: $e");
    }
  }

  // Function to add filters
  void _addFilter(
      String fieldName, String operator, Map<String, dynamic> filter) {
    if (allFilters.containsKey(fieldName)) {
      allFilters[fieldName]!.add({...filter, 'operator': operator});
    } else {
      allFilters[fieldName] = [
        {...filter, 'operator': operator}
      ];
    }
  }

  // Function to get selected filters for a specific field
  List<Map<String, dynamic>> _getSelectedFiltersForField(String fieldName) {
    return allFilters[fieldName] ?? [];
  }

  // Function to remove a filter
  void _removeFilter(String fieldName, Map<String, dynamic> filter) {
    allFilters[fieldName]?.remove(filter);
  }

  void showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sort By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: sortBy,
                onChanged: (String? value) {
                  setState(() {
                    sortBy = value!;
                  });
                },
                items: availableFields.map((field) {
                  return DropdownMenuItem<String>(
                    value: field['fieldname'] as String,
                    child: Text(field['label'] ?? field['fieldname']),
                  );
                }).toList(),
              ),
              SwitchListTile(
                title: Text('Ascending'),
                value: ascending,
                onChanged: (value) {
                  setState(() {
                    ascending = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                applyFiltersAndSort();
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.doctype} List',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            IconButton(
              icon: Icon(Icons.sort),
              onPressed: showSortDialog,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FrappeCrudForm(
                  doctype: '${widget.doctype}',
                  docname: '',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
          },
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        backgroundColor: Colors.grey[100],
        body: Container(
          padding: EdgeInsets.all(4),
          child: ListView.builder(
            itemCount: filteredData.length,
            itemBuilder: (context, index) {
              final doc = filteredData[index];
              return Padding(
                padding:
                    const EdgeInsets.all(1.0), // Add margin around the card
                child: GestureDetector(
                    onTap: () {
                      // print('data: ${widget.doctype} ,${doc['name']}');
                      // Navigate to the form screen when the card is tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FrappeCrudForm(
                              doctype: widget.doctype,
                              docname: doc['name'],
                              baseUrl:
                                  'http://localhost:8000'), // Replace with your form screen
                        ),
                      );
                    },
                    child: Card(
                      color: Colors.white, // Set the background color to white
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            10), // Rounded corners for the card
                      ),
                      elevation: 3, // Slight elevation for shadow
                      // shadowColor:
                      //     Colors.blue, // Set the color of the shadow to blue
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display the ID field separately in full width
                            ...selectedFields.where((field) {
                              final fieldData = availableFields.firstWhere(
                                  (f) => f['fieldname'] == field,
                                  orElse: () =>
                                      {'label': field, 'fieldtype': ''});
                              return fieldData['label'] == 'ID';
                            }).map((field) {
                              String fieldValue =
                                  doc.containsKey(field) && doc[field] != null
                                      ? doc[field].toString()
                                      : 'N/A';
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4), // Spacing
                                child: Text(
                                  fieldValue,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }),

                            // Display all other fields in two columns with a border after every 3 items
                            Builder(builder: (context) {
                              List<Widget> fieldWidgets = [];
                              List selectedNonIdFields =
                                  selectedFields.where((field) {
                                final fieldData = availableFields.firstWhere(
                                    (f) => f['fieldname'] == field,
                                    orElse: () =>
                                        {'label': field, 'fieldtype': ''});
                                return fieldData['label'] != 'ID';
                              }).toList();

                              for (int i = 0;
                                  i < selectedNonIdFields.length;
                                  i++) {
                                final field = selectedNonIdFields[i];
                                final fieldData = availableFields.firstWhere(
                                    (f) => f['fieldname'] == field,
                                    orElse: () =>
                                        {'label': field, 'fieldtype': ''});
                                final label = fieldData['label'];
                                final fieldType =
                                    fieldData['fieldtype']; // Get field type

                                dynamic fieldValue =
                                    doc.containsKey(field) && doc[field] != null
                                        ? doc[field]
                                        : 'N/A';

                                // Format based on field type
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
                                  fieldValue = NumberFormat('#,##0.00').format(
                                      double.tryParse(fieldValue.toString()) ??
                                          0);
                                }

                                // 🌟 If it's "Status" or "Workflow State", show it in a badge
                                Widget fieldWidget;
                                if (fieldType == 'Percent' &&
                                    fieldValue != 'N/A') {
                                  // Accurate animated circular progress bar for Percent fields
                                  double percentValue =
                                      (double.tryParse(fieldValue.toString()) ??
                                              0.0)
                                          .clamp(0.0,
                                              100.0); // Ensure value is 0-100
                                  fieldWidget = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text('$label: ',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 500),
                                              curve: Curves.easeInOut,
                                              child: CircularProgressIndicator(
                                                value: percentValue /
                                                    100, // 0.0 to 1.0
                                                strokeWidth: 5,
                                                backgroundColor:
                                                    Colors.grey[300],
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Colors.blueAccent),
                                              ),
                                            ),
                                            Text(
                                              '${percentValue.round()}%',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .shade100, // Light color background
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          fieldValue,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  fieldWidget = Text('$label: $fieldValue',
                                      style: const TextStyle(fontSize: 14));
                                }

                                fieldWidgets.add(
                                  SizedBox(
                                    width: (MediaQuery.of(context).size.width /
                                            2) -
                                        30, // Two-column layout
                                    child: fieldWidget,
                                  ),
                                );

                                // Add a divider after every 3 items, except the last group
                                if ((i + 1) % 4 == 0 &&
                                    (i + 1) < selectedNonIdFields.length) {
                                  fieldWidgets.add(
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 1),
                                      child: Divider(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                }
                              }

                              return Wrap(
                                spacing: 12, // Space between columns
                                runSpacing: 6, // Space between rows
                                children: fieldWidgets,
                              );
                            }),
                          ],
                        ),
                      ),
                    )),
              );
            },
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
