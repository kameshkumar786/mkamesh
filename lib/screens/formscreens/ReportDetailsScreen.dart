import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String report_name;
  const ReportDetailsScreen({
    required this.report_name,
  });

  @override
  _ReportDetailsScreenState createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  List<Map<String, dynamic>> filters = [];
  Map<String, dynamic> filterValues = {};
  Map<String, dynamic> reportData = {};
  String report_name = '';
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    report_name = widget.report_name;
    _fetchFilters();
  }

  Future<void> _fetchFilters() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        throw Exception('No authentication token found. Please log in again.');
      }

      final response = await http
          .post(
        Uri.parse(
            'http://localhost:8000/api/method/frappe.desk.query_report.get_script'),
        headers: {
          'Authorization': '$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'report_name': report_name}),
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out. Check your network connection.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] == null || data['message']['script'] == null) {
          throw Exception('Invalid response format: Script data missing.');
        }
        print('Full API response: $data');
        print('Raw script: ${data['message']['script']}');
        setState(() {
          filters = _parseFilters(data['message']['script']);
          for (var filter in filters) {
            filterValues[filter['fieldname']] = filter['default'] ?? '';
          }
        });
        print('Parsed filters: $filters');
        print('Filter labels: ${filters.map((f) => f['label']).toList()}');
      } else {
        throw Exception(
            'Failed to load filters: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching filters: $e';
      });
      print(errorMessage);
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _parseFilters(String script) {
    List<Map<String, dynamic>> filters = [];
    try {
      // Extract filters array
      RegExp filtersArrayExp = RegExp(
        r'filters\s*:\s*\[(.*?)\]',
        multiLine: true,
        dotAll: true,
      );
      Match? arrayMatch = filtersArrayExp.firstMatch(script);

      if (arrayMatch == null) {
        print('No filters array found in script: $script');
        return filters;
      }

      String filtersContent = arrayMatch.group(1)!.trim();
      if (filtersContent.isEmpty) {
        print('Filters content is empty');
        return filters;
      }

      // Split filters by top-level objects
      List<String> filterStrings = [];
      int braceCount = 0;
      StringBuffer currentFilter = StringBuffer();

      for (var char in filtersContent.runes) {
        currentFilter.write(String.fromCharCode(char));
        if (char == '{'.codeUnitAt(0)) braceCount++;
        if (char == '}'.codeUnitAt(0)) braceCount--;
        if (char == '}'.codeUnitAt(0) && braceCount == 0) {
          String filterStr = currentFilter.toString().trim();
          if (filterStr.isNotEmpty) {
            filterStrings.add(filterStr);
          }
          currentFilter.clear();
        }
      }

      // Parse each filter object
      RegExp fieldExp = RegExp(
        r'(\w+)\s*:\s*(?:"([^"]*)"|[^\{\[,}]+)(?=\s*,|\s*\}|$)',
        multiLine: true,
      );

      for (String filterStr in filterStrings) {
        Map<String, dynamic> filter = {};
        print('Parsing filter: $filterStr');
        for (Match match in fieldExp.allMatches(filterStr)) {
          String key = match.group(1)!;
          String? value = match.group(2)?.trim() ?? '';
          print('Key: $key, Value: $value');

          if (key == 'label' &&
              value.startsWith('__(') &&
              value.endsWith(')')) {
            filter[key] =
                value.substring(3, value.length - 1).replaceAll('"', '');
          } else if (key == 'options' && value.contains('\\n')) {
            // Split options by \n and clean up
            filter[key] = value
                .split('\\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            print('Parsed options for $key: ${filter[key]}');
          } else if (key == 'default' && value.contains('frappe.datetime')) {
            if (value.contains('get_today()')) {
              filter[key] = DateTime.now().toIso8601String().substring(0, 10);
            } else {
              filter[key] = value;
            }
          } else {
            filter[key] = value.replaceAll('"', '').trim();
          }
        }

        // Ensure label is set
        if (!filter.containsKey('label') ||
            filter['label'].toString().isEmpty) {
          String fieldname = filter['fieldname']?.toString() ?? 'Unknown';
          filter['label'] = fieldname.replaceAll('_', ' ').toTitleCase();
          print('Label missing, defaulting to: ${filter['label']}');
        }

        if (filter.containsKey('fieldname') &&
            filter.containsKey('fieldtype')) {
          filters.add(filter);
        } else {
          print('Skipping invalid filter: $filter');
        }
      }
    } catch (e, stackTrace) {
      print('Error parsing filters: $e');
      print('Stack trace: $stackTrace');
    }
    print('Parsed filters: $filters');
    return filters;
  }

  Future<List<dynamic>> fetchLinkOptions(
      String linkDoctype, String query) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/method/frappe.desk.search.search_link?doctype=$linkDoctype&txt=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? [];
      } else {
        throw Exception('Failed to fetch link options: ${response.body}');
      }
    } catch (e) {
      // developer.log("Error fetching link options: $e");
      // showError('An error occurred: $e');
      return [];
    }
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        throw Exception('No authentication token found. Please log in again.');
      }

      final response = await http
          .post(
        Uri.parse(
            'http://localhost:8000/api/method/frappe.desk.query_report.run'),
        headers: {
          'Authorization': '$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'report_name': report_name,
          'filters': filterValues,
        }),
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out. Check your network connection.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] == null) {
          throw Exception('Invalid response format: Report data missing.');
        }
        setState(() {
          reportData = data['message'];
        });
      } else {
        throw Exception(
            'Failed to load report data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching report data: $e';
      });
      print(errorMessage);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildFilterInput(Map<String, dynamic> filter) {
    String fieldname = filter['fieldname'] as String;
    String fieldtype = filter['fieldtype'] as String;
    String label =
        (filter['label'] as String?)?.trim() ?? fieldname.toTitleCase();
    String defaultValue = filterValues[fieldname]?.toString() ??
        filter['default']?.toString() ??
        '';

    print(
        'Building filter: $fieldname, type: $fieldtype, label: "$label", default: "$defaultValue"');

    const inputPadding = EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0);
    final labelStyle =
        TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]);

    try {
      switch (fieldtype) {
        case 'Date':
          return Padding(
            padding: inputPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: defaultValue.isNotEmpty
                          ? DateTime.tryParse(defaultValue) ?? DateTime.now()
                          : DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        filterValues[fieldname] =
                            picked.toIso8601String().substring(0, 10);
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: Text(
                    filterValues[fieldname]!.toString().isNotEmpty
                        ? filterValues[fieldname]
                        : 'Select Date',
                  ),
                ),
              ],
            ),
          );

        case 'Check':
          return Padding(
            padding: inputPadding,
            child: CheckboxListTile(
              title: Text(label, style: labelStyle),
              value: filterValues[fieldname] == '1' ||
                  filterValues[fieldname] == true,
              onChanged: (value) {
                setState(() {
                  filterValues[fieldname] = value! ? '1' : '0';
                });
              },
            ),
          );

        case 'Select':
          List<dynamic> options = filter['options'] is String
              ? (filter['options'] as String)
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : (filter['options'] as List<dynamic>? ?? []);
          String? initialValue = options.contains(defaultValue)
              ? defaultValue
              : options.isNotEmpty
                  ? options.first.toString()
                  : '';
          if (!filterValues.containsKey(fieldname) ||
              filterValues[fieldname].toString().isEmpty) {
            filterValues[fieldname] = initialValue;
          }
          return Padding(
            padding: inputPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: filterValues[fieldname].toString().isNotEmpty &&
                          options.contains(filterValues[fieldname])
                      ? filterValues[fieldname].toString()
                      : initialValue,
                  items: options
                      .map((option) => DropdownMenuItem<String>(
                            value: option.toString(),
                            child: Text(option.toString()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      filterValues[fieldname] = value ?? '';
                    });
                  },
                ),
              ],
            ),
          );

        case 'Link':
          String label =
              filter['label']?.toString() ?? filter['fieldname'].toTitleCase();
          bool isRequired = filter['reqd'] == 1 || filter['reqd'] == '1';
          return Padding(
            padding: inputPadding,
            child: LinkField(
              fieldLabel: label,
              fieldName: fieldname,
              linkDoctype: filter['options']?.toString() ?? '',
              fetchLinkOptions: fetchLinkOptions,
              formData: filterValues,
              onValueChanged: (value) {
                setState(() {
                  filterValues[fieldname] = value ?? '';
                });
              },
              readOnly: false,
              isRequired: isRequired,
            ),
          );
        case 'MultiSelectList':
        case 'Data':
        case 'Autocomplete':
          return Padding(
            padding: inputPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 4),
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  controller: TextEditingController(text: defaultValue),
                  onChanged: (value) {
                    filterValues[fieldname] = value;
                  },
                ),
              ],
            ),
          );

        default:
          return Padding(
            padding: inputPadding,
            child: Text('Unsupported filter type: $fieldtype for $label',
                style: const TextStyle(color: Colors.red)),
          );
      }
    } catch (e) {
      print('Error building filter $fieldname: $e');
      return Padding(
        padding: inputPadding,
        child: Text('Error rendering $label: $e',
            style: const TextStyle(color: Colors.red)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report_name.toTitleCase()),
        // backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B95D6),
                        ),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : filters.isEmpty && reportData.isEmpty
                  ? const Center(
                      child: Text('No filters or data available'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: filters
                                    .map((filter) => _buildFilterInput(filter))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _fetchReportData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2B95D6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Run Report',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (reportData.isNotEmpty &&
                              reportData['result'] != null) ...[
                            const Text(
                              'Report Data',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: (reportData['columns']
                                              as List<dynamic>? ??
                                          [])
                                      .map((col) => DataColumn(
                                          label: Text(col['label'].toString())))
                                      .toList(),
                                  rows: (reportData['result']
                                              as List<dynamic>? ??
                                          [])
                                      .map((row) => DataRow(
                                            cells: (row as List)
                                                .map((cell) => DataCell(Text(
                                                    cell?.toString() ?? '')))
                                                .toList(),
                                          ))
                                      .toList(),
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

// Extension for title case
extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
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
  final bool isRequired;

  const LinkField({
    required this.fieldLabel,
    required this.fieldName,
    required this.linkDoctype,
    required this.fetchLinkOptions,
    required this.formData,
    required this.onValueChanged,
    this.readOnly = false,
    this.isRequired = false,
  });

  @override
  _LinkFieldState createState() => _LinkFieldState();
}

class _LinkFieldState extends State<LinkField> {
  String? _selectedValue;
  List<dynamic> _options = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.formData[widget.fieldName]?.toString();
    _controller.text = _selectedValue ?? '';
    if (widget.linkDoctype.isNotEmpty && _selectedValue != null) {
      _fetchOptions(_selectedValue!);
    }
  }

  @override
  void didUpdateWidget(LinkField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.linkDoctype != widget.linkDoctype) {
      _options = [];
      _selectedValue = widget.formData[widget.fieldName]?.toString();
      _controller.text = _selectedValue ?? '';
      if (widget.linkDoctype.isNotEmpty) {
        _fetchOptions(_selectedValue ?? '');
      }
    }
  }

  Future<void> _fetchOptions(String query) async {
    if (widget.linkDoctype.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      _options = await widget.fetchLinkOptions(widget.linkDoctype, query);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching options: $e')),
      );
    }
  }

  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (modalContext, modalSetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Select ${widget.fieldLabel}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        onChanged: (query) async {
                          await _fetchOptions(query);
                          modalSetState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Search ${widget.fieldLabel}',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading && _options.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _options.isEmpty
                              ? const Center(child: Text('No options found'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: _options.length,
                                  itemBuilder: (context, index) {
                                    final option = _options[index];
                                    return ListTile(
                                      title: Text(
                                          option['value']?.toString() ?? ''),
                                      subtitle: option['description'] != null
                                          ? Text(
                                              option['description'].toString())
                                          : null,
                                      selected:
                                          _selectedValue == option['value'],
                                      selectedTileColor:
                                          Colors.blue.withOpacity(0.1),
                                      onTap: () {
                                        setState(() {
                                          _selectedValue =
                                              option['value']?.toString();
                                          _controller.text =
                                              _selectedValue ?? '';
                                          widget.formData[widget.fieldName] =
                                              _selectedValue;
                                          widget.onValueChanged(_selectedValue);
                                        });
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isRequired ? '${widget.fieldLabel} *' : widget.fieldLabel,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: widget.readOnly || widget.linkDoctype.isEmpty
                ? null
                : _showOptionsModal,
            child: AbsorbPointer(
              child: TextFormField(
                controller: _controller,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: widget.linkDoctype.isEmpty
                      ? 'Select a doctype first'
                      : 'Select ${widget.fieldLabel}',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: widget.readOnly ? Colors.grey[300] : Colors.white,
                  suffixIcon: widget.linkDoctype.isEmpty
                      ? null
                      : _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_drop_down),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black),
                validator: widget.isRequired && !widget.readOnly
                    ? (value) => value == null || value.isEmpty
                        ? '${widget.fieldLabel} is required'
                        : null
                    : null,
              ),
            ),
          ),
          if (_selectedValue != null && !widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedValue = null;
                    _controller.clear();
                    widget.formData[widget.fieldName] = null;
                    widget.onValueChanged(null);
                  });
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
