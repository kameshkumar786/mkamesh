import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:mkamesh/screens/formscreens/DoctypeListView.dart';
import 'package:mkamesh/screens/formscreens/FileViewer.dart';
import 'package:mkamesh/screens/formscreens/FrappeTableField.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'package:signature/signature.dart'; // Add this import at the top of your file
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart'; // For Leaflet-style maps
import 'package:latlong2/latlong.dart'; // For coordinates
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap; // Alias for flutter_map
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class FrappeCrudForm extends StatefulWidget {
  final String doctype;
  final String docname;
  final String baseUrl;

  const FrappeCrudForm({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
  });

  @override
  _FrappeCrudFormState createState() => _FrappeCrudFormState();
}

class _FrappeCrudFormState extends State<FrappeCrudForm> {
  List<Map<String, dynamic>> fields = [];
  Map<String, dynamic> formData = {};
  Map<String, dynamic> cur_doc = {};
  Map<String, dynamic> cur_frm = {};
  dynamic doc_permissions;
  Map<String, dynamic> metaData = {};
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;
  bool updateAble = false;
  bool isdirtyform = false;
  List<Map<String, dynamic>> _workflowActions = [];

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
          metaData = data;
          fields = List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
          fields.sort((a, b) => (a['idx'] ?? 0).compareTo(b['idx'] ?? 0));
          for (var field in fields) {
            String fieldName = field['fieldname'] ?? '';
            formData[fieldName] = null;
            controllers[fieldName] = TextEditingController();
          }
          isLoading = false;
        });

        if (widget.docname.isNotEmpty) {
          await fetchDocumentData(token);
        }
      } else {
        throw Exception('Failed to load fields: ${response.body}');
      }
    } catch (e) {
      developer.log("Error fetching doctype fields: $e");
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
        setState(() {
          cur_frm = data;
          doc_permissions = data['permissions'];
          cur_doc = data['docs'][0];

          for (var field in fields) {
            String fieldName = field['fieldname'] ?? '';
            if (data['docs'][0][fieldName] != null) {
              if (field['fieldtype'] == 'Check') {
                formData[fieldName] = data['docs'][0][fieldName] == 1;
              } else if (field['fieldtype'] == 'Table MultiSelect') {
                formData[fieldName] =
                    List<String>.from(data['docs'][0][fieldName] ?? []);
              } else {
                formData[fieldName] = data['docs'][0][fieldName];
              }
              controllers[fieldName]?.text = formData[fieldName].toString();
            }
          }
          isLoading = false;
        });
        _fetchWorkflowTransitions();
      } else {
        throw Exception('Failed to load document data: ${response.body}');
      }
    } catch (e) {
      developer.log("Error fetching document data: $e");
      setState(() {
        isLoading = false;
      });
      showError(e.toString());
    }
  }

  Future<void> _fetchWorkflowTransitions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      Map<String, dynamic> doc = Map.from(cur_frm['docs'][0]);
      doc.addAll(formData);

      final response = await http.post(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.model.workflow.get_transitions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({"doc": doc}),
      );
      print('payload ${doc}');
      print('response ${jsonDecode(response.body)}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] != null && data['message'] is List) {
          setState(() {
            _workflowActions = List<Map<String, dynamic>>.from(data['message']);
          });
        }
      } else {
        developer.log('Failed to load workflow transitions: ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching workflow transitions: $e');
    }
  }

  Future<void> _performWorkflowAction(String action) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      Map<String, dynamic> doc = Map.from(cur_frm['docs'][0]);
      doc.addAll(formData);

      final response = await http.post(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.model.workflow.apply_workflow'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({"doc": doc, "action": action}),
      );
      print('response work flow ${response.body}');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workflow action "$action" applied successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh document data to show updated state
        // await fetchDoctypeFields();
        // _fetchWorkflowTransitions();
      } else {
        String errorMessage = _extractFrappeError(response.body);
        throw Exception(errorMessage);
      }
    } catch (e) {
      developer.log('Error performing workflow action: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _evaluateMultipleConditions(String? condition) {
    if (condition == null || condition.isEmpty) return true;

    try {
      String parsedCondition = condition.trim().replaceAll('doc.', '');
      List<String> parts = parsedCondition.split(RegExp(r'\s*(&&|\|\|)\s*'));
      List<String> operators = RegExp(r'(&&|\|\|)')
          .allMatches(parsedCondition)
          .map((match) => match.group(0)!)
          .toList();

      bool result = true;
      for (int i = 0; i < parts.length; i++) {
        String part = parts[i].trim();
        bool partResult = _evaluateSingleCondition(part);

        if (i > 0) {
          String operator = operators[i - 1];
          if (operator == '&&') {
            result = result && partResult;
          } else if (operator == '||') {
            result = result || partResult;
          }
        } else {
          result = partResult;
        }
      }
      return result;
    } catch (e) {
      developer.log("Error evaluating condition '$condition': $e");
      return false;
    }
  }

  bool _evaluateSingleCondition(String condition) {
    try {
      if (condition.contains('==')) {
        var parts = condition.split('==').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1].replaceAll('"', '').replaceAll("'", "");
        return formData[fieldName]?.toString() == value;
      } else if (condition.contains('!=')) {
        var parts = condition.split('!=').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1].replaceAll('"', '').replaceAll("'", "");
        return formData[fieldName]?.toString() != value;
      } else if (condition.contains('>')) {
        var parts = condition.split('>').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1];
        return (double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0) >
            (double.tryParse(value) ?? 0);
      } else if (condition.contains('<')) {
        var parts = condition.split('<').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1];
        return (double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0) <
            (double.tryParse(value) ?? 0);
      } else if (condition.contains('>=')) {
        var parts = condition.split('>=').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1];
        return (double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0) >=
            (double.tryParse(value) ?? 0);
      } else if (condition.contains('<=')) {
        var parts = condition.split('<=').map((p) => p.trim()).toList();
        if (parts.length != 2) return false;
        String fieldName = parts[0];
        String value = parts[1];
        return (double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0) <=
            (double.tryParse(value) ?? 0);
      } else {
        String fieldName = condition.trim();
        dynamic value = formData[fieldName];
        return value != null &&
            value.toString().isNotEmpty &&
            value.toString() != 'false' &&
            value.toString() != '0';
      }
    } catch (e) {
      developer.log("Error evaluating single condition '$condition': $e");
      return false;
    }
  }

  bool _convertToBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return false;
  }

  Widget _buildField(Map<String, dynamic> field) {
    String fieldType = field['fieldtype'] ?? '';
    String fieldName = field['fieldname'] ?? '';
    String? label = field['label'];
    bool readOnly = _convertToBool(field['read_only']);
    bool hidden = _convertToBool(field['hidden']);
    bool required = _convertToBool(field['reqd']);
    String? dependsOn = field['depends_on'];
    String? mandatoryDependsOn = field['mandatory_depends_on'];
    String? readOnlyDependsOn = field['read_only_depends_on'];
    String? fetchFrom = field['fetch_from'];

    // Make all fields read-only if docstatus==1, unless allow_on_submit==1
    if (cur_frm.isNotEmpty &&
        cur_frm['docs'] != null &&
        cur_frm['docs'] is List &&
        cur_frm['docs'].isNotEmpty &&
        cur_frm['docs'][0]['docstatus'] == 1) {
      readOnly = field['allow_on_submit'] == 1 ? false : true;
    }

    if (hidden ||
        (dependsOn != null && !_evaluateMultipleConditions(dependsOn))) {
      return const SizedBox.shrink();
    }

    dynamic fieldValue = formData[fieldName];
    if (readOnly && (fieldValue == null || fieldValue.toString().isEmpty)) {
      return const SizedBox.shrink();
    }

    if (mandatoryDependsOn != null) {
      required = _evaluateMultipleConditions(mandatoryDependsOn);
    }
    if (readOnlyDependsOn != null) {
      readOnly = _evaluateMultipleConditions(readOnlyDependsOn);
    }

    final controller = controllers[fieldName];

    // Handle fetch_from with a check to prevent repeated calls
    if (fetchFrom != null &&
        fetchFrom.isNotEmpty &&
        !fetchedFields.contains(fieldName)) {
      _fetchFieldValueFromLink(fieldName, fetchFrom);
    }

    final inputDecoration = InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: const TextStyle(
          fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
      floatingLabelStyle: const TextStyle(
          fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
      hintText: 'Enter ${label ?? fieldName}',
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.black),
      ),
      filled: true,
      fillColor: readOnly ? Colors.grey[300] : Colors.white,
    );

    void _updateDependentFields() {
      setState(() {
        isdirtyform = true;
      });

      for (var f in fields) {
        if (f['depends_on']?.contains(fieldName) == true ||
            f['mandatory_depends_on']?.contains(fieldName) == true ||
            f['read_only_depends_on']?.contains(fieldName) == true ||
            f['fetch_from']?.contains(fieldName) == true) {
          setState(() {
            developer.log("Updating dependent field: ${f['fieldname']}");
            if (f['fetch_from'] != null &&
                !fetchedFields.contains(f['fieldname'])) {
              _fetchFieldValueFromLink(f['fieldname'], f['fetch_from']);
            }
          });
        }
      }
    }

    try {
      if (fieldType == 'Data') {
        String? options = field['options']?.toString().toLowerCase();
        Icon? suffixIcon;
        String? errorMessage; // Add local state for error

        if (options == 'email') {
          suffixIcon = const Icon(Icons.email);
        } else if (options == 'phone') {
          suffixIcon = const Icon(Icons.phone);
        } else if (options == 'url') {
          suffixIcon = const Icon(Icons.link);
        }

        String? validateInput(String? value) {
          if (!required || readOnly) return null;
          if (value == null || value.isEmpty) {
            return '$label is required';
          }
          if (options == 'email' &&
              !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Please enter a valid email (e.g., user@example.com)';
          }
          if (options == 'phone' &&
              !RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(value)) {
            return 'Please enter a valid phone number (e.g., +1234567890)';
          }
          if (options == 'url' &&
              !RegExp(r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$')
                  .hasMatch(value)) {
            return 'Please enter a valid URL (e.g., https://example.com)';
          }
          return null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                decoration: inputDecoration.copyWith(
                  suffixIcon: suffixIcon,
                  errorText: errorMessage, // Show error inline
                  errorStyle: const TextStyle(fontSize: 12, color: Colors.red),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                readOnly: readOnly || (fetchFrom != null),
                keyboardType: options == 'email'
                    ? TextInputType.emailAddress
                    : options == 'phone'
                        ? TextInputType.phone
                        : options == 'url'
                            ? TextInputType.url
                            : TextInputType.text,
                onChanged: (value) {
                  setState(() {
                    formData[fieldName] = value;
                    errorMessage = null; // Clear error on change
                    _updateDependentFields();
                  });
                },
                onEditingComplete: () {
                  setState(() {
                    errorMessage = validateInput(controller?.text);
                  });
                  FocusScope.of(context).nextFocus();
                },
                validator: (value) => validateInput(value),
              ),
            ],
          ),
        );
      } else if (fieldType == 'Small Text') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            maxLines: 1,
            decoration: inputDecoration.copyWith(
                hintText: 'Short input for ${label ?? fieldName}'),
            style: const TextStyle(fontSize: 13, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                _updateDependentFields();
              });
            },
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );
      } else if (fieldType == 'Text' || fieldType == 'Text Editor') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            maxLines: fieldType == 'Text Editor' ? 5 : 3,
            decoration: inputDecoration,
            style: const TextStyle(fontSize: 12, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                _updateDependentFields();
              });
            },
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );
      } else if (fieldType == 'Int') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: inputDecoration,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = int.tryParse(value) ?? 0;
                _updateDependentFields();
              });
            },
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );
      } else if (fieldType == 'Float' ||
          fieldType == 'Currency' ||
          fieldType == 'Rate') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: inputDecoration,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = double.tryParse(value) ?? 0.0;
                _updateDependentFields();
              });
            },
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );
      } else if (fieldType == 'Time') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: formData[fieldName] != null
                          ? TimeOfDay.fromDateTime(DateTime.parse(
                              '2023-01-01 ${formData[fieldName]}'))
                          : TimeOfDay.now(),
                    );
                    if (picked != null) {
                      String formattedTime = picked.format(context);
                      setState(() {
                        formData[fieldName] = formattedTime;
                        controller?.text = formattedTime;
                        _updateDependentFields();
                      });
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.access_time)),
              child: Text(
                formData[fieldName]?.toString() ?? 'Select Time',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
          ),
        );
      } else if (fieldType == 'Datetime') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: formData[fieldName] != null
                          ? DateTime.parse(formData[fieldName])
                          : DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        picked = DateTime(picked.year, picked.month, picked.day,
                            time.hour, time.minute);
                        String formattedDateTime =
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(picked);
                        setState(() {
                          formData[fieldName] = formattedDateTime;
                          controller?.text = formattedDateTime;
                          _updateDependentFields();
                        });
                      }
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.calendar_today)),
              child: Text(
                formData[fieldName]?.toString() ?? 'Select Date & Time',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
          ),
        );
      } else if (fieldType == 'Rating') {
        double ratingValue =
            double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0.0;
        int starCount = (ratingValue * 5).round(); // Scale 0-1 to 0-5 stars

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label ?? fieldName,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < starCount ? Icons.star : Icons.star_border,
                      color: Colors.yellow[700],
                    ),
                    onPressed: readOnly
                        ? null
                        : () {
                            setState(() {
                              // Convert the clicked star (0-4 index) to a 0-1 scale
                              double newRating = (index + 1) / 5.0;
                              formData[fieldName] = newRating;
                              controller?.text = newRating
                                  .toStringAsFixed(2); // e.g., 0.20, 0.40
                              _updateDependentFields();
                            });
                          },
                  );
                }),
              ),
              // if (!readOnly) // Optional: Show the numeric value for clarity
              //   Text(
              //     'Value: ${(ratingValue * 100).toStringAsFixed(0)}% (${ratingValue.toStringAsFixed(2)})',
              //     style: const TextStyle(fontSize: 12, color: Colors.grey),
              //   ),
            ],
          ),
        );
      } else if (fieldType == 'Signature') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label ?? fieldName,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Display the base64 signature if it exists
                    if (formData[fieldName] != null &&
                        formData[fieldName].toString().isNotEmpty)
                      Image.memory(
                        base64Decode(
                          (formData[fieldName] as String)
                                  .startsWith('data:image/png;base64,')
                              ? (formData[fieldName] as String)
                                  .substring(22) // Remove prefix for decoding
                              : formData[fieldName] as String,
                        ),
                        fit: BoxFit.contain,
                        height: 150,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Text(
                            'Error loading signature',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Text(
                          'Tap to sign',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    // GestureDetector to open signature pad
                    GestureDetector(
                      onTap: readOnly
                          ? null
                          : () async {
                              final SignatureController sigController =
                                  SignatureController(
                                penStrokeWidth: 3,
                                penColor: Colors.black,
                                exportBackgroundColor: Colors.white,
                              );
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Sign Here'),
                                  content: SizedBox(
                                    height: 200,
                                    width: 300,
                                    child: Signature(
                                      controller: sigController,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        sigController.clear();
                                      },
                                      child: const Text('Clear'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );

                              if (result == true && sigController.isNotEmpty) {
                                final Uint8List? signatureData =
                                    await sigController.toPngBytes();
                                if (signatureData != null) {
                                  String base64Signature =
                                      base64Encode(signatureData);
                                  String dataUrl =
                                      'data:image/png;base64,$base64Signature';
                                  setState(() {
                                    formData[fieldName] =
                                        dataUrl; // Store with prefix
                                    controller?.text =
                                        'Signed'; // Optional display text
                                    _updateDependentFields();
                                  });
                                }
                                sigController.dispose();
                              } else {
                                sigController.dispose();
                              }
                            },
                    ),
                  ],
                ),
              ),
              if (!readOnly &&
                  formData[fieldName] != null &&
                  formData[fieldName].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        formData[fieldName] = null;
                        controller?.text = '';
                        _updateDependentFields();
                      });
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Clear Signature',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        );
      } else if (fieldType == 'Percent') {
        double percentValue =
            double.tryParse(formData[fieldName]?.toString() ?? '0') ?? 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: inputDecoration.copyWith(
                  suffixText: '%',
                  suffixStyle: const TextStyle(fontSize: 14),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                readOnly: readOnly || (fetchFrom != null),
                onChanged: (value) {
                  setState(() {
                    double? percent = double.tryParse(value);
                    percentValue =
                        percent != null && percent >= 0 && percent <= 100
                            ? percent
                            : 0.0;
                    formData[fieldName] = percentValue;
                    controller?.text =
                        percentValue.toStringAsFixed(1); // Sync text field
                    _updateDependentFields();
                  });
                },
                validator: required && !readOnly
                    ? (value) => value!.isEmpty ? '$label is required' : null
                    : null,
              ),
              SizedBox(height: 8),
              Slider(
                value: percentValue,
                min: 0,
                max: 100,
                divisions: 100, // For smooth sliding with 1% steps
                label: '${percentValue.toStringAsFixed(1)}%',
                activeColor: Colors.blue,
                inactiveColor: Colors.grey[300],
                onChanged: readOnly || (fetchFrom != null)
                    ? null
                    : (double newValue) {
                        setState(() {
                          percentValue = newValue;
                          formData[fieldName] = percentValue;
                          controller?.text = percentValue
                              .toStringAsFixed(1); // Sync text field
                          _updateDependentFields();
                        });
                      },
              ),
            ],
          ),
        );
      } else if (fieldType == 'Attach') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(); // Allow all files
                          if (result != null) {
                            setState(() {
                              formData[fieldName] = result.files.single.path;
                              _updateDependentFields();
                            });
                          }
                        } catch (e) {
                          showError("Error picking file: $e");
                        }
                      },
                child:
                    const Text('Upload File', style: TextStyle(fontSize: 13)),
              ),
              if (formData[fieldName] != null)
                Text(
                  'File: ${formData[fieldName].toString().split('/').last}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        );
      } else if (fieldType == 'Image') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Only View able image'),
              // ElevatedButton(
              //   onPressed: readOnly
              //       ? null
              //       : () async {
              //           try {
              //             FilePickerResult? result = await FilePicker.platform
              //                 .pickFiles(
              //                     type: FileType
              //                         .image); // Restrict to images only
              //             if (result != null) {
              //               setState(() {
              //                 formData[fieldName] = result.files.single.path;
              //                 _updateDependentFields();
              //               });
              //             }
              //           } catch (e) {
              //             showError("Error picking image: $e");
              //           }
              //         },
              //   child:
              //       const Text('Upload Image', style: TextStyle(fontSize: 13)),
              // ),
              if (formData[fieldName] != null)
                Image.file(
                  File(formData[fieldName]),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Text(
                      'Image preview not available',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        );
      } else if (fieldType == 'Attach Image') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(
                                  type: FileType
                                      .image); // Restrict to images only
                          if (result != null) {
                            setState(() {
                              formData[fieldName] = result.files.single.path;
                              _updateDependentFields();
                            });
                          }
                        } catch (e) {
                          showError("Error picking image: $e");
                        }
                      },
                child:
                    const Text('Upload Image', style: TextStyle(fontSize: 13)),
              ),
              if (formData[fieldName] != null)
                Image.file(
                  File(formData[fieldName]),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Text(
                      'Image preview not available',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        );
      } else if (fieldType == 'Select') {
        if (field['options'] == null) return const SizedBox.shrink();
        List<String> options = (field['options'] as String)
            .split('\n')
            .where((opt) => opt.isNotEmpty)
            .toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: formData[fieldName] != null &&
                    options.contains(formData[fieldName])
                ? formData[fieldName]
                : options.isNotEmpty
                    ? options.first
                    : null,
            decoration: inputDecoration,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            items: options.map((option) {
              final isSelected = formData[fieldName] == option;
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.black87,
                  ),
                ),
              );
            }).toList(),
            onChanged: readOnly
                ? null
                : (value) {
                    setState(() {
                      formData[fieldName] = value;
                      _updateDependentFields();
                    });
                  },
            validator: required && !readOnly
                ? (value) =>
                    value == null || value.isEmpty ? '$label is required' : null
                : null,
          ),
        );
      } else if (fieldType == 'Date') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: formData[fieldName] != null
                          ? DateTime.tryParse(formData[fieldName]) ??
                              DateTime.now()
                          : DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2101),
                      builder: (context, child) => Theme(
                        data: ThemeData.light().copyWith(
                          primaryColor: Colors.black,
                          hintColor: Colors.black,
                          colorScheme: ColorScheme.light(primary: Colors.black),
                          dialogBackgroundColor: Colors.white,
                          buttonTheme: const ButtonThemeData(
                              textTheme: ButtonTextTheme.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd').format(picked);
                      setState(() {
                        formData[fieldName] = formattedDate;
                        controller?.text = formattedDate;
                        _updateDependentFields();
                      });
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.calendar_today)),
              child: Text(
                formData[fieldName]?.toString() ?? 'Select Date',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
          ),
        );
      } else if (fieldType == 'Link') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: LinkField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: fieldType == 'Dynamic Link'
                ? formData[field['options']] ?? ''
                : field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: formData,
            onValueChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                controller?.text = value ?? '';
                _updateDependentFields();
              });
            },
            readOnly: readOnly,
          ),
        );
      } else if (fieldType == 'Dynamic Link') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: formData[field['options']]
              ? LinkField(
                  fieldLabel: label ?? '',
                  fieldName: fieldName,
                  linkDoctype: fieldType == 'Dynamic Link'
                      ? formData[field['options']] ?? ''
                      : field['options'] ?? '',
                  fetchLinkOptions: fetchLinkOptions,
                  formData: formData,
                  onValueChanged: (value) {
                    setState(() {
                      formData[fieldName] = value;
                      controller?.text = value ?? '';
                      _updateDependentFields();
                    });
                  },
                  readOnly: readOnly,
                )
              : SizedBox.shrink(),
        );
      } else if (fieldType == 'Check') {
        // return Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        //   child: Row(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       SizedBox(
        //         width: 24,
        //         height: 24,
        //         child: Checkbox(
        //           value: formData[fieldName] ?? false,
        //           onChanged: readOnly
        //               ? null
        //               : (value) {
        //                   setState(() {
        //                     formData[fieldName] = value ?? false;
        //                     _updateDependentFields();
        //                   });
        //                 },
        //         ),
        //       ),
        //       const SizedBox(width: 8),
        //       Flexible(
        //         child: Text(
        //           label ?? '',
        //           style: const TextStyle(fontSize: 14, color: Colors.black),
        //           overflow: TextOverflow.ellipsis,
        //         ),
        //       ),
        //     ],
        //   ),
        // );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label ?? '',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 48, // Adjust width as needed
                height: 25,
                child: Transform.scale(
                  scale: 0.9, // Adjust the scale factor to change the size
                  child: Switch(
                    value: (formData[fieldName] ?? 0) == 1,
                    activeTrackColor: Colors.black, // Background when active
                    inactiveTrackColor:
                        Colors.grey.shade300, // Background when inactive
                    activeColor: Colors.white, // Ball color when active
                    inactiveThumbColor: Colors.white,
                    onChanged: readOnly
                        ? null
                        : (value) {
                            setState(() {
                              formData[fieldName] = value ? 1 : 0;
                              _updateDependentFields();
                            });
                          },
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (fieldType == 'Image') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          if (result != null) {
                            setState(() {
                              formData[fieldName] = result.files.single.path;
                              _updateDependentFields();
                            });
                          }
                        } catch (e) {
                          showError("Error picking image: $e");
                        }
                      },
                child:
                    const Text('Upload Image', style: TextStyle(fontSize: 13)),
              ),
              if (formData[fieldName] != null)
                Image.network(
                  formData[fieldName],
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Text(
                      'Image preview not available',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        );
      } else if (fieldType == 'Attach') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        try {
                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles();
                          if (result != null) {
                            setState(() {
                              formData[fieldName] = result.files.single.path;
                              _updateDependentFields();
                            });
                          }
                        } catch (e) {
                          showError("Error picking file: $e");
                        }
                      },
                child:
                    const Text('Upload File', style: TextStyle(fontSize: 13)),
              ),
              if (formData[fieldName] != null)
                Text(
                  'File: ${formData[fieldName].toString().split('/').last}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        );
      } else if (fieldType == 'HTML') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: SizedBox(
            height: 200,
            child: TextFormField(
              controller: controller,
              maxLines: null,
              decoration: inputDecoration,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              readOnly: readOnly || (fetchFrom != null),
              onChanged: (value) {
                setState(() {
                  formData[fieldName] = value;
                  _updateDependentFields();
                });
              },
            ),
          ),
        );
      } else if (fieldType == 'Password') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: inputDecoration,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                _updateDependentFields();
              });
            },
          ),
        );
      } else if (fieldType == 'Duration') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            decoration: inputDecoration,
            style: const TextStyle(fontSize: 14, color: Colors.black),
            readOnly: readOnly || (fetchFrom != null),
            onChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                _updateDependentFields();
              });
            },
          ),
        );
      } else if (fieldType == 'Table MultiSelect') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: MultiSelectField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: formData,
            onValueChanged: (values) {
              setState(() {
                formData[fieldName] = values;
                _updateDependentFields();
              });
            },
          ),
        );
      } else if (fieldType == 'Table') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: FrappeTableField(
            label: label ?? '',
            childTableDoctype: field['options'] ?? '',
            formData: formData,
            field: field,
            baseUrl: widget.baseUrl,
            initialData: formData[fieldName] ?? [],
            onValueChanged: (value) {
              setState(() {
                formData[fieldName] = value;
                _updateDependentFields();
              });
            },
          ),
        );
      } else if (fieldType == 'Geolocation') {
        String? options =
            field['options']?.toString(); // Check options for map type
        bool useGoogleMaps = options == 'Google Maps';

        // Parse existing coordinates from formData
        LatLng? leafletPoint;
        gmaps.LatLng? googlePoint;
        if (formData[fieldName] != null &&
            formData[fieldName].toString().isNotEmpty) {
          try {
            Map<String, dynamic> geoData =
                jsonDecode(formData[fieldName] as String);
            double lat = double.parse(geoData['latitude'].toString());
            double lng = double.parse(geoData['longitude'].toString());
            leafletPoint = LatLng(lat, lng);
            googlePoint = gmaps.LatLng(lat, lng);
          } catch (e) {
            developer.log('Error parsing Geolocation data: $e');
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label ?? fieldName,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: useGoogleMaps
                    ? _GoogleMapWidget(
                        initialPoint: googlePoint,
                        onPointSelected: (point) {
                          setState(() {
                            googlePoint = point;
                            formData[fieldName] = jsonEncode({
                              'latitude': point.latitude,
                              'longitude': point.longitude,
                            });
                            controller?.text =
                                'Marked at ${point.latitude}, ${point.longitude}';
                            _updateDependentFields();
                          });
                        },
                        readOnly: readOnly,
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: leafletPoint ??
                              const LatLng(
                                  51.509364, -0.128928), // Default: London
                          initialZoom: 13.0,
                          onTap: readOnly
                              ? null
                              : (tapPosition, point) {
                                  setState(() {
                                    leafletPoint = point;
                                    formData[fieldName] = jsonEncode({
                                      'latitude': point.latitude,
                                      'longitude': point.longitude,
                                    });
                                    controller?.text =
                                        'Marked at ${point.latitude}, ${point.longitude}';
                                    _updateDependentFields();
                                  });
                                },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          if (leafletPoint != null)
                            MarkerLayer(
                              markers: [
                                fmap.Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: leafletPoint!,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40.0,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
              if (!readOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (formData[fieldName] != null)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              formData[fieldName] = null;
                              leafletPoint = null;
                              googlePoint = null;
                              controller?.text = '';
                              _updateDependentFields();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Clear Marker',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ElevatedButton(
                        onPressed: () async {
                          final dynamic newPoint = await showDialog(
                            context: context,
                            builder: (context) => useGoogleMaps
                                ? _GoogleMapDialog(initialPoint: googlePoint)
                                : _LeafletMapDialog(initialPoint: leafletPoint),
                          );
                          if (newPoint != null) {
                            setState(() {
                              if (useGoogleMaps) {
                                googlePoint = newPoint as gmaps.LatLng;
                                formData[fieldName] = jsonEncode({
                                  'latitude': googlePoint!.latitude,
                                  'longitude': googlePoint!.longitude,
                                });
                                controller?.text =
                                    'Marked at ${googlePoint!.latitude}, ${googlePoint!.longitude}';
                              } else {
                                leafletPoint = newPoint as LatLng;
                                formData[fieldName] = jsonEncode({
                                  'latitude': leafletPoint!.latitude,
                                  'longitude': leafletPoint!.longitude,
                                });
                                controller?.text =
                                    'Marked at ${leafletPoint!.latitude}, ${leafletPoint!.longitude}';
                              }
                              _updateDependentFields();
                            });
                          }
                        },
                        child: const Text('Open Full Map'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      } else {
        return SizedBox(
          width: double.infinity,
          height: 40,
          child: Text(
            "Unsupported field type: $fieldType",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      }
    } catch (e) {
      if (!errorLoggedFields.contains(fieldName)) {
        developer.log("Error building field $fieldName: $e");
        errorLoggedFields.add(fieldName);
      }
      return SizedBox(
        width: double.infinity,
        child: Text(
          "Error rendering $label: $e",
          style: const TextStyle(fontSize: 12, color: Colors.red),
        ),
      );
    }
  }

// Add these to your class
  Set<String> fetchedFields = {};
  Set<String> errorLoggedFields = {};

  Future<void> _fetchFieldValueFromLink(
      String fieldName, String fetchFrom) async {
    try {
      List<String> parts = fetchFrom.split('.');
      if (parts.length != 2) return;
      String linkFieldName = parts[0];
      String targetField = parts[1];

      String? linkedDocName = formData[linkFieldName];
      if (linkedDocName == null || linkedDocName.isEmpty) return;

      String? linkDoctype;
      for (var f in fields) {
        if (f['fieldname'] == linkFieldName && f['fieldtype'] == 'Link') {
          linkDoctype = f['options'];
          break;
        }
      }
      if (linkDoctype == null) return;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/resource/$linkDoctype/$linkedDocName'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        dynamic fetchedValue = data['data'][targetField];
        if (fetchedValue != null) {
          setState(() {
            formData[fieldName] = fetchedValue;
            controllers[fieldName]?.text = fetchedValue.toString();
            fetchedFields.add(fieldName);
          });
        }
      } else {
        if (!errorLoggedFields.contains(fieldName)) {
          developer.log(
              "Failed to fetch $fetchFrom for $fieldName: ${response.body}");
          errorLoggedFields.add(fieldName);
        }
      }
    } catch (e) {
      if (!errorLoggedFields.contains(fieldName)) {
        developer
            .log("Error fetching value for $fieldName from $fetchFrom: $e");
        errorLoggedFields.add(fieldName);
      }
    }
  }

// Add this to your class to track fetched and errored fields

// Optionally reset these sets when the form initializes or submits
  // @override
  // void initState() {
  //   super.initState();
  //   fetchedFields.clear();
  //   errorLoggedFields.clear();
  //   fetchDoctypeFields();
  // }

// New method to fetch value from linked document
  // Future<void> _fetchFieldValueFromLink(
  //     String fieldName, String fetchFrom) async {
  //   try {
  //     // Parse fetch_from (e.g., "customer.customer_name")
  //     List<String> parts = fetchFrom.split('.');
  //     if (parts.length != 2) return;
  //     String linkFieldName = parts[0]; // e.g., "customer"
  //     String targetField = parts[1]; // e.g., "customer_name"

  //     // Get the linked document name from the Link field
  //     String? linkedDocName = formData[linkFieldName];
  //     if (linkedDocName == null || linkedDocName.isEmpty) return;

  //     // Find the doctype of the Link field
  //     String? linkDoctype;
  //     for (var f in fields) {
  //       if (f['fieldname'] == linkFieldName && f['fieldtype'] == 'Link') {
  //         linkDoctype = f['options'];
  //         break;
  //       }
  //     }
  //     if (linkDoctype == null) return;

  //     // Fetch token
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? token = prefs.getString('token');
  //     if (token == null) return;

  //     // Make API call to fetch the linked document
  //     final response = await http.get(
  //       Uri.parse('${widget.baseUrl}/api/resource/$linkDoctype/$linkedDocName'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': '$token',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       dynamic fetchedValue = data['data'][targetField];
  //       if (fetchedValue != null) {
  //         setState(() {
  //           formData[fieldName] = fetchedValue;
  //           controllers[fieldName]?.text = fetchedValue.toString();
  //         });
  //       }
  //     } else {
  //       developer.log("Failed to fetch $fetchFrom: ${response.body}");
  //     }
  //   } catch (e) {
  //     developer.log("Error fetching value for $fieldName from $fetchFrom: $e");
  //   }
  // }

  Future<List<dynamic>> fetchLinkOptions(
      String linkDoctype, String query) async {
    try {
      // Get token from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      // Make the HTTP request
      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out. Check your network connection.');
      });

      // Handle HTTP status codes
      switch (response.statusCode) {
        case 200:
          final data = jsonDecode(response.body);
          return data['message'] ?? [];
        case 401:
          throw Exception('Unauthorized: Invalid or expired token.');
        case 403:
          throw Exception(
              'Permission denied: You lack access to this resource.');
        case 404:
          throw Exception('Resource not found on the server.');
        case 500:
          throw Exception('Server error. Please try again later.');
        default:
          throw Exception('Failed to fetch link options: ${response.body}');
      }
    } on FormatException catch (e) {
      // Handle JSON parsing errors
      developer.log("JSON parsing error: $e");
      showError('Invalid response format from server.');
      return [];
    } on SocketException catch (e) {
      // Handle network connectivity issues
      developer.log("Network error: $e");
      showError('No internet connection. Please check your network.');
      return [];
    } on TimeoutException catch (e) {
      // Handle timeout explicitly (though covered by .timeout above)
      developer.log("Timeout error: $e");
      showError('Request took too long. Please try again.');
      return [];
    } catch (e) {
      // Catch any other unexpected errors
      developer.log("Unexpected error fetching link options: $e");
      showError('An error occurred: $e');
      return [];
    }
  }

  Future<void> _submit() async {
    // Check for required fields locally
    print(fields);
    for (var field in fields) {
      String fieldName = field['fieldname'] ?? '';
      if (_convertToBool(field['reqd']) &&
          (formData[fieldName] == null ||
              formData[fieldName].toString().isEmpty)) {
        _showAlertDialog(
            'Please fill ${field['label'] ?? fieldName} - it\'s a required field.');
        return;
      }
    }

    String apiUrl = '${widget.baseUrl}/api/resource/${widget.doctype}';
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      http.Response response;
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token,
      };
      final body = jsonEncode(formData);

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitting...'),
          duration: Duration(seconds: 10),
        ),
      );

      if (widget.docname.isNotEmpty) {
        response = await http
            .put(
              Uri.parse('$apiUrl/${widget.docname}'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10));
      } else {
        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10));
      }

      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Log the response for debugging
      developer.log('Response Status: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        String successMessage =
            responseData['message'] ?? 'Data saved successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2), // Short duration before pop
          ),
        );
        developer.log('Submission successful: $successMessage');

        // Delay slightly to show the success message, then navigate back
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      } else {
        // Extract and throw the exact error message
        String errorMessage = _extractFrappeError(response.body);
        throw Exception(errorMessage);
      }
    } on FormatException catch (e) {
      developer.log('JSON parsing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid response format from server.'),
          backgroundColor: Colors.red,
        ),
      );
    } on SocketException catch (e) {
      developer.log('Network error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.red,
        ),
      );
    } on TimeoutException catch (e) {
      developer.log('Timeout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      developer.log('Submission error: $e');
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Helper method to extract exact Frappe error messages
  String _extractFrappeError(String responseBody) {
    try {
      final responseData = jsonDecode(responseBody);

      // 1. Check _server_messages (most common for user-facing errors)
      if (responseData['_server_messages'] != null) {
        try {
          final serverMessages = jsonDecode(responseData['_server_messages']);
          if (serverMessages is List && serverMessages.isNotEmpty) {
            return serverMessages[0]['message'] ?? 'Unknown server error';
          }
        } catch (e) {
          developer.log('Failed to parse _server_messages: $e');
          return responseData['_server_messages'].toString();
        }
      }

      // 2. Check exc or exception (detailed error traces)
      if (responseData['exc'] != null) {
        final exc = responseData['exc'];
        if (exc is List && exc.isNotEmpty) {
          // Extract the meaningful part of the exception
          String excString = exc[0].toString();
          List<String> lines = excString.split('\n');
          for (String line in lines) {
            if (line.contains('ValueError') ||
                line.contains('ValidationError')) {
              return line.trim();
            }
          }
          return lines[0]; // Fallback to first line
        } else if (exc is String) {
          return exc.split('\n')[0];
        }
      }

      // 3. Check exception and message pair
      if (responseData['exception'] != null) {
        String excType = responseData['exception'];
        String msg = responseData['message'] ?? '';
        return '$excType: $msg'.trim();
      }

      // 4. Check error field
      if (responseData['error'] != null) {
        return responseData['error'];
      }

      // 5. Check message field (generic)
      if (responseData['message'] != null) {
        return responseData['message'];
      }

      // 6. Fallback to raw body if nothing specific found
      return responseBody.isNotEmpty ? responseBody : 'Unknown error occurred';
    } catch (e) {
      developer.log('Error parsing Frappe response: $e');
      return 'Failed to parse error: $responseBody';
    }
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String statusText = '';
    Color statusColor = Colors.grey;

    if (widget.docname.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'New ${widget.doctype}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.white,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Building form with idx order and collapsible sections
                      ...(() {
                        List<Widget> formWidgets = [];
                        List<Widget> currentSectionFields = [];
                        List<List<Widget>> currentColumns = [];
                        List<Widget> currentColumnFields = [];
                        bool inCollapsibleSection = false;

                        for (int i = 0; i < fields.length; i++) {
                          var field = fields[i];
                          String fieldType = field['fieldtype'] ?? '';
                          bool collapsible =
                              _convertToBool(field['collapsible']);

                          if (fieldType == 'Section Break') {
                            // Finalize any ongoing column
                            if (currentColumnFields.isNotEmpty) {
                              currentColumns.add(currentColumnFields);
                              currentColumnFields = [];
                            }
                            // Finalize prior section or columns
                            if (currentColumns.isNotEmpty) {
                              currentSectionFields.add(
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: currentColumns
                                      .map((col) => Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: col,
                                            ),
                                          ))
                                      .toList(),
                                ),
                              );
                              currentColumns = [];
                            }
                            // Add the prior section to formWidgets
                            if (currentSectionFields.isNotEmpty) {
                              if (inCollapsibleSection) {
                                formWidgets.last = ExpansionTile(
                                  title: Text(
                                    fields[i - currentSectionFields.length - 1]
                                            ['label'] ??
                                        '',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  initiallyExpanded: true,
                                  children: currentSectionFields,
                                );
                              } else {
                                formWidgets.addAll(currentSectionFields);
                              }
                              currentSectionFields = [];
                            }
                            // Start new section
                            inCollapsibleSection = collapsible;
                            formWidgets.add(
                              collapsible
                                  ? ExpansionTile(
                                      title: Text(
                                        field['label'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      children: [], // Will be updated later
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (field['label'] != null &&
                                            field['label'].isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              field['label'],
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        const Divider(),
                                      ],
                                    ),
                            );
                          } else if (fieldType == 'Column Break') {
                            if (currentColumnFields.isNotEmpty) {
                              currentColumns.add(currentColumnFields);
                              currentColumnFields = [];
                            }
                          } else {
                            Widget fieldWidget = _buildField(field);
                            if (fieldWidget is! SizedBox ||
                                (fieldWidget as SizedBox).height != null) {
                              currentColumnFields.add(fieldWidget);
                            }
                          }
                        }

                        // Finalize any remaining column
                        if (currentColumnFields.isNotEmpty) {
                          currentColumns.add(currentColumnFields);
                        }
                        // Finalize any remaining section
                        if (currentColumns.isNotEmpty) {
                          currentSectionFields.add(
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: currentColumns
                                  .map((col) => Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: col,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          );
                        }
                        if (currentSectionFields.isNotEmpty) {
                          if (inCollapsibleSection) {
                            formWidgets.last = ExpansionTile(
                              title: Text(
                                fields[fields.length -
                                        currentSectionFields.length -
                                        1]['label'] ??
                                    '',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              initiallyExpanded: true,
                              children: currentSectionFields,
                            );
                          } else {
                            formWidgets.addAll(currentSectionFields);
                          }
                        }

                        return formWidgets;
                      })(),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text('Save',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
      );
    } else {
      final Map<String, Color> styleColors = {
        'Success': Colors.green, // Green
        'Danger': Colors.red, // Red
        'Inverse': Colors.black, // Black
        'Primary': Colors.blue[800]!, // Dark Blue
        'Info': Colors.lightBlue, // Light Blue
        'Warning': Colors.orange, // Orange
      };

      // if (cur_frm['docs'][0].containsKey('workflow_state') &&
      //     cur_frm['docs'][0]['workflow_state'] != null) {
      //   statusText = cur_frm['docs'][0]['workflow_state'];
      //   // Find the corresponding color for the workflow state
      //   for (var state in metaData['docs'][0]['__workflow_docs'] as List) {
      //     if (state['name'] == statusText) {
      //       statusColor = state['style'] ?? Colors.grey;
      //       break;
      //     }
      //   }
      if (cur_frm['docs'][0].containsKey('workflow_state') &&
          cur_frm['docs'][0]['workflow_state'] != null) {
        statusText = cur_frm['docs'][0]['workflow_state'];
        // Find the corresponding color for the workflow state
        for (var state in metaData['docs'][0]['__workflow_docs'] as List) {
          if (state['name'] == statusText) {
            String style = state['style'];
            statusColor = styleColors[style] ??
                Colors.grey; // Default to grey if not found
            break;
          }
        }
      } else {
        // Check docstatus
        int docStatus = cur_frm['docs'][0]['docstatus'];
        switch (docStatus) {
          case 0:
            statusText = 'Draft';
            statusColor = styleColors['Success']!; // Green
            break;
          case 1:
            statusText = 'Submitted';
            statusColor = styleColors['Success']!; // Orange
            break;
          case 2:
            statusText = 'Cancelled';
            statusColor = styleColors['Danger']!; // Red
            break;
          default:
            statusText = 'Unknown';
            statusColor = Colors.grey; // Inverse
        }
      }
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctype,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            margin: EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: statusColor, // Default to grey if null
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                          Text(
                            widget.docname,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.print, color: Colors.black),
                      tooltip: 'Print',
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            backgroundColor: Colors.white,
                            content: Row(
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black), // Black loading indicator
                                ),
                                SizedBox(width: 16),
                                Text('Loading PDF...'),
                              ],
                            ),
                          ),
                        );
                        try {
                          final pdfUrl =
                              '${widget.baseUrl}/api/method/frappe.utils.print_format.download_pdf'
                              '?doctype=${Uri.encodeComponent(widget.doctype)}'
                              '&name=${Uri.encodeComponent(widget.docname)}'
                              '&format=Standard'
                              '&no_letterhead=1'
                              '&letterhead=No'
                              '&trigger_print=1'
                              '&_lang=en'; // <-- Letterhead दिखाने के लिए
                          print('PDF DOWNLOAD URL: $pdfUrl'); // Debug
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String? token = prefs.getString('token');
                          final response = await http.get(
                            Uri.parse(pdfUrl),
                            headers: {
                              'Authorization': token ?? '',
                            },
                          );
                          final contentType =
                              response.headers['content-type'] ?? '';
                          print('PDF Response Status: ${response.statusCode}');
                          print('PDF Response Headers: ${response.headers}');
                          if (response.statusCode == 200 &&
                              contentType.contains('application/pdf')) {
                            print(
                                'PDF Response Body Length: ${response.bodyBytes.length}');
                            // Save PDF to temp file
                            final dir = await getTemporaryDirectory();
                            final file = File('${dir.path}/print_preview.pdf');
                            await file.writeAsBytes(response.bodyBytes);
                            Navigator.of(context, rootNavigator: true)
                                .pop(); // Close loader
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  backgroundColor:
                                      Colors.black, // Modal background black
                                  appBar: AppBar(title: Text('Print Preview')),
                                  body: Container(
                                    color: Colors.black,
                                    child: SfPdfViewer.file(
                                      file,
                                      canShowScrollHead: true,
                                      canShowScrollStatus: true,
                                    ),
                                  ),
                                  floatingActionButton: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      FloatingActionButton.extended(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        icon: Icon(Icons.save),
                                        label: Text('Save'),
                                        onPressed: () async {
                                          try {
                                            String? outputPath;
                                            final result = await FilePicker
                                                .platform
                                                .saveFile(
                                              dialogTitle: 'Save PDF As',
                                              fileName:
                                                  'print_preview_${DateTime.now().millisecondsSinceEpoch}.pdf',
                                              type: FileType.custom,
                                              allowedExtensions: ['pdf'],
                                            );
                                            outputPath = result;
                                            if (outputPath != null) {
                                              await file.copy(outputPath);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'PDF saved to: $outputPath')),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Save cancelled.')),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to save PDF: $e'),
                                                  backgroundColor: Colors.red),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      FloatingActionButton.extended(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        icon: Icon(Icons.share),
                                        label: Text('Share'),
                                        onPressed: () async {
                                          try {
                                            await Share.shareXFiles(
                                                [XFile(file.path)],
                                                text: 'PDF Document');
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to share PDF: $e'),
                                                  backgroundColor: Colors.red),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      FloatingActionButton.extended(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        icon: const Icon(Icons.download),
                                        label: const Text(''),
                                        onPressed: () async {
                                          try {
                                            Directory? downloadsDir;
                                            if (Platform.isAndroid ||
                                                Platform.isIOS) {
                                              downloadsDir =
                                                  await getExternalStorageDirectory();
                                              if (Platform.isAndroid) {
                                                downloadsDir = Directory(
                                                    '/storage/emulated/0/Download');
                                              }
                                            } else if (Platform.isWindows ||
                                                Platform.isLinux ||
                                                Platform.isMacOS) {
                                              downloadsDir =
                                                  await getDownloadsDirectory();
                                            }
                                            if (downloadsDir == null) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Downloads folder not found!'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            final outputPath =
                                                '${downloadsDir.path}/print_preview_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                            await file.copy(outputPath);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'PDF saved to Downloads: $outputPath'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Failed to save to Downloads: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            print('PDF Response Body (Error/HTML):');
                            print(response.body);
                            Navigator.of(context, rootNavigator: true)
                                .pop(); // Close loader
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to load PDF: ${response.statusCode}\nContent-Type: $contentType'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          print('PDF Download Error: $e');
                          Navigator.of(context, rootNavigator: true)
                              .pop(); // Close loader
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.black),
                      color: Colors.white, // Set background color to white
                      onSelected: (String value) async {
                        if (value == 'edit') {
                          // Show confirmation dialog for edit
                          bool? confirmEdit = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text('Confirm Edit'),
                                content: Text(
                                    'Are you sure you want to edit this document?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text('Cancel',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text('Edit',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmEdit == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Edit selected')),
                            );
                            // Add your edit logic here
                          }
                        } else if (value == 'delete') {
                          // Show confirmation dialog for delete
                          bool? confirmDelete = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text('Confirm Delete'),
                                content: Text(
                                    'Are you sure you want to delete this document? This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text('Cancel',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text('Delete',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmDelete == true) {
                            _fetchWorkflowTransitions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete selected')),
                            );
                            // Add your delete logic here
                          }
                        } else {
                          // Show confirmation dialog for workflow actions
                          bool? confirmWorkflow = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: Colors.white,
                                title: Text('Confirm Action'),
                                content: Text(
                                    'Are you sure you want to perform "$value" action?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text('Cancel',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text('Confirm',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmWorkflow == true) {
                            _performWorkflowAction(value);
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        List<PopupMenuEntry<String>> items = [];

                        if (isdirtyform == false) {
                          // Add workflow actions
                          items.addAll(_workflowActions.map((action) {
                            return PopupMenuItem<String>(
                              value: action['action'],
                              child: Text(
                                action['action'],
                                style: TextStyle(
                                    color: Colors.black), // Black text color
                              ),
                            );
                          }).toList());

                          // Add a divider if there are any workflow actions
                          if (_workflowActions.isNotEmpty) {
                            items.add(const PopupMenuDivider());
                          }
                        }
                        // Add static actions
                        items.add(
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                  color: Colors.black), // Black text color
                            ),
                          ),
                        );
                        items.add(
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                  color: Colors.black), // Black text color
                            ),
                          ),
                        );

                        return items;
                      },
                    ),
                  ],
                ),
              ],
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Form'),
                Tab(text: 'Comments'),
                Tab(text: 'Share'),
                Tab(text: 'Connections'),
              ],
            ),
          ),
          backgroundColor: Color(0xFFF8FAFC),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...(() {
                              List<Widget> formWidgets = [];
                              List<Widget> currentSectionFields = [];
                              List<List<Widget>> currentColumns = [];
                              List<Widget> currentColumnFields = [];
                              bool inCollapsibleSection = false;

                              for (int i = 0; i < fields.length; i++) {
                                var field = fields[i];
                                String fieldType = field['fieldtype'] ?? '';
                                bool collapsible =
                                    _convertToBool(field['collapsible']);

                                if (fieldType == 'Section Break') {
                                  if (currentColumnFields.isNotEmpty) {
                                    currentColumns.add(currentColumnFields);
                                    currentColumnFields = [];
                                  }
                                  if (currentColumns.isNotEmpty) {
                                    currentSectionFields.add(
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: currentColumns
                                            .map((col) => Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: col,
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    );
                                    currentColumns = [];
                                  }
                                  if (currentSectionFields.isNotEmpty) {
                                    if (inCollapsibleSection) {
                                      formWidgets.last = ExpansionTile(
                                        title: Text(
                                          fields[i -
                                                  currentSectionFields.length -
                                                  1]['label'] ??
                                              '',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        initiallyExpanded: true,
                                        children: currentSectionFields,
                                      );
                                    } else {
                                      formWidgets.addAll(currentSectionFields);
                                    }
                                    currentSectionFields = [];
                                  }
                                  inCollapsibleSection = collapsible;
                                  formWidgets.add(
                                    collapsible
                                        ? ExpansionTile(
                                            title: Text(
                                              field['label'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            children: [],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (field['label'] != null &&
                                                  field['label'].isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: Text(
                                                    field['label'],
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              const Divider(),
                                            ],
                                          ),
                                  );
                                } else if (fieldType == 'Column Break') {
                                  if (currentColumnFields.isNotEmpty) {
                                    currentColumns.add(currentColumnFields);
                                    currentColumnFields = [];
                                  }
                                } else {
                                  Widget fieldWidget = _buildField(field);
                                  if (fieldWidget is! SizedBox ||
                                      (fieldWidget as SizedBox).height !=
                                          null) {
                                    currentColumnFields.add(fieldWidget);
                                  }
                                }
                              }

                              if (currentColumnFields.isNotEmpty) {
                                currentColumns.add(currentColumnFields);
                              }
                              if (currentColumns.isNotEmpty) {
                                currentSectionFields.add(
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: currentColumns
                                        .map((col) => Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: col,
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                );
                              }
                              if (currentSectionFields.isNotEmpty) {
                                if (inCollapsibleSection) {
                                  formWidgets.last = ExpansionTile(
                                    title: Text(
                                      fields[fields.length -
                                          currentSectionFields.length -
                                          1]['label'],
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    initiallyExpanded: true,
                                    children: currentSectionFields,
                                  );
                                } else {
                                  formWidgets.addAll(currentSectionFields);
                                }
                              }

                              return formWidgets;
                            })(),
                            const SizedBox(height: 10),
                            (_workflowActions.isNotEmpty &&
                                    isdirtyform == false)
                                ? SizedBox.shrink()
                                : SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        print(formData);
                                        _submit();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: updateAble
                                          ? const Text('Update Now',
                                              style: TextStyle(fontSize: 14))
                                          : (formData['docstatus'] == 0
                                              ? const Text('Submit',
                                                  style:
                                                      TextStyle(fontSize: 14))
                                              : const Text('Save',
                                                  style:
                                                      TextStyle(fontSize: 14))),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                          child: TabContent2(
                              doctype: widget.doctype,
                              docname: widget.docname,
                              baseUrl: widget.baseUrl,
                              cur_frm: cur_frm)),
                      SingleChildScrollView(
                          child: TabContent3(
                              doctype: widget.doctype,
                              docname: widget.docname,
                              baseUrl: widget.baseUrl,
                              cur_frm: cur_frm)),
                      SingleChildScrollView(
                          child: TabContent4(
                              doctype: widget.doctype,
                              docname: widget.docname,
                              baseUrl: widget.baseUrl,
                              cur_frm: cur_frm,
                              metaData: metaData)),
                    ],
                  ),
                ),
        ),
      );
    }
  }
}

