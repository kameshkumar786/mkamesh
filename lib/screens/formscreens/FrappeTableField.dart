import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mkamesh/screens/formscreens/ChildTableForm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class FrappeTableField extends StatefulWidget {
  final String label;
  final String childTableDoctype;
  final Map<String, dynamic> formData;
  final Map<String, dynamic> field;
  final String baseUrl;
  final List<dynamic> initialData;
  final Function(List<dynamic>) onValueChanged;

  const FrappeTableField({
    required this.label,
    required this.childTableDoctype,
    required this.formData,
    required this.field,
    required this.baseUrl,
    required this.initialData,
    required this.onValueChanged,
  });

  @override
  _FrappeTableFieldState createState() => _FrappeTableFieldState();
}

class _FrappeTableFieldState extends State<FrappeTableField> {
  List<dynamic> tableData = [];
  List<Map<String, dynamic>> childFields = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // tableData = List.from(widget.initialData);
    // tableData =
    //     widget.initialData != null ? List.from(widget.initialData!) : [];
    fetchChildTableMeta();
  }

  Future<void> fetchChildTableMeta() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.childTableDoctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          tableData = List.from(widget.initialData!);
          childFields =
              List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
          childFields.sort((a, b) => (a['idx'] ?? 0).compareTo(b['idx'] ?? 0));
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        developer.log('Failed to fetch child table meta: ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      developer.log('Error fetching child table meta: $e');
    }
  }

  void _addRow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildTableForm(
          doctype: widget.childTableDoctype,
          baseUrl: widget.baseUrl,
          onSave: (rowData) {
            setState(() {
              tableData.add(rowData);
              widget.onValueChanged(tableData);
            });
          },
        ),
      ),
    );
  }

  void _editRow(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildTableForm(
          doctype: widget.childTableDoctype,
          baseUrl: widget.baseUrl,
          initialData: tableData[index],
          onSave: (rowData) {
            setState(() {
              tableData[index] = rowData;
              widget.onValueChanged(tableData);
            });
          },
        ),
      ),
    );
  }

  void _deleteRow(int index) {
    setState(() {
      tableData.removeAt(index);
      widget.onValueChanged(tableData);
    });
  }

  Widget _buildRowCard(int index) {
    final row = tableData[index];
    String displayField = childFields.firstWhere((f) => f['in_list_view'] == 1,
        orElse: () => childFields.first)['fieldname'];
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.label} #${index + 1}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              '$displayField: ${row[displayField]?.toString() ?? 'N/A'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editRow(index),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteRow(index),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: _addRow,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
                child: const Text('Add Row'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          tableData.isEmpty
              ? const Text('No entries yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey))
              : Column(
                  children: List.generate(
                      tableData.length, (index) => _buildRowCard(index)),
                ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:developer' as developer;

// class FrappeTableField extends StatefulWidget {
//   final String label;
//   final String childTableDoctype;
//   final Map<String, dynamic> formData;
//   final List initialData;
//   final Map<String, dynamic> field;
//   final Function(List?) onValueChanged;
//   final String baseUrl;

//   const FrappeTableField({
//     required this.label,
//     required this.childTableDoctype,
//     required this.formData,
//     required this.field,
//     required this.onValueChanged,
//     required this.baseUrl,
//     required this.initialData,
//     Key? key,
//   }) : super(key: key);

//   @override
//   _FrappeTableFieldState createState() => _FrappeTableFieldState();
// }

// class _FrappeTableFieldState extends State<FrappeTableField> {
//   List rows = [];
//   List<Map<String, dynamic>> columns = [];
//   bool isLoading = true;
//   Set<String> fetchedFields = {};
//   Set<String> errorLoggedFields = {};

//   @override
//   void initState() {
//     super.initState();
//     _fetchChildTableFields();
//   }

//   Future<void> _fetchChildTableFields() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? token = prefs.getString('token');
//       developer.log(
//           "Fetching child table fields for ${widget.childTableDoctype} with token: $token");

//       final String apiUrl =
//           "${widget.baseUrl}/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.childTableDoctype}";
//       final response = await http.get(Uri.parse(apiUrl), headers: {
//         'Content-Type': 'application/json',
//         'Authorization': '$token',
//       });

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final fields =
//             List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
//         developer.log("Fields fetched: ${fields.length}");
//         setState(() {
//           columns = fields
//               .map((field) => ({
//                     'fieldname': field['fieldname'] ?? '',
//                     'label': field['label'] ?? '',
//                     'fieldtype': field['fieldtype'] ?? '',
//                     'in_list_view': field['in_list_view'] ?? 0,
//                     'options': field['options'],
//                     'reqd': field['reqd'] ?? 0,
//                     'read_only': field['read_only'] ?? 0,
//                     'hidden': field['hidden'] ?? 0,
//                     'collapsible': field['collapsible'] ?? 0,
//                     'depends_on': field['depends_on'],
//                     'mandatory_depends_on': field['mandatory_depends_on'],
//                     'read_only_depends_on': field['read_only_depends_on'],
//                     'fetch_from': field['fetch_from'],
//                     'idx': field['idx'] ?? 0,
//                   }))
//               .toList()
//             ..sort((a, b) => (a['idx'] as int).compareTo(b['idx'] as int));
//           rows = List.from(widget.initialData);
//           isLoading = false;
//         });
//       } else {
//         throw Exception("Failed to load fields: ${response.body}");
//       }
//     } catch (e) {
//       developer.log("Error fetching fields: $e");
//       setState(() {
//         isLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to load fields: $e")),
//       );
//     }
//   }

//   void _addRow() {
//     _openFormModal(context);
//   }

//   void _removeRow(int index) {
//     setState(() {
//       rows.removeAt(index);
//       widget.onValueChanged(rows);
//     });
//   }

//   void _editRow(int index) {
//     _openFormModal(context, index);
//   }

//   bool _evaluateMultipleConditions(
//       String? condition, Map<String, dynamic> tempRow) {
//     if (condition == null || condition.isEmpty) return true;

//     try {
//       String parsedCondition = condition.trim().replaceAll('doc.', '');
//       List<String> parts = parsedCondition.split(RegExp(r'\s*(&&|\|\|)\s*'));
//       List<String> operators = RegExp(r'(&&|\|\|)')
//           .allMatches(parsedCondition)
//           .map((match) => match.group(0)!)
//           .toList();

//       bool result = true;
//       for (int i = 0; i < parts.length; i++) {
//         String part = parts[i].trim();
//         bool partResult = _evaluateSingleCondition(part, tempRow);
//         developer.log("Evaluating condition part '$part': $partResult");

//         if (i > 0) {
//           String operator = operators[i - 1];
//           if (operator == '&&') {
//             result = result && partResult;
//           } else if (operator == '||') {
//             result = result || partResult;
//           }
//         } else {
//           result = partResult;
//         }
//       }
//       developer.log("Evaluated condition '$condition': $result");
//       return result;
//     } catch (e) {
//       developer.log("Error evaluating condition '$condition': $e");
//       return false;
//     }
//   }

//   bool _evaluateSingleCondition(
//       String condition, Map<String, dynamic> tempRow) {
//     try {
//       if (condition.contains('==')) {
//         var parts = condition.split('==').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1].replaceAll('"', '').replaceAll("'", "");
//         return tempRow[fieldName]?.toString() == value;
//       } else if (condition.contains('!=')) {
//         var parts = condition.split('!=').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1].replaceAll('"', '').replaceAll("'", "");
//         return tempRow[fieldName]?.toString() != value;
//       } else if (condition.contains('>')) {
//         var parts = condition.split('>').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1];
//         return (double.tryParse(tempRow[fieldName]?.toString() ?? '0') ?? 0) >
//             (double.tryParse(value) ?? 0);
//       } else if (condition.contains('<')) {
//         var parts = condition.split('<').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1];
//         return (double.tryParse(tempRow[fieldName]?.toString() ?? '0') ?? 0) <
//             (double.tryParse(value) ?? 0);
//       } else if (condition.contains('>=')) {
//         var parts = condition.split('>=').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1];
//         return (double.tryParse(tempRow[fieldName]?.toString() ?? '0') ?? 0) >=
//             (double.tryParse(value) ?? 0);
//       } else if (condition.contains('<=')) {
//         var parts = condition.split('<=').map((p) => p.trim()).toList();
//         if (parts.length != 2) return false;
//         String fieldName = parts[0];
//         String value = parts[1];
//         return (double.tryParse(tempRow[fieldName]?.toString() ?? '0') ?? 0) <=
//             (double.tryParse(value) ?? 0);
//       } else {
//         String fieldName = condition.trim();
//         dynamic value = tempRow[fieldName];
//         return value != null &&
//             value.toString().isNotEmpty &&
//             value.toString() != 'false' &&
//             value.toString() != '0';
//       }
//     } catch (e) {
//       developer.log("Error evaluating single condition '$condition': $e");
//       return false;
//     }
//   }

//   bool _convertToBool(dynamic value) {
//     if (value is bool) return value;
//     if (value is int) return value == 1;
//     return false;
//   }

//   Future<void> _fetchFieldValueFromLink(String fieldName, String fetchFrom,
//       Map<String, dynamic> tempRow, StateSetter setModalState) async {
//     try {
//       List<String> parts = fetchFrom.split('.');
//       if (parts.length != 2) {
//         developer.log("Invalid fetch_from format: $fetchFrom");
//         return;
//       }
//       String linkFieldName = parts[0];
//       String targetField = parts[1];

//       String? linkedDocName = tempRow[linkFieldName];
//       if (linkedDocName == null || linkedDocName.isEmpty) {
//         developer.log("No linked document name for $linkFieldName");
//         return;
//       }

//       String? linkDoctype;
//       for (var f in columns) {
//         if (f['fieldname'] == linkFieldName && f['fieldtype'] == 'Link') {
//           linkDoctype = f['options'];
//           break;
//         }
//       }
//       if (linkDoctype == null) {
//         developer.log("No link doctype found for $linkFieldName");
//         return;
//       }

//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? token = prefs.getString('token');
//       if (token == null) {
//         developer.log("No token available");
//         return;
//       }

//       final url = '${widget.baseUrl}/api/resource/$linkDoctype/$linkedDocName';
//       developer.log("Fetching from URL: $url");
//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': '$token',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         dynamic fetchedValue = data['data'][targetField];
//         if (fetchedValue != null) {
//           setModalState(() {
//             tempRow[fieldName] = fetchedValue;
//             fetchedFields.add(fieldName);
//             developer.log("Fetched value for $fieldName: $fetchedValue");
//           });
//         } else {
//           developer.log(
//               "No value found for $targetField in $linkDoctype/$linkedDocName");
//         }
//       } else {
//         developer
//             .log("Failed to fetch $fetchFrom for $fieldName: ${response.body}");
//         if (!errorLoggedFields.contains(fieldName)) {
//           errorLoggedFields.add(fieldName);
//         }
//       }
//     } catch (e) {
//       developer.log("Error fetching value for $fieldName from $fetchFrom: $e");
//       if (!errorLoggedFields.contains(fieldName)) {
//         errorLoggedFields.add(fieldName);
//       }
//     }
//   }

//   Widget _buildField(Map<String, dynamic> column, Map<String, dynamic> tempRow,
//       StateSetter setModalState) {
//     final fieldtype = column['fieldtype'] ?? '';
//     final fieldname = column['fieldname'] ?? '';
//     final label = column['label'] ?? 'Unnamed Field';
//     bool readOnly = _convertToBool(column['read_only']);
//     bool hidden = _convertToBool(column['hidden']);
//     bool required = _convertToBool(column['reqd']);
//     final dependsOn = column['depends_on'];
//     final mandatoryDependsOn = column['mandatory_depends_on'];
//     final readOnlyDependsOn = column['read_only_depends_on'];
//     final fetchFrom = column['fetch_from'];
//     final options = column['options'];

//     developer.log(
//         "Building field: $fieldname, Type: $fieldtype, Depends On: $dependsOn");

//     if (hidden ||
//         (dependsOn != null &&
//             !_evaluateMultipleConditions(dependsOn, tempRow))) {
//       developer.log(
//           "$fieldname hidden due to hidden: $hidden or depends_on: $dependsOn");
//       return const SizedBox.shrink();
//     }

//     if (mandatoryDependsOn != null) {
//       required = _evaluateMultipleConditions(mandatoryDependsOn, tempRow);
//       developer.log("$fieldname required updated to: $required");
//     }
//     if (readOnlyDependsOn != null) {
//       readOnly = _evaluateMultipleConditions(readOnlyDependsOn, tempRow);
//       developer.log("$fieldname readOnly updated to: $readOnly");
//     }

//     if (fetchFrom != null &&
//         fetchFrom.isNotEmpty &&
//         !fetchedFields.contains(fieldname)) {
//       developer.log("Triggering fetch_from for $fieldname: $fetchFrom");
//       _fetchFieldValueFromLink(fieldname, fetchFrom, tempRow, setModalState);
//     }

//     final inputDecoration = InputDecoration(
//       labelText: required ? '$label *' : label,
//       labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
//       hintText: 'Enter $label',
//       hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(15),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(15),
//         borderSide: const BorderSide(color: Colors.black),
//       ),
//       filled: true,
//       fillColor: readOnly ? Colors.grey[300] : Colors.white,
//     );

//     void _updateDependentFields() {
//       setModalState(() {
//         developer.log("Updating dependent fields for $fieldname");
//         for (var f in columns) {
//           if (f['depends_on']?.contains(fieldname) == true ||
//               f['mandatory_depends_on']?.contains(fieldname) == true ||
//               f['read_only_depends_on']?.contains(fieldname) == true ||
//               f['fetch_from']?.contains(fieldname) == true) {
//             developer.log("Field ${f['fieldname']} depends on $fieldname");
//             if (f['fetch_from'] != null &&
//                 !fetchedFields.contains(f['fieldname'])) {
//               _fetchFieldValueFromLink(
//                   f['fieldname'], f['fetch_from'], tempRow, setModalState);
//             }
//           }
//         }
//       });
//     }

//     try {
//       switch (fieldtype) {
//         case 'Data':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Small Text':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               maxLines: 1,
//               decoration:
//                   inputDecoration.copyWith(hintText: 'Short input for $label'),
//               style: const TextStyle(fontSize: 13, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Text':
//         case 'Text Editor':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               maxLines: fieldtype == 'Text Editor' ? 5 : 3,
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 12, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Int':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               keyboardType: TextInputType.number,
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = int.tryParse(value) ?? 0;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Float':
//         case 'Currency':
//         case 'Rate':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = double.tryParse(value) ?? 0.0;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Percent':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//               decoration: inputDecoration.copyWith(
//                   suffixText: '%', suffixStyle: const TextStyle(fontSize: 14)),
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   double? percent = double.tryParse(value);
//                   tempRow[fieldname] =
//                       percent != null && percent >= 0 && percent <= 100
//                           ? percent
//                           : 0.0;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Date':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: readOnly
//                       ? null
//                       : () async {
//                           developer.log("Opening date picker for $fieldname");
//                           DateTime? picked = await showDatePicker(
//                             context: context,
//                             initialDate: tempRow[fieldname] != null
//                                 ? DateTime.tryParse(
//                                         tempRow[fieldname].toString()) ??
//                                     DateTime.now()
//                                 : DateTime.now(),
//                             firstDate: DateTime(2000),
//                             lastDate: DateTime(2101),
//                           );
//                           if (picked != null) {
//                             setModalState(() {
//                               tempRow[fieldname] =
//                                   DateFormat('yyyy-MM-dd').format(picked);
//                               developer.log(
//                                   "Date selected for $fieldname: ${tempRow[fieldname]}");
//                               _updateDependentFields();
//                             });
//                           }
//                         },
//                   child: InputDecorator(
//                     decoration: inputDecoration.copyWith(
//                       suffixIcon: const Icon(Icons.calendar_today),
//                     ),
//                     child: Text(
//                       tempRow[fieldname]?.toString() ?? 'Select Date',
//                       style: const TextStyle(fontSize: 14, color: Colors.black),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         case 'Link':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: LinkField(
//               fieldLabel: label,
//               fieldName: fieldname,
//               linkDoctype: options ?? '',
//               fetchLinkOptions: _fetchLinkOptions,
//               formData: tempRow,
//               onValueChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//             ),
//           );
//         case 'Dynamic Link':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: tempRow[options] != null && tempRow[options].isNotEmpty
//                 ? LinkField(
//                     fieldLabel: label,
//                     fieldName: fieldname,
//                     linkDoctype: tempRow[options] ?? '',
//                     fetchLinkOptions: _fetchLinkOptions,
//                     formData: tempRow,
//                     onValueChanged: (value) {
//                       setModalState(() {
//                         tempRow[fieldname] = value;
//                         _updateDependentFields();
//                       });
//                     },
//                   )
//                 : const SizedBox.shrink(),
//           );
//         case 'Check':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SizedBox(
//                   width: 24,
//                   height: 24,
//                   child: Checkbox(
//                     value:
//                         tempRow[fieldname] == true || tempRow[fieldname] == 1,
//                     onChanged: readOnly
//                         ? null
//                         : (value) {
//                             setModalState(() {
//                               tempRow[fieldname] = value ?? false;
//                               _updateDependentFields();
//                             });
//                           },
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Flexible(
//                   child: Text(
//                     label,
//                     style: const TextStyle(fontSize: 14, color: Colors.black),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         case 'Attach':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 ElevatedButton(
//                   onPressed: readOnly
//                       ? null
//                       : () async {
//                           try {
//                             FilePickerResult? result =
//                                 await FilePicker.platform.pickFiles();
//                             if (result != null) {
//                               setModalState(() {
//                                 tempRow[fieldname] = result.files.single.path;
//                                 _updateDependentFields();
//                               });
//                             }
//                           } catch (e) {
//                             developer.log("Error picking file: $e");
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(content: Text("Error picking file: $e")),
//                             );
//                           }
//                         },
//                   child: const Text('Upload File'),
//                 ),
//                 if (tempRow[fieldname] != null)
//                   Text(
//                     'File: ${tempRow[fieldname].toString().split('/').last}',
//                     style: const TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//               ],
//             ),
//           );
//         case 'Image':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 ElevatedButton(
//                   onPressed: readOnly
//                       ? null
//                       : () async {
//                           try {
//                             FilePickerResult? result = await FilePicker.platform
//                                 .pickFiles(type: FileType.image);
//                             if (result != null) {
//                               setModalState(() {
//                                 tempRow[fieldname] = result.files.single.path;
//                                 _updateDependentFields();
//                               });
//                             }
//                           } catch (e) {
//                             developer.log("Error picking image: $e");
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                   content: Text("Error picking image: $e")),
//                             );
//                           }
//                         },
//                   child: const Text('Upload Image'),
//                 ),
//                 if (tempRow[fieldname] != null)
//                   Image.network(
//                     tempRow[fieldname].toString(),
//                     height: 100,
//                     width: 100,
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stackTrace) => const Text(
//                       'Image preview not available',
//                       style: TextStyle(fontSize: 12, color: Colors.grey),
//                     ),
//                   ),
//               ],
//             ),
//           );
//         case 'Select':
//           if (options == null) return const SizedBox.shrink();
//           List<String> selectOptions = (options as String)
//               .split('\n')
//               .where((opt) => opt.isNotEmpty)
//               .toList();
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: DropdownButtonFormField<String>(
//               value: tempRow[fieldname] != null &&
//                       selectOptions.contains(tempRow[fieldname])
//                   ? tempRow[fieldname]
//                   : selectOptions.isNotEmpty
//                       ? selectOptions.first
//                       : null,
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               items: selectOptions
//                   .map((option) => DropdownMenuItem(
//                         value: option,
//                         child:
//                             Text(option, style: const TextStyle(fontSize: 13)),
//                       ))
//                   .toList(),
//               onChanged: readOnly
//                   ? null
//                   : (value) {
//                       setModalState(() {
//                         tempRow[fieldname] = value;
//                         _updateDependentFields();
//                       });
//                     },
//               validator: required && !readOnly
//                   ? (value) => value == null || value.isEmpty
//                       ? '$label is required'
//                       : null
//                   : null,
//             ),
//           );
//         case 'Password':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               obscureText: true,
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         case 'Duration':
//           return Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//             child: TextFormField(
//               initialValue: tempRow[fieldname]?.toString() ?? '',
//               decoration: inputDecoration,
//               style: const TextStyle(fontSize: 14, color: Colors.black),
//               readOnly: readOnly || (fetchFrom != null),
//               onChanged: (value) {
//                 setModalState(() {
//                   tempRow[fieldname] = value;
//                   _updateDependentFields();
//                 });
//               },
//               validator: required && !readOnly
//                   ? (value) => value!.isEmpty ? '$label is required' : null
//                   : null,
//             ),
//           );
//         default:
//           return SizedBox(
//             width: double.infinity,
//             height: 40,
//             child: Text(
//               "Unsupported field type: $fieldtype",
//               style: const TextStyle(fontSize: 12, color: Colors.grey),
//             ),
//           );
//       }
//     } catch (e) {
//       developer.log("Error building field $fieldname: $e");
//       return SizedBox(
//         width: double.infinity,
//         child: Text(
//           "Error rendering $label: $e",
//           style: const TextStyle(fontSize: 12, color: Colors.red),
//         ),
//       );
//     }
//   }

//   Future<List<dynamic>> _fetchLinkOptions(
//       String linkDoctype, String query) async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? token = prefs.getString('token');
//       final url =
//           '${widget.baseUrl}/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query';
//       developer.log("Fetching link options from: $url");
//       final response = await http.get(Uri.parse(url), headers: {
//         'Content-Type': 'application/json',
//         'Authorization': '$token',
//       });

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         developer.log("Link options fetched: ${data['message']}");
//         return data['message'] ?? [];
//       } else {
//         throw Exception('Failed to fetch link options: ${response.body}');
//       }
//     } catch (e) {
//       developer.log("Error fetching link options: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error fetching link options: $e")),
//       );
//       return [];
//     }
//   }

//   void _openFormModal(BuildContext context, [int? editIndex]) {
//     Map<String, dynamic> tempRow = editIndex != null
//         ? Map<String, dynamic>.from(rows[editIndex])
//         : {
//             for (var column in columns)
//               column['fieldname']: column['fieldtype'] == 'Check' ? false : null
//           };

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setModalState) {
//             developer.log("Opening modal with tempRow: $tempRow");
//             List<Widget> sections = [];
//             List<Widget> currentSectionFields = [];

//             if (columns.isEmpty || columns[0]['fieldtype'] != 'Section Break') {
//               sections.add(
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Padding(
//                       padding: EdgeInsets.all(8.0),
//                       child: Text(
//                         "Details",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     const Divider(),
//                   ],
//                 ),
//               );
//             }

//             for (var column in columns) {
//               if (column['fieldtype'] == 'Section Break') {
//                 if (currentSectionFields.isNotEmpty) {
//                   if (sections.last is ExpansionTile) {
//                     sections.last = ExpansionTile(
//                       title: (sections.last as ExpansionTile).title,
//                       initiallyExpanded:
//                           (sections.last as ExpansionTile).initiallyExpanded,
//                       children: currentSectionFields,
//                     );
//                   } else if (sections.last is Column) {
//                     sections.last = Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: (sections.last as Column).children +
//                           currentSectionFields,
//                     );
//                   }
//                   currentSectionFields = [];
//                 }
//                 if (column['collapsible'] == 1) {
//                   sections.add(
//                     ExpansionTile(
//                       title: Text(
//                         column['label'] ?? 'Section',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       initiallyExpanded: true,
//                       children: [],
//                     ),
//                   );
//                 } else {
//                   sections.add(
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         if (column['label'] != null)
//                           Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Text(
//                               column['label'],
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         const Divider(),
//                       ],
//                     ),
//                   );
//                 }
//               } else if (column['fieldtype'] != 'Column Break') {
//                 Widget fieldWidget =
//                     _buildField(column, tempRow, setModalState);
//                 if (fieldWidget is! SizedBox ||
//                     (fieldWidget as SizedBox).height != null) {
//                   currentSectionFields.add(fieldWidget);
//                 }
//               }
//             }

//             if (currentSectionFields.isNotEmpty) {
//               if (sections.last is ExpansionTile) {
//                 sections.last = ExpansionTile(
//                   title: (sections.last as ExpansionTile).title,
//                   initiallyExpanded:
//                       (sections.last as ExpansionTile).initiallyExpanded,
//                   children: currentSectionFields,
//                 );
//               } else if (sections.last is Column) {
//                 sections.last = Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children:
//                       (sections.last as Column).children + currentSectionFields,
//                 );
//               }
//             }

//             return Container(
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.9,
//               ),
//               padding: EdgeInsets.only(
//                 bottom: MediaQuery.of(context).viewInsets.bottom,
//                 left: 16,
//                 right: 16,
//                 top: 16,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       editIndex == null ? "Add New Row" : "Edit Row",
//                       style: const TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     if (sections.isEmpty)
//                       const SizedBox(
//                         height: 40,
//                         child: Text(
//                           "No fields available",
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                       )
//                     else
//                       ...sections,
//                     const SizedBox(height: 16),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.black,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         onPressed: () {
//                           Navigator.pop(context);
//                           setState(() {
//                             if (editIndex != null) {
//                               rows[editIndex] = Map.from(tempRow);
//                             } else {
//                               rows.add(Map.from(tempRow));
//                             }
//                             widget.onValueChanged(rows);
//                             developer.log("Saved row: $tempRow");
//                           });
//                         },
//                         child: const Text(
//                           "Save",
//                           style: TextStyle(fontSize: 13, color: Colors.white),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.label,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         const SizedBox(height: 10),
//         if (isLoading)
//           const SizedBox(
//             height: 40,
//             child: Center(child: CircularProgressIndicator()),
//           )
//         else if (rows.isEmpty)
//           const SizedBox(
//             height: 40,
//             child: Text(
//               "No rows added",
//               style: TextStyle(fontSize: 13, color: Colors.grey),
//             ),
//           )
//         else
//           ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: rows.length,
//             itemBuilder: (context, rowIndex) {
//               return Card(
//                 color: Colors.white,
//                 margin: const EdgeInsets.symmetric(vertical: 5),
//                 child: ListTile(
//                   title: Text(
//                     "Item ${rowIndex + 1}",
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: columns
//                         .where((column) =>
//                             column['in_list_view'] == 1 &&
//                             column['hidden'] != 1)
//                         .map((column) {
//                       return Text(
//                         "${column['label']}: ${rows[rowIndex][column['fieldname']] ?? ''}",
//                         style:
//                             const TextStyle(fontSize: 13, color: Colors.grey),
//                       );
//                     }).toList(),
//                   ),
//                   trailing: SizedBox(
//                     width: 100,
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.edit, color: Colors.blue),
//                           onPressed: () => _editRow(rowIndex),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => _removeRow(rowIndex),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         Align(
//           alignment: Alignment.centerRight,
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.black,
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: _addRow,
//             child: const Text(
//               "Add Row",
//               style: TextStyle(fontSize: 13, color: Colors.white),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class LinkField extends StatefulWidget {
//   final String fieldLabel;
//   final String fieldName;
//   final String linkDoctype;
//   final Future<List<dynamic>> Function(String, String) fetchLinkOptions;
//   final Map<String, dynamic> formData;
//   final Function(String?) onValueChanged;

//   const LinkField({
//     required this.fieldLabel,
//     required this.fieldName,
//     required this.linkDoctype,
//     required this.fetchLinkOptions,
//     required this.formData,
//     required this.onValueChanged,
//     Key? key,
//   }) : super(key: key);

//   @override
//   _LinkFieldState createState() => _LinkFieldState();
// }

// class _LinkFieldState extends State<LinkField> {
//   String? _selectedValue;
//   List<dynamic> _options = [];
//   List<dynamic> _filteredOptions = [];
//   String _searchQuery = '';
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _selectedValue = widget.formData[widget.fieldName];
//     _fetchOptions();
//   }

//   Future<void> _fetchOptions() async {
//     setState(() => _isLoading = true);
//     try {
//       _options =
//           await widget.fetchLinkOptions(widget.linkDoctype, _searchQuery);
//       if (mounted) {
//         setState(() {
//           _filteredOptions = _options;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       developer.log("Error fetching link options: $e");
//       if (mounted) {
//         setState(() {
//           _filteredOptions = [];
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       height: 60,
//       child: GestureDetector(
//         onTap: () async {
//           await _fetchOptions();
//           if (!mounted) return;
//           showModalBottomSheet(
//             context: context,
//             isScrollControlled: true,
//             backgroundColor: Colors.white,
//             builder: (context) => StatefulBuilder(
//               builder: (context, setModalState) => SizedBox(
//                 height: MediaQuery.of(context).size.height * 0.7,
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Text(
//                         'Select ${widget.fieldLabel}',
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                       child: TextField(
//                         onChanged: (query) async {
//                           setModalState(() {
//                             _searchQuery = query;
//                             _isLoading = true;
//                           });
//                           final newOptions = await widget.fetchLinkOptions(
//                               widget.linkDoctype, query);
//                           if (mounted) {
//                             setModalState(() {
//                               _options = newOptions;
//                               _filteredOptions = newOptions;
//                               _isLoading = false;
//                             });
//                           }
//                         },
//                         decoration: const InputDecoration(
//                           labelText: 'Search',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Expanded(
//                       child: _isLoading
//                           ? const Center(child: CircularProgressIndicator())
//                           : _filteredOptions.isEmpty
//                               ? const Center(
//                                   child: Text(
//                                     "No options available",
//                                     style: TextStyle(
//                                         fontSize: 12, color: Colors.grey),
//                                   ),
//                                 )
//                               : ListView.builder(
//                                   itemCount: _filteredOptions.length,
//                                   itemBuilder: (context, index) {
//                                     final option = _filteredOptions[index];
//                                     return ListTile(
//                                       title: Text(
//                                         option['value']?.toString() ?? '',
//                                         style: TextStyle(
//                                           fontSize: 13,
//                                           fontWeight: FontWeight.bold,
//                                           color:
//                                               _selectedValue == option['value']
//                                                   ? Colors.blue
//                                                   : Colors.black,
//                                         ),
//                                       ),
//                                       subtitle: option['description'] != null
//                                           ? Text(
//                                               option['description'].toString(),
//                                               style:
//                                                   const TextStyle(fontSize: 12),
//                                             )
//                                           : null,
//                                       onTap: () {
//                                         final selected =
//                                             option['value']?.toString();
//                                         if (selected != null) {
//                                           setState(() {
//                                             _selectedValue = selected;
//                                             widget.formData[widget.fieldName] =
//                                                 _selectedValue;
//                                             widget
//                                                 .onValueChanged(_selectedValue);
//                                           });
//                                           Navigator.pop(context);
//                                         }
//                                       },
//                                     );
//                                   },
//                                 ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//         child: InputDecorator(
//           decoration: InputDecoration(
//             labelText: widget.fieldLabel,
//             labelStyle: const TextStyle(fontSize: 14, color: Colors.black),
//             hintText: 'Select ${widget.fieldLabel}',
//             hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
//             filled: true,
//             fillColor: Colors.white,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(15),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(15),
//               borderSide: const BorderSide(color: Colors.black),
//             ),
//           ),
//           child: Text(
//             _selectedValue ??
//                 widget.formData[widget.fieldName] ??
//                 'Select ${widget.fieldLabel}',
//             style: TextStyle(
//               fontSize: 14,
//               color:
//                   (_selectedValue ?? widget.formData[widget.fieldName]) == null
//                       ? Colors.grey
//                       : Colors.black,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
