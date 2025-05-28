import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mkamesh/services/frappe_service.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ApprovalRequestScreen extends StatefulWidget {
  @override
  _ApprovalRequestScreenState createState() => _ApprovalRequestScreenState();
}

class _ApprovalRequestScreenState extends State<ApprovalRequestScreen> {
  List approvals = [];
  int page = 1;
  bool isLoading = false;
  bool hasMore = true;
  String documentType = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    fetchApprovals();
  }

  Future<void> fetchApprovals() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(
          '${FrappeService.baseUrl}/api/resource/Workflow Action?fields=["*"]&start=${(page - 1) * 20}&limit_page_length=20&document_type=$documentType&date=${selectedDate?.toIso8601String() ?? ''}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': '$token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data);

      final fetchedApprovals = data['data'] ?? [];

      setState(() {
        approvals.addAll(fetchedApprovals);
        page++;
        hasMore = fetchedApprovals.length == 20;
      });
    }
    setState(() => isLoading = false);
  }

  void applyFilters(String type, DateTime? date) {
    setState(() {
      documentType = type;
      selectedDate = date;
      approvals.clear();
      page = 1;
      hasMore = true;
    });
    fetchApprovals();
  }

  void approveDocument(String docId) async {
    await http.post(Uri.parse('http://localhost:8000/api/method/approve'),
        body: {'doc_id': docId});
    setState(() => approvals.removeWhere((doc) => doc['id'] == docId));
  }

  void rejectDocument(String docId) async {
    await http.post(Uri.parse('http://localhost:8000/api/method/reject'),
        body: {'doc_id': docId});
    setState(() => approvals.removeWhere((doc) => doc['id'] == docId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Approval Requests',
            style: TextStyle(color: Colors.black, fontSize: 14)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: documentType.isEmpty ? null : documentType,
                    hint: Text('Select Type',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    items: ['Invoice', 'Purchase Order', 'Sales Order']
                        .map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type, style: TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        applyFilters(value ?? '', selectedDate),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today, color: Colors.grey),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) applyFilters(documentType, picked);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: approvals.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == approvals.length) {
                  fetchApprovals();
                  return Center(child: CircularProgressIndicator());
                }
                final approval = approvals[index];

                final referenceName = approval['reference_name'] ?? '';
                final referenceDoctype = approval['reference_doctype'] ?? '';
                final status = approval['status'] ?? '';
                final workflowState = approval['workflow_state'] ?? '';
                final creation = approval['creation'] ?? '';

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(referenceDoctype,
                          style: TextStyle(fontSize: 14, color: Colors.black)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: $referenceName',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Status: $status',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Workflow: $workflowState',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Created: $creation',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => approveDocument(approval['name']),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: () => rejectDocument(approval['name']),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