class LinkField extends StatefulWidget {
  final String fieldLabel;
  final String fieldName;
  final String linkDoctype;
  final Future<List<dynamic>> Function(String, String) fetchLinkOptions;
  final Map<String, dynamic> formData;
  final Function(String?) onValueChanged;
  final bool readOnly;

  const LinkField({
    required this.fieldLabel,
    required this.fieldName,
    required this.linkDoctype,
    required this.fetchLinkOptions,
    required this.formData,
    required this.onValueChanged,
    required this.readOnly,
    Key? key,
  }) : super(key: key);

  @override
  _LinkFieldState createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  String? _selectedValue;
  List<dynamic> _options = [];
  List<dynamic> _filteredOptions = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.formData[widget.fieldName]?.toString();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    setState(() => _isLoading = true);
    try {
      _options =
          await widget.fetchLinkOptions(widget.linkDoctype, _searchQuery);
      if (mounted) {
        setState(() {
          _filteredOptions = _options;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log("Error fetching link options for ${widget.fieldName}: $e");
      if (mounted) {
        setState(() {
          _filteredOptions = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: GestureDetector(
        onTap: widget.readOnly
            ? null
            : () async {
                await _fetchOptions();
                if (!mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setModalState) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Select ${widget.fieldLabel}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              onChanged: (query) async {
                                setModalState(() {
                                  _searchQuery = query;
                                  _isLoading = true;
                                });
                                final newOptions =
                                    await widget.fetchLinkOptions(
                                        widget.linkDoctype, query);
                                if (mounted) {
                                  setModalState(() {
                                    _options = newOptions;
                                    _filteredOptions = newOptions;
                                    _isLoading = false;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Search',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _filteredOptions.isEmpty
                                    ? const Center(
                                        child: Text("No options available",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)))
                                    : ListView.builder(
                                        itemCount: _filteredOptions.length,
                                        itemBuilder: (context, index) {
                                          final option =
                                              _filteredOptions[index];
                                          return ListTile(
                                            title: Text(
                                              option['value']?.toString() ?? '',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedValue ==
                                                        option['value']
                                                    ? Colors.blue
                                                    : Colors.black,
                                              ),
                                            ),
                                            subtitle:
                                                option['description'] != null
                                                    ? Text(
                                                        option['description']
                                                            .toString(),
                                                        style: const TextStyle(
                                                            fontSize: 12))
                                                    : null,
                                            onTap: () {
                                              final selected =
                                                  option['value']?.toString();
                                              if (selected != null) {
                                                setState(() {
                                                  _selectedValue = selected;
                                                  widget.formData[
                                                          widget.fieldName] =
                                                      _selectedValue;
                                                  widget.onValueChanged(
                                                      _selectedValue);
                                                });
                                                Navigator.pop(context);
                                              }
                                            },
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelStyle: const TextStyle(
                fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
            labelText: '${widget.fieldLabel}',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey[300] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Text(
                  _selectedValue ??
                      widget.formData[widget.fieldName] ??
                      'Select ${widget.fieldLabel}',
                  style: TextStyle(
                      fontSize: 14,
                      color:
                          _selectedValue == null ? Colors.grey : Colors.black),
                ),
        ),
      ),
    );
  }
}

class MultiSelectField extends StatefulWidget {
  final String fieldLabel;
  final String fieldName;
  final String linkDoctype;
  final Future<List<dynamic>> Function(String, String) fetchLinkOptions;
  final Map<String, dynamic> formData;
  final Function(List<String>) onValueChanged;

  const MultiSelectField({
    required this.fieldLabel,
    required this.fieldName,
    required this.linkDoctype,
    required this.fetchLinkOptions,
    required this.formData,
    required this.onValueChanged,
    Key? key,
  }) : super(key: key);

  @override
  _MultiSelectFieldState createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<MultiSelectField> {
  List<String> _selectedValues = [];
  List<dynamic> _options = [];
  List<dynamic> _filteredOptions = [];
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedValues =
        List<String>.from(widget.formData[widget.fieldName] ?? []);
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    setState(() => _isLoading = true);
    try {
      _options =
          await widget.fetchLinkOptions(widget.linkDoctype, _searchQuery);
      if (mounted) {
        setState(() {
          _filteredOptions = _options;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log("Error fetching options for ${widget.fieldName}: $e");
      if (mounted) {
        setState(() {
          _filteredOptions = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: GestureDetector(
            onTap: () async {
              await _fetchOptions();
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                builder: (context) => StatefulBuilder(
                  builder: (context, setModalState) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Select ${widget.fieldLabel}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            onChanged: (query) async {
                              setModalState(() {
                                _searchQuery = query;
                                _isLoading = true;
                              });
                              final newOptions = await widget.fetchLinkOptions(
                                  widget.linkDoctype, query);
                              if (mounted) {
                                setModalState(() {
                                  _options = newOptions;
                                  _filteredOptions = newOptions;
                                  _isLoading = false;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Search',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _filteredOptions.isEmpty
                                  ? const Center(
                                      child: Text("No options available",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: _filteredOptions.length,
                                      itemBuilder: (context, index) {
                                        final option = _filteredOptions[index];
                                        final value =
                                            option['value']?.toString() ?? '';
                                        final isSelected =
                                            _selectedValues.contains(value);
                                        return CheckboxListTile(
                                          title: Text(
                                            value,
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                          subtitle:
                                              option['description'] != null
                                                  ? Text(
                                                      option['description']
                                                          .toString(),
                                                      style: const TextStyle(
                                                          fontSize: 12))
                                                  : null,
                                          value: isSelected,
                                          onChanged: (checked) {
                                            setModalState(() {
                                              if (checked == true) {
                                                _selectedValues.add(value);
                                              } else {
                                                _selectedValues.remove(value);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                widget.formData[widget.fieldName] =
                                    _selectedValues;
                                widget.onValueChanged(_selectedValues);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Save',
                                style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelStyle: const TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
                labelText: '${widget.fieldLabel}',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              child: Text(
                _selectedValues.isEmpty
                    ? 'Select ${widget.fieldLabel}'
                    : _selectedValues.join(', '),
                style: TextStyle(
                    fontSize: 14,
                    color:
                        _selectedValues.isEmpty ? Colors.grey : Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

      var uri = Uri.parse('http://localhost:8000/api/method/upload_file');
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
        String fileUrl = 'http://localhost:8000${attachment['file_url']}';
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
        Uri.parse("http://localhost:8000/api/method/share_remove"),
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
            'http://localhost:8000/api/method/remove_assignment?name=${assignment['name']}'),
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
  final dynamic metaData;

  TabContent4({
    required this.doctype,
    required this.docname,
    required this.baseUrl,
    required this.cur_frm,
    required this.metaData,
  });

  @override
  _TabContent4State createState() => _TabContent4State();
}

class _TabContent4State extends State<TabContent4> {
  int? externalLinksCount;
  int? internalLinksCount;
  String? errorMessage;
  List<dynamic> externalLinks = [];
  List<Map<String, dynamic>> dashboardConnections = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await Future.wait<void>([
        initializeDashboardConnections(),
        fetchOpenCount(),
      ]);

      await fetchPermissionsForDoctypes();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Initialize dashboard connections using the provided JSON data
  Future<void> initializeDashboardConnections() async {
    try {
      if (widget.metaData != null &&
          widget.metaData['docs'] != null &&
          widget.metaData['docs'].isNotEmpty &&
          widget.metaData['docs'][0]['__dashboard'] != null) {
        final data = widget.metaData['docs'][0]['__dashboard'];

        if (data['transactions'] != null) {
          setState(() {
            dashboardConnections = (data['transactions'] as List)
                .map((category) => {
                      'category': category['label'] ?? 'Unknown Category',
                      'doctypes': (category['items'] as List?)
                              ?.map((doctype) => {'name': doctype, 'count': 0})
                              .toList() ??
                          [],
                    })
                .toList();
          });
        }
      }
    } catch (e) {
      developer.log('Error initializing dashboard connections: $e');
      setState(() {
        dashboardConnections = [];
      });
    }
  }

  Future<void> fetchOpenCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final url =
          '${widget.baseUrl}/api/method/frappe.desk.notifications.get_open_count?doctype=${widget.doctype}&name=${widget.docname}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['message'] != null && data['message']['count'] != null) {
          final countData = data['message']['count'];

          setState(() {
            if (countData['external_links_found'] != null) {
              externalLinks = countData['external_links_found'];
              externalLinksCount = externalLinks.fold<int>(
                  0, (sum, link) => sum + (link['open_count'] as int? ?? 0));
            } else {
              externalLinks = [];
              externalLinksCount = 0;
            }

            internalLinksCount = countData['internal_links_found']?.length ?? 0;
            errorMessage = null;

            // Update counts in dashboardConnections
            if (externalLinks.isNotEmpty) {
              for (var link in externalLinks) {
                for (var category in dashboardConnections) {
                  for (var doctype in category['doctypes']) {
                    if (doctype['name'] == link['doctype']) {
                      doctype['count'] = link['open_count'] ?? 0;
                    }
                  }
                }
              }
            }
          });
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied: You don\'t have permission to view this data');
      } else if (response.statusCode == 404) {
        throw Exception('Data not found');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      setState(() {
        errorMessage = 'Request timed out. Please check your connection.';
      });
    } on SocketException {
      setState(() {
        errorMessage = 'No internet connection. Please check your network.';
      });
    } catch (e) {
      setState(() {
        errorMessage =
            'Failed to load connections: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  // Fetch permissions for all doctypes dynamically
  Future<void> fetchPermissionsForDoctypes() async {
    if (externalLinks.isEmpty) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      for (var link in externalLinks) {
        final url =
            '${widget.baseUrl}/api/method/check_doctype_permissions?doctype=${link['doctype']}';

        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': '$token',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            setState(() {
              link['has_create_permission'] = data['status'] ?? false;
            });
          } else {
            setState(() {
              link['has_create_permission'] = false;
            });
          }
        } catch (e) {
          developer
              .log('Error fetching permissions for ${link['doctype']}: $e');
          setState(() {
            link['has_create_permission'] = false;
          });
        }
      }
    } catch (e) {
      developer.log('Error in fetchPermissionsForDoctypes: $e');
    }
  }

  void function01(String doctype) {
    try {
      if (widget.metaData == null ||
          widget.metaData['docs'] == null ||
          widget.metaData['docs'].isEmpty ||
          widget.metaData['docs'][0]['__dashboard'] == null) {
        throw Exception('Dashboard data not available');
      }

      var data = widget.metaData['docs'][0]['__dashboard'];
      List<List<dynamic>> prefilters = [];
      String? linkingField;

      // Check non_standard_fieldnames for the doctype
      if (data['non_standard_fieldnames'] != null) {
        linkingField = data['non_standard_fieldnames'][doctype];
      }

      if (linkingField != null && widget.docname.isNotEmpty) {
        prefilters.add([linkingField, '=', widget.docname]);
      } else if (data['internal_links'] != null) {
        // Check internal_links for the doctype
        final internalLink = data['internal_links'][doctype];
        if (internalLink != null &&
            internalLink.length > 1 &&
            widget.docname.isNotEmpty) {
          prefilters.add([internalLink[1], '=', widget.docname]);
        } else if (data['fieldname'] != null) {
          // Default filter if no specific link is found
          prefilters.add([data['fieldname'], '=', widget.docname]);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctypeListView(
            doctype: doctype,
            prefilters: prefilters,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error navigating to $doctype: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void function02(String doctype) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FrappeCrudForm(
            doctype: doctype,
            docname: '',
            baseUrl: widget.baseUrl,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error creating new $doctype: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $errorMessage',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (externalLinks.isNotEmpty) ...[
                        ...externalLinks.map<Widget>((link) {
                          return Container(
                            margin: const EdgeInsets.all(5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  onPressed: () => function01(link['doctype']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                      '${link['doctype']}: Count: ${link['open_count']}'),
                                ),
                                if (link['has_create_permission'] ?? false)
                                  ElevatedButton(
                                    onPressed: () =>
                                        function02(link['doctype']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Add'),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ] else ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No connections found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
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
          'http://localhost:8000/api/method/frappe.desk.search.search_link?doctype=User&txt=$query',
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
        Uri.parse("http://localhost:8000/api/method/frappe.share.add"),
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
            'http://localhost:8000/api/method/frappe.desk.search.search_link?doctype=User&txt=$query'),
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
            "http://localhost:8000/api/method/frappe.desk.form.assign_to.add"),
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

// Widget for Google Maps (unchanged)
class _GoogleMapWidget extends StatefulWidget {
  final gmaps.LatLng? initialPoint;
  final Function(gmaps.LatLng) onPointSelected;
  final bool readOnly;

  const _GoogleMapWidget({
    this.initialPoint,
    required this.onPointSelected,
    required this.readOnly,
  });

  @override
  State<_GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<_GoogleMapWidget> {
  gmaps.GoogleMapController? _controller;
  gmaps.LatLng? _markerPoint;

  @override
  void initState() {
    super.initState();
    _markerPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _markerPoint ?? const gmaps.LatLng(51.509364, -0.128928),
        zoom: 13.0,
      ),
      markers: _markerPoint != null
          ? {
              gmaps.Marker(
                markerId: const gmaps.MarkerId('selectedPoint'),
                position: _markerPoint!,
              ),
            }
          : {},
      onMapCreated: (controller) {
        _controller = controller;
      },
      onTap: widget.readOnly
          ? null
          : (point) {
              setState(() {
                _markerPoint = point;
                widget.onPointSelected(point);
              });
            },
    );
  }
}

// Full-screen Google Maps dialog (unchanged)
class _GoogleMapDialog extends StatefulWidget {
  final gmaps.LatLng? initialPoint;

  const _GoogleMapDialog({this.initialPoint});

  @override
  State<_GoogleMapDialog> createState() => _GoogleMapDialogState();
}

class _GoogleMapDialogState extends State<_GoogleMapDialog> {
  gmaps.GoogleMapController? _controller;
  gmaps.LatLng? _markerPoint;

  @override
  void initState() {
    super.initState();
    _markerPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Location'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, _markerPoint);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: _markerPoint ?? const gmaps.LatLng(51.509364, -0.128928),
            zoom: 13.0,
          ),
          markers: _markerPoint != null
              ? {
                  gmaps.Marker(
                    markerId: const gmaps.MarkerId('selectedPoint'),
                    position: _markerPoint!,
                  ),
                }
              : {},
          onMapCreated: (controller) {
            _controller = controller;
          },
          onTap: (point) {
            setState(() {
              _markerPoint = point;
            });
          },
        ),
      ),
    );
  }
}

// Full-screen Leaflet-style map dialog (corrected Marker)
class _LeafletMapDialog extends StatefulWidget {
  final LatLng? initialPoint;

  const _LeafletMapDialog({this.initialPoint});

  @override
  State<_LeafletMapDialog> createState() => _LeafletMapDialogState();
}

class _LeafletMapDialogState extends State<_LeafletMapDialog> {
  LatLng? markerPoint;

  @override
  void initState() {
    super.initState();
    markerPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Location'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, markerPoint);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: FlutterMap(
          options: MapOptions(
            initialCenter: markerPoint ?? const LatLng(51.509364, -0.128928),
            initialZoom: 13.0,
            onTap: (tapPosition, point) {
              setState(() {
                markerPoint = point;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            if (markerPoint != null)
              MarkerLayer(
                markers: [
                  fmap.Marker(
                    width: 40.0,
                    height: 40.0,
                    point: markerPoint!,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40.0,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
