import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrappeTableField extends StatefulWidget {
  final String label;
  final String childTableDoctype;
  Map<String, dynamic> formData;
  final List<Map<String, dynamic>> initialData;
  final Map<String, dynamic> field;
  final Function(List?) onValueChanged;

  FrappeTableField({
    required this.label,
    required this.childTableDoctype,
    required this.formData,
    required this.field,
    required this.onValueChanged,
    this.initialData = const [],
    Key? key,
  }) : super(key: key);

  @override
  _FrappeTableFieldState createState() => _FrappeTableFieldState();
}

class _FrappeTableFieldState extends State<FrappeTableField> {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> columns = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChildTableFields();
  }

  Future<void> _fetchChildTableFields() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final String apiUrl =
        "https://teamloser.in//api/method/frappe.desk.form.load.getdoctype?doctype=${widget.childTableDoctype}";
    final response = await http.get(Uri.parse(apiUrl), headers: {
      'Content-Type': 'application/json',
      'Authorization': '$token',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final fields =
          List<Map<String, dynamic>>.from(data['docs'][0]['fields']) as List;
      setState(() {
        columns = fields
            .map((field) => {
                  'fieldname': field['fieldname'],
                  'label': field['label'],
                  'fieldtype': field['fieldtype'],
                  'in_list_view': field['in_list_view'],
                })
            .toList();
        rows = List.from(widget.initialData);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print("Failed to load child table fields: ${response.body}");
    }
  }

  void _addRow() {
    setState(() {
      rows.add({for (var column in columns) column['fieldname']: ''});

      // widget.formData[widget.field['fieldname']] = rows;
      // widget.onValueChanged(rows as List?); // Notify parent of the change
    });
  }

  void _removeRow(int index) {
    setState(() {
      rows.removeAt(index);
    });
  }

  void _editRow(int index) {
    _openFormModal(context, index);
  }

  void _openFormModal(BuildContext context, [int? editIndex]) {
    Map<String, dynamic> tempRow = editIndex != null
        ? {...rows[editIndex]}
        : {for (var column in columns) column['fieldname']: ''};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                0.9, // Set max height to 90% of screen height
          ),
          margin: EdgeInsets.only(top: 20), // Set top margin
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              // Make the content scrollable
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    editIndex == null ? "Add New Row" : "Edit Row",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  ...columns.map((column) {
                    if (column['section_break'] == true) {
                      return Divider(
                          height: 20, thickness: 2, color: Colors.grey);
                    }
                    if (column['column_break'] == true) {
                      return SizedBox(width: 10);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        initialValue: tempRow[column['fieldname']].toString(),
                        decoration: InputDecoration(
                          labelText:
                              '${column['label']}, ${column['in_list_view'] ?? 'no list'}',
                          labelStyle:
                              TextStyle(fontSize: 13, color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                        readOnly: column['read_only'] ?? false,
                        onChanged: (value) {
                          tempRow[column['fieldname']] = value;
                        },
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 16), // Add some space before the button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // Black background
                      padding: EdgeInsets.symmetric(horizontal: 14), // Padding
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8), // Rounded corners
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        if (editIndex != null) {
                          rows[editIndex] = tempRow;
                        } else {
                          rows.add(tempRow);
                        }

                        widget.onValueChanged(rows as List?);
                      });
                    },
                    child: Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white, // White font color
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 10),
        if (isLoading)
          Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, rowIndex) {
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  title: Text("Item ${rowIndex + 1}",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: columns.map((column) {
                      return Text(
                          "${column['label']}: ${rows[rowIndex][column['fieldname']].toString()}",
                          style: TextStyle(fontSize: 13, color: Colors.grey));
                    }).toList(),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editRow(rowIndex),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeRow(rowIndex),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // Black background
              padding: EdgeInsets.symmetric(
                horizontal: 14,
              ), // Padding
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Rounded corners
              ),
            ),
            onPressed: () => _openFormModal(context),
            child: Text(
              "Add Row",
              style: TextStyle(
                fontSize: 13,
                color: Colors.white, // White font color
              ),
            ),
          ),
        ),
      ],
    );
  }
}
