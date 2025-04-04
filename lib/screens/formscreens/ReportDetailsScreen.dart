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
        print('Raw script: ${data['message']['script']}');
        setState(() {
          filters = _parseFilters(data['message']['script']);
          for (var filter in filters) {
            filterValues[filter['fieldname']] = filter['default'] ?? '';
          }
        });
        print('Parsed filters: $filters');
        print('Initial filterValues: $filterValues');
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
      RegExp filtersArrayExp = RegExp(
        r'filters\s*:\s*\[(.*?)\]',
        multiLine: true,
        dotAll: true,
      );
      Match? arrayMatch = filtersArrayExp.firstMatch(script);

      if (arrayMatch == null) {
        print('No filters array found. Trying alternative parsing...');
        RegExp altFiltersExp =
            RegExp(r'\[(.*?)\]', multiLine: true, dotAll: true);
        arrayMatch = altFiltersExp.firstMatch(script);
        if (arrayMatch == null) {
          print('No filter array found in script');
          return filters;
        }
      }

      String filtersContent = arrayMatch.group(1)!.trim();
      if (filtersContent.isEmpty) {
        print('Filters content is empty');
        return filters;
      }

      List<String> filterStrings = [];
      int braceCount = 0;
      StringBuffer currentFilter = StringBuffer();

      for (int i = 0; i < filtersContent.length; i++) {
        String char = filtersContent[i];
        if (char == '{') braceCount++;
        if (char == '}') braceCount--;
        currentFilter.write(char);

        if (char == '}' && braceCount == 0) {
          String filterStr = currentFilter.toString().trim();
          if (filterStr.isNotEmpty) {
            filterStrings.add(filterStr);
          }
          currentFilter.clear();
          while (i + 1 < filtersContent.length &&
              (filtersContent[i + 1] == ',' ||
                  filtersContent[i + 1].trim().isEmpty)) {
            i++;
          }
        }
      }

      if (currentFilter.isNotEmpty) {
        String filterStr = currentFilter.toString().trim();
        if (filterStr.isNotEmpty) {
          filterStrings.add(filterStr);
        }
      }

      // Improved regex to capture all key-value pairs more reliably
      RegExp fieldExp = RegExp(
        r'(\w+)\s*:\s*(?:"([^"]*)"|[^\{\[,]+|\{.*?\}|\[.*?\])(?=\s*,|\s*\}|$)',
        multiLine: true,
        dotAll: true,
      );

      for (String filterStr in filterStrings) {
        Map<String, dynamic> filter = {};
        Iterable<Match> matches = fieldExp.allMatches(filterStr);
        print('Parsing filter string: $filterStr');

        for (Match match in matches) {
          String key = match.group(1)!;
          String value = match.group(2)?.trim() ?? '';
          print('Key: $key, Value: $value'); // Debug each key-value pair
          if (key == 'label' &&
              value.startsWith('__(') &&
              value.endsWith(')')) {
            filter[key] =
                value.substring(3, value.length - 1).replaceAll('"', '');
          } else if (key == 'options' && value.contains('\n')) {
            filter[key] = value
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (key == 'default' && value.contains(',')) {
            filter[key] = value.split(',').map((e) => e.trim()).first;
          } else if (value.contains('frappe.datetime')) {
            if (value.contains('get_today()')) {
              filter[key] = DateTime.now().toIso8601String().substring(0, 10);
            } else if (value.contains('add_months')) {
              filter[key] = DateTime.now()
                  .subtract(Duration(days: 30))
                  .toIso8601String()
                  .substring(0, 10);
            } else {
              filter[key] = value;
            }
          } else {
            filter[key] = value.replaceAll('"', '');
          }
        }

        if (!filter.containsKey('label')) {
          filter['label'] = filter['fieldname'] ?? 'Unknown';
          print('Label missing, defaulting to: ${filter['label']}');
        }
        if (filter.containsKey('fieldname') &&
            filter.containsKey('fieldtype')) {
          filters.add(filter);
        } else {
          print('Invalid filter (missing fieldname or fieldtype): $filter');
        }
      }
    } catch (e) {
      print('Error parsing filters: $e');
    }
    return filters;
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
    String label = filter['label'] as String;
    String defaultValue = filterValues[fieldname].toString().isNotEmpty
        ? filterValues[fieldname].toString()
        : (filter['default']?.toString() ?? '');

    print(
        'Building filter: $fieldname, type: $fieldtype, label: $label, default: "$defaultValue"');

    try {
      switch (fieldtype) {
        case 'Date':
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
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
              child: Text(
                  '$label: ${filterValues[fieldname].toString().isNotEmpty ? filterValues[fieldname] : 'Select Date'}'),
            ),
          );

        case 'Check':
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: CheckboxListTile(
              title: Text(label),
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
          print(
              'Select options for $fieldname: $options'); // Debug dropdown options
          String? initialValue = options.contains(defaultValue)
              ? defaultValue
              : (options.isNotEmpty ? options.first.toString() : '');
          if (!filterValues.containsKey(fieldname) ||
              filterValues[fieldname].toString().isEmpty) {
            filterValues[fieldname] = initialValue;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: label),
              value: filterValues[fieldname].toString().isNotEmpty &&
                      options.contains(filterValues[fieldname])
                  ? filterValues[fieldname].toString()
                  : initialValue,
              items: options.map((option) {
                String value = option.toString();
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  filterValues[fieldname] = value ?? '';
                });
              },
            ),
          );

        case 'Link':
        case 'MultiSelectList':
        case 'Data':
        case 'Autocomplete':
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: label,
                hintText: filter['options']?.toString() ?? 'Enter $label',
              ),
              controller: TextEditingController(text: defaultValue),
              onChanged: (value) {
                filterValues[fieldname] = value;
              },
            ),
          );

        default:
          return const SizedBox.shrink();
      }
    } catch (e) {
      print('Error building filter $fieldname: $e');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Error rendering $label: $e',
            style: const TextStyle(color: Colors.red)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(report_name),
      ),
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filters.isEmpty && reportData.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('No filters or data available'),
                          SizedBox(height: 10),
                          Text('Please check the report script or server logs'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Filters',
                              style: Theme.of(context).textTheme.titleLarge),
                          ...filters
                              .map((filter) => _buildFilterInput(filter))
                              .toList(),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _fetchReportData,
                            child: const Text('Run Report'),
                          ),
                          const SizedBox(height: 20),
                          if (reportData.isNotEmpty &&
                              reportData['result'] != null) ...[
                            Text('Report Data',
                                style: Theme.of(context).textTheme.titleLarge),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: (reportData['columns']
                                            as List<dynamic>? ??
                                        [])
                                    .map((col) => DataColumn(
                                        label: Text(col['label'].toString())))
                                    .toList(),
                                rows: (reportData['result'] as List<dynamic>? ??
                                        [])
                                    .map((row) {
                                  if (row is List) {
                                    return DataRow(
                                      cells: row
                                          .map((cell) => DataCell(
                                              Text(cell?.toString() ?? '')))
                                          .toList(),
                                    );
                                  } else {
                                    return const DataRow(cells: []);
                                  }
                                }).toList(),
                              ),
                            ),
                          ] else if (reportData.isNotEmpty)
                            const Text(
                                'No data available for the selected filters'),
                        ],
                      ),
                    ),
    );
  }
}
