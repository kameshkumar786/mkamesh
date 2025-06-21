import 'package:flutter/material.dart';
import 'package:mkamesh/screens/CategoryScreen.dart';
import 'package:mkamesh/screens/ChatListPage.dart';
import 'package:mkamesh/screens/ModuleCategoriesScreen.dart';
import 'package:mkamesh/screens/MyHomeScreen.dart';
import 'package:mkamesh/screens/formscreens/ReportScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/frappe_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FrappeService _frappeService = FrappeService();

  /// All tab views
  final List<Widget> _tabs = [
    MyHomeScreen(),
    MyHomeScreen(),
    ModuleCategoriesScreen(),
    const ChatListScreen(),
    ReportScreen(),
  ];

  /// Icons & labels for navigation
  final List<IconData> _icons = const [
    Icons.home_outlined,
    Icons.category_outlined,
    Icons.grid_view_rounded,
    Icons.chat_bubble_outline,
    Icons.bar_chart_rounded,
  ];

  final List<String> _labels = const [
    'Home',
    'Category',
    'Modules',
    'Chat',
    'Reports',
  ];

  int _selectedIndex = 0;
  bool _isRefreshing = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _handlePermissions();
    _loadUserId();
  }

  Future<void> _handlePermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      await Permission.location.request();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('userid'));
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      await _frappeService.fetchUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data refreshed successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      // floatingActionButton: _isRefreshing
      //     ? const CircularProgressIndicator()
      //     : FloatingActionButton(
      //         onPressed: _refreshData,
      //         tooltip: 'Refresh',
      //         child: const Icon(Icons.refresh),
      //       ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(context),
      backgroundColor: Colors.white,
    );
  }

  /// Custom bottom navigation bar with pill‑style animation
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            final bool isSelected = _selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: isSelected
                      ? const EdgeInsets.symmetric(vertical: 4, horizontal: 0)
                      : EdgeInsets.zero,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[index],
                        size: 24,
                        color: isSelected ? Colors.black : Colors.grey,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _labels[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? Colors.black : Colors.grey,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
