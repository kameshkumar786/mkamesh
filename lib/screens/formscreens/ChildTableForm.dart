import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'package:signature/signature.dart';

class ChildTableForm extends StatefulWidget {
  final String doctype;
  final String baseUrl;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const ChildTableForm({
    required this.doctype,
    required this.baseUrl,
    this.initialData,
    required this.onSave,
  });

  @override
  _ChildTableFormState createState() => _ChildTableFormState();
}

class _ChildTableFormState extends State<ChildTableForm> {
  List<Map<String, dynamic>> fields = [];
  Map<String, dynamic> rowData = {};
  Map<String, TextEditingController> controllers = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChildTableFields();
    if (widget.initialData != null) {
      rowData = Map.from(widget.initialData!);
    }
  }

  Future<void> fetchChildTableFields() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.form.load.getdoctype?doctype=${widget.doctype}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          fields = List<Map<String, dynamic>>.from(data['docs'][0]['fields']);
          fields.sort((a, b) => (a['idx'] ?? 0).compareTo(b['idx'] ?? 0));
          for (var field in fields) {
            String fieldName = field['fieldname'] ?? '';
            if (field['fieldtype'] != 'Section Break' &&
                field['fieldtype'] != 'Column Break') {
              rowData[fieldName] ??= null;
              controllers[fieldName] = TextEditingController(
                  text: rowData[fieldName]?.toString() ?? '');
            }
          }
          isLoading = false;
        });
        _updateDependentFields();
      } else {
        throw Exception('Failed to load child table fields: ${response.body}');
      }
    } catch (e) {
      developer.log("Error fetching child table fields: $e");
      setState(() => isLoading = false);
    }
  }

  void _saveRow() {
    for (var field in fields) {
      String fieldName = field['fieldname'] ?? '';
      if (_convertToBool(field['reqd']) &&
          field['fieldtype'] != 'Section Break' &&
          field['fieldtype'] != 'Column Break' &&
          (rowData[fieldName] == null ||
              rowData[fieldName].toString().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${field['label'] ?? fieldName} is required')));
        return;
      }
    }
    widget.onSave(rowData);
    Navigator.pop(context);
  }

  bool _convertToBool(dynamic value) => value is bool
      ? value
      : value is int
          ? value == 1
          : false;

  void _updateDependentFields() {
    bool changed = false;
    for (var field in fields) {
      String? dependsOn = field['depends_on'];
      if (dependsOn != null && dependsOn.isNotEmpty) {
        bool isVisible = _evaluateDependsOn(dependsOn);
        if (_convertToBool(field['hidden']) != !isVisible) {
          field['hidden'] = !isVisible;
          changed = true;
          developer
              .log('Field ${field['fieldname']} visibility set to $isVisible');
        }
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _fetchFieldValue(String fieldName, String fetchFrom) async {
    if (fetchFrom.isEmpty || !fetchFrom.contains('.')) return;
    List<String> parts = fetchFrom.split('.');
    if (parts.length != 2) return;

    String sourceField = parts[0];
    String targetField = parts[1];
    String? sourceValue = rowData[sourceField]?.toString();

    if (sourceValue == null || sourceValue.isEmpty) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? linkDoctype =
          fields.firstWhere((f) => f['fieldname'] == sourceField)['options'];

      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/resource/$linkDoctype/$sourceValue'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        String? fetchedValue = data[targetField]?.toString();
        if (fetchedValue != null && fetchedValue != rowData[fieldName]) {
          setState(() {
            rowData[fieldName] = fetchedValue;
            controllers[fieldName]?.text = fetchedValue;
            developer
                .log('Fetched $targetField = $fetchedValue for $fieldName');
          });
          _updateDependentFields();
        }
      } else {
        developer.log('Fetch failed for $fieldName: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching value for $fieldName: $e');
    }
  }

  Widget _buildField(Map<String, dynamic> field) {
    String fieldType = field['fieldtype'] ?? '';
    String fieldName = field['fieldname'] ?? '';
    String? label = field['label'];
    bool readOnly = _convertToBool(field['read_only']);
    bool hidden = _convertToBool(field['hidden']);
    bool required = _convertToBool(field['reqd']);
    String? dependsOn = field['depends_on'];
    String? fetchFrom = field['fetch_from'];

    if (hidden) return const SizedBox.shrink();

    final controller = controllers[fieldName];
    final inputDecoration = InputDecoration(
      labelText: required ? '$label *' : label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: readOnly ? Colors.grey[200] : Colors.white,
    );

    if (fetchFrom != null &&
        fetchFrom.isNotEmpty &&
        rowData[fetchFrom.split('.').first] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchFieldValue(fieldName, fetchFrom);
      });
    }

    switch (fieldType) {
      case 'Section Break':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
            ],
          ),
        );

      case 'Column Break':
        return const SizedBox(width: 8);

      // case 'Data':
      //   return Padding(
      //     padding: const EdgeInsets.all(8.0),
      //     child: TextFormField(
      //       controller: controller,
      //       decoration: inputDecoration,
      //       readOnly: readOnly,
      //       onChanged: (value) {
      //         setState(() {
      //           rowData[fieldName] = value;
      //           _updateDependentFields();
      //           if (fetchFrom != null) _fetchFieldValue(fieldName, fetchFrom);
      //         });
      //       },
      //     ),
      //   );

      case 'Data':
        String? options = field['options']?.toString().toLowerCase();
        Icon? suffixIcon;
        if (options == 'email')
          suffixIcon = const Icon(Icons.email);
        else if (options == 'phone')
          suffixIcon = const Icon(Icons.phone);
        else if (options == 'url') suffixIcon = const Icon(Icons.link);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            decoration: inputDecoration.copyWith(suffixIcon: suffixIcon),
            readOnly: readOnly,
            keyboardType: options == 'email'
                ? TextInputType.emailAddress
                : options == 'phone'
                    ? TextInputType.phone
                    : options == 'url'
                        ? TextInputType.url
                        : TextInputType.text,
            onChanged: (value) => {
              setState(() {
                rowData[fieldName] = value;
                _updateDependentFields();
              })
            },
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Small Text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            maxLines: 1,
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = value;
              _updateDependentFields();
            }),
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Text':
      case 'Text Editor':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            maxLines: fieldType == 'Text Editor' ? 5 : 3,
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = value;
              _updateDependentFields();
            }),
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Int':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = int.tryParse(value) ?? 0;
              _updateDependentFields();
            }),
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Float':
      case 'Currency':
      case 'Rate':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = double.tryParse(value) ?? 0.0;
              _updateDependentFields();
            }),
            validator: required && !readOnly
                ? (value) => value!.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Time':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: rowData[fieldName] != null
                          ? TimeOfDay.fromDateTime(DateTime.parse(
                              '2023-01-01 ${rowData[fieldName]}'))
                          : TimeOfDay.now(),
                    );
                    if (picked != null) {
                      String formattedTime = picked.format(context);
                      setState(() {
                        rowData[fieldName] = formattedTime;
                        controller?.text = formattedTime;
                        _updateDependentFields();
                      });
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.access_time)),
              child: Text(rowData[fieldName]?.toString() ?? 'Select Time'),
            ),
          ),
        );

      case 'Datetime':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: rowData[fieldName] != null
                          ? DateTime.parse(rowData[fieldName])
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
                          rowData[fieldName] = formattedDateTime;
                          controller?.text = formattedDateTime;
                          _updateDependentFields();
                        });
                      }
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.calendar_today)),
              child:
                  Text(rowData[fieldName]?.toString() ?? 'Select Date & Time'),
            ),
          ),
        );

      case 'Rating':
        double ratingValue =
            double.tryParse(rowData[fieldName]?.toString() ?? '0') ?? 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label ?? fieldName,
                  style: const TextStyle(fontSize: 14, color: Colors.black)),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < (ratingValue * 5).round()
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.yellow[700],
                    ),
                    onPressed: readOnly
                        ? null
                        : () {
                            setState(() {
                              double newRating = (index + 1) / 5.0;
                              rowData[fieldName] = newRating;
                              controller?.text = newRating.toStringAsFixed(2);
                              _updateDependentFields();
                            });
                          },
                  );
                }),
              ),
            ],
          ),
        );

      case 'Signature':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label ?? fieldName,
                  style: const TextStyle(fontSize: 14, color: Colors.black)),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    if (rowData[fieldName] != null &&
                        rowData[fieldName].toString().isNotEmpty)
                      Image.memory(
                        base64Decode(
                          (rowData[fieldName] as String)
                                  .startsWith('data:image/png;base64,')
                              ? (rowData[fieldName] as String).substring(22)
                              : rowData[fieldName] as String,
                        ),
                        fit: BoxFit.contain,
                        height: 150,
                        width: double.infinity,
                      )
                    else
                      const Center(
                          child: Text('Tap to sign',
                              style: TextStyle(color: Colors.grey))),
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
                                        backgroundColor: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => sigController.clear(),
                                        child: const Text('Clear')),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
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
                                    rowData[fieldName] = dataUrl;
                                    controller?.text = 'Signed';
                                    _updateDependentFields();
                                  });
                                }
                              }
                              sigController.dispose();
                            },
                    ),
                  ],
                ),
              ),
              if (!readOnly &&
                  rowData[fieldName] != null &&
                  rowData[fieldName].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      rowData[fieldName] = null;
                      controller?.text = '';
                    }),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Clear Signature',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        );

      case 'Percent':
        double percentValue =
            double.tryParse(rowData[fieldName]?.toString() ?? '0') ?? 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: inputDecoration.copyWith(suffixText: '%'),
                readOnly: readOnly,
                onChanged: (value) {
                  setState(() {
                    double? percent = double.tryParse(value);
                    percentValue =
                        percent != null && percent >= 0 && percent <= 100
                            ? percent
                            : 0.0;
                    rowData[fieldName] = percentValue;
                    controller?.text = percentValue.toStringAsFixed(1);

                    _updateDependentFields();
                  });
                },
                validator: required && !readOnly
                    ? (value) => value!.isEmpty ? '$label is required' : null
                    : null,
              ),
              Slider(
                value: percentValue,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${percentValue.toStringAsFixed(1)}%',
                onChanged: readOnly
                    ? null
                    : (newValue) => setState(() {
                          percentValue = newValue;
                          rowData[fieldName] = percentValue;
                          controller?.text = percentValue.toStringAsFixed(1);
                        }),
              ),
            ],
          ),
        );

      case 'Attach':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles();
                        if (result != null) {
                          setState(() {
                            rowData[fieldName] = result.files.single.path;
                            _updateDependentFields();
                          });
                        }
                      },
                child: const Text('Upload File'),
              ),
              if (rowData[fieldName] != null)
                Text('File: ${rowData[fieldName].toString().split('/').last}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );

      case 'Attach Image':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: readOnly
                    ? null
                    : () async {
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (result != null) {
                          setState(() {
                            rowData[fieldName] = result.files.single.path;
                            _updateDependentFields();
                          });
                        }
                      },
                child: const Text('Upload Image'),
              ),
              if (rowData[fieldName] != null)
                Image.file(
                  File(rowData[fieldName]),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('Image preview not available'),
                ),
            ],
          ),
        );

      case 'Image':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rowData[fieldName] != null)
                Image.network(
                  rowData[fieldName],
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('Image preview not available'),
                )
              else
                const Text('No image available',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );

      case 'Select':
        if (field['options'] == null) return const SizedBox.shrink();
        List<String> options = (field['options'] as String)
            .split('\n')
            .where((opt) => opt.isNotEmpty)
            .toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: rowData[fieldName] != null &&
                    options.contains(rowData[fieldName])
                ? rowData[fieldName]
                : null,
            decoration: inputDecoration,
            items: options
                .map((option) =>
                    DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: readOnly
                ? null
                : (value) => setState(() {
                      rowData[fieldName] = value;
                      _updateDependentFields();
                    }),
            validator: required && !readOnly
                ? (value) =>
                    value == null || value.isEmpty ? '$label is required' : null
                : null,
          ),
        );

      case 'Date':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: InkWell(
            onTap: readOnly
                ? null
                : () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: rowData[fieldName] != null
                          ? DateTime.tryParse(rowData[fieldName]) ??
                              DateTime.now()
                          : DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd').format(picked);
                      setState(() {
                        rowData[fieldName] = formattedDate;
                        controller?.text = formattedDate;
                        _updateDependentFields();
                      });
                    }
                  },
            child: InputDecorator(
              decoration: inputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.calendar_today)),
              child: Text(rowData[fieldName]?.toString() ?? 'Select Date'),
            ),
          ),
        );

      case 'Link':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: LinkField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: rowData,
            onValueChanged: (value) => setState(() {
              rowData[fieldName] = value;
              controller?.text = value ?? '';
              _updateDependentFields();
            }),
          ),
        );

      case 'Dynamic Link':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: rowData[field['options']] != null
              ? LinkField(
                  fieldLabel: label ?? '',
                  fieldName: fieldName,
                  linkDoctype: rowData[field['options']] ?? '',
                  fetchLinkOptions: fetchLinkOptions,
                  formData: rowData,
                  onValueChanged: (value) => setState(() {
                    rowData[fieldName] = value;
                    controller?.text = value ?? '';
                    _updateDependentFields();
                  }),
                )
              : const SizedBox.shrink(),
        );

      case 'Check':
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: rowData[fieldName] == 1 || rowData[fieldName] == true,
                onChanged: readOnly
                    ? null
                    : (value) {
                        setState(() {
                          rowData[fieldName] = value == true
                              ? 1
                              : 0; // Frappe uses 1/0 for Check fields
                          _updateDependentFields();
                        });
                      },
              ),
              const SizedBox(width: 8), // Space between checkbox and label
              Flexible(
                child: Text(
                  required ? '$label *' : label ?? fieldName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: readOnly ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'HTML':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: SizedBox(
            height: 200,
            child: TextFormField(
              controller: controller,
              maxLines: null,
              decoration: inputDecoration,
              readOnly: readOnly,
              onChanged: (value) => setState(() {
                rowData[fieldName] = value;
                _updateDependentFields();
                ;
              }),
            ),
          ),
        );

      case 'Password':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = value;
              _updateDependentFields();
            }),
          ),
        );

      case 'Duration':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: TextFormField(
            controller: controller,
            decoration: inputDecoration,
            readOnly: readOnly,
            onChanged: (value) => setState(() {
              rowData[fieldName] = value;
              _updateDependentFields();
            }),
          ),
        );

      case 'Table MultiSelect':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: MultiSelectField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: rowData,
            onValueChanged: (values) => setState(() {
              rowData[fieldName] = values;
              _updateDependentFields();
            }),
          ),
        );

      // case 'Geolocation':
      //   String? options = field['options']?.toString();
      //   bool useGoogleMaps = options == 'Google Maps';
      //   LatLng? leafletPoint;
      //   gmaps.LatLng? googlePoint;
      //   if (rowData[fieldName] != null &&
      //       rowData[fieldName].toString().isNotEmpty) {
      //     try {
      //       Map<String, dynamic> geoData =
      //           jsonDecode(rowData[fieldName] as String);
      //       double lat = double.parse(geoData['latitude'].toString());
      //       double lng = double.parse(geoData['longitude'].toString());
      //       leafletPoint = LatLng(lat, lng);
      //       googlePoint = gmaps.LatLng(lat, lng);
      //     } catch (e) {
      //       developer.log('Error parsing Geolocation data: $e');
      //     }
      //   }

      //   return Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      //     child: Column(
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         Text(label ?? fieldName,
      //             style: const TextStyle(fontSize: 14, color: Colors.black)),
      //         Container(
      //           height: 200,
      //           width: double.infinity,
      //           decoration: BoxDecoration(
      //             border: Border.all(color: Colors.grey),
      //             borderRadius: BorderRadius.circular(8),
      //           ),
      //           child: useGoogleMaps
      //               ? _GoogleMapWidget(
      //                   initialPoint: googlePoint,
      //                   onPointSelected: (point) => setState(() {
      //                     rowData[fieldName] = jsonEncode({
      //                       'latitude': point.latitude,
      //                       'longitude': point.longitude
      //                     });
      //                     controller?.text =
      //                         'Marked at ${point.latitude}, ${point.longitude}';
      //                   }),
      //                   readOnly: readOnly,
      //                 )
      //               : fmap.FlutterMap(
      //                   options: fmap.MapOptions(
      //                     initialCenter: leafletPoint ??
      //                         const LatLng(51.509364, -0.128928),
      //                     initialZoom: 13.0,
      //                     onTap: readOnly
      //                         ? null
      //                         : (tapPosition, point) => setState(() {
      //                               rowData[fieldName] = jsonEncode({
      //                                 'latitude': point.latitude,
      //                                 'longitude': point.longitude
      //                               });
      //                               controller?.text =
      //                                   'Marked at ${point.latitude}, ${point.longitude}';
      //                             }),
      //                   ),
      //                   children: [
      //                     fmap.TileLayer(
      //                       urlTemplate:
      //                           'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      //                       subdomains: const ['a', 'b', 'c'],
      //                     ),
      //                     if (leafletPoint != null)
      //                       fmap.MarkerLayer(
      //                         markers: [
      //                           fmap.Marker(
      //                             width: 40.0,
      //                             height: 40.0,
      //                             point: leafletPoint,
      //                             child: const Icon(Icons.location_pin,
      //                                 color: Colors.red, size: 40.0),
      //                           ),
      //                         ],
      //                       ),
      //                   ],
      //                 ),
      //         ),
      //       ],
      //     ),
      //   );

      // default:
      //   return Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      //     child: Text('Unsupported field type: $fieldType',
      //         style: const TextStyle(fontSize: 12, color: Colors.grey)),
      //   );

      case 'Link':
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: LinkField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: rowData,
            onValueChanged: (value) {
              setState(() {
                rowData[fieldName] = value;
                controller?.text = value ?? '';
                _updateDependentFields();
                for (var dependentField in fields) {
                  if (dependentField['fetch_from']?.startsWith('$fieldName.') ??
                      false) {
                    _fetchFieldValue(dependentField['fieldname'],
                        dependentField['fetch_from']);
                  }
                }
              });
            },
          ),
        );

      case 'Table MultiSelect':
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MultiSelectField(
            fieldLabel: label ?? '',
            fieldName: fieldName,
            linkDoctype: field['options'] ?? '',
            fetchLinkOptions: fetchLinkOptions,
            formData: rowData,
            onValueChanged: (values) {
              setState(() {
                rowData[fieldName] = values;
                _updateDependentFields();
              });
            },
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Unsupported field: $fieldType'),
        );
    }
  }

  List<Widget> _buildFormLayout() {
    List<Widget> sections = [];
    List<Widget> currentSection = [];
    List<List<Widget>> columnGroups = [
      []
    ]; // List of columns within the current section

    for (var field in fields) {
      Widget fieldWidget = _buildField(field);

      if (field['fieldtype'] == 'Section Break') {
        if (columnGroups.isNotEmpty &&
            columnGroups.any((group) => group.isNotEmpty)) {
          currentSection.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnGroups
                .map((group) => Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: group,
                      ),
                    ))
                .toList(),
          ));
          columnGroups = [[]]; // Reset for the next section
        }
        if (currentSection.isNotEmpty) {
          sections.add(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: currentSection,
          ));
          currentSection = [];
        }
        currentSection.add(fieldWidget);
      } else if (field['fieldtype'] == 'Column Break') {
        columnGroups.add([]); // Start a new column group
      } else if (fieldWidget is! SizedBox) {
        columnGroups.last.add(fieldWidget); // Add to the current column group
      }
    }

    // Add the last section’s columns
    if (columnGroups.isNotEmpty &&
        columnGroups.any((group) => group.isNotEmpty)) {
      currentSection.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columnGroups
            .map((group) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: group,
                  ),
                ))
            .toList(),
      ));
    }
    if (currentSection.isNotEmpty) {
      sections.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: currentSection,
      ));
    }

    sections.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: _saveRow,
          child: const Text('Save'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50)),
        ),
      ),
    );

    return sections;
  }
  // List<Widget> _buildFormLayout() {
  //   List<Widget> sections = [];
  //   List<Widget> currentSection = [];
  //   List<Widget> currentRow = [];

  //   for (var field in fields) {
  //     Widget fieldWidget = _buildField(field);

  //     if (field['fieldtype'] == 'Section Break') {
  //       if (currentRow.isNotEmpty) {
  //         currentSection.add(Row(
  //             children: currentRow.map((w) => Expanded(child: w)).toList()));
  //         currentRow = [];
  //       }
  //       if (currentSection.isNotEmpty) {
  //         sections.add(Column(children: currentSection));
  //         currentSection = [];
  //       }
  //       currentSection.add(fieldWidget);
  //     } else if (field['fieldtype'] == 'Column Break') {
  //       if (currentRow.isNotEmpty) {
  //         currentSection.add(Row(
  //             children: currentRow.map((w) => Expanded(child: w)).toList()));
  //         currentRow = [];
  //       }
  //     } else if (fieldWidget is! SizedBox) {
  //       currentRow.add(fieldWidget);
  //     }
  //   }

  //   if (currentRow.isNotEmpty) {
  //     currentSection.add(
  //         Row(children: currentRow.map((w) => Expanded(child: w)).toList()));
  //   }
  //   if (currentSection.isNotEmpty) {
  //     sections.add(Column(children: currentSection));
  //   }

  //   sections.add(
  //     Padding(
  //       padding: const EdgeInsets.all(8.0),
  //       child: ElevatedButton(
  //         onPressed: _saveRow,
  //         child: const Text('Save'),
  //         style: ElevatedButton.styleFrom(
  //             minimumSize: const Size(double.infinity, 50)),
  //       ),
  //     ),
  //   );

  //   return sections;
  // }

  bool _evaluateDependsOn(String condition) {
    if (!condition.startsWith('eval:')) return true;
    String expression = condition.substring(5).trim();
    developer.log('Evaluating depends_on: $expression with rowData: $rowData');

    if (expression.contains('!=')) {
      List<String> parts = expression.split('!=').map((e) => e.trim()).toList();
      if (parts.length == 2 &&
          parts[0].startsWith('doc.') &&
          parts[1].startsWith('doc.')) {
        String field1 = parts[0].substring(4);
        String field2 = parts[1].substring(4);
        var value1 = rowData[field1];
        var value2 = rowData[field2];
        bool result = value1 != value2;
        developer
            .log('Comparing $field1 ($value1) != $field2 ($value2): $result');
        return result;
      }
    } else if (expression.contains('==')) {
      List<String> parts = expression.split('==').map((e) => e.trim()).toList();
      if (parts.length == 2 && parts[0].startsWith('doc.')) {
        String field = parts[0].substring(4);
        String value = parts[1].replaceAll("'", "").replaceAll('"', '');
        var fieldValue = rowData[field]?.toString();
        bool result = fieldValue == value;
        developer.log('Comparing $field ($fieldValue) == $value: $result');
        return result;
      }
    } else if (expression.startsWith('doc.')) {
      String field = expression.substring(4);
      var value = rowData[field];
      bool result = value != null && value.toString().isNotEmpty;
      developer.log('Checking $field exists and non-empty: $result');
      return result;
    }
    developer.log('Defaulting to true for unhandled condition: $expression');
    return true;
  }

  Future<List<dynamic>> fetchLinkOptions(
      String linkDoctype, String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.get(
        Uri.parse(
            '${widget.baseUrl}/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token'
        },
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['message'] ?? [];
      return [];
    } catch (e) {
      developer.log('Error fetching link options: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              '${widget.initialData == null ? 'Add' : 'Edit'} ${widget.doctype} Row')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(children: _buildFormLayout()),
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
                                          fontSize: 12, color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: _filteredOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = _filteredOptions[index];
                                    return ListTile(
                                      title: Text(
                                        option['value']?.toString() ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _selectedValue == option['value']
                                                  ? Colors.blue
                                                  : Colors.black,
                                        ),
                                      ),
                                      subtitle: option['description'] != null
                                          ? Text(
                                              option['description'].toString(),
                                              style:
                                                  const TextStyle(fontSize: 12))
                                          : null,
                                      onTap: () {
                                        final selected =
                                            option['value']?.toString();
                                        if (selected != null) {
                                          setState(() {
                                            _selectedValue = selected;
                                            widget.formData[widget.fieldName] =
                                                _selectedValue;
                                            widget
                                                .onValueChanged(_selectedValue);
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
                fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
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
                    fontSize: 18,
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
