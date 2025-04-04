import 'package:flutter/material.dart';
import 'package:mkamesh/data/DBHelper.dart';
import 'package:mkamesh/data/DataLocalChat.dart';
import 'package:mkamesh/screens/ChatScreen.dart';
import 'package:mkamesh/services/SocketService.dart';
import 'package:mkamesh/services/frappe_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatListScreen extends StatefulWidget {
  // final User currentUser;

  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final SocketService _socketService = SocketService();
  final DBHelper _dbHelper = DBHelper();
  User? currentUser;
  List<User> _users = []; // List to hold users

  List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _initializeChatList();
    _loadUserData();
  }

  void _initializeChatList() async {
    await _dbHelper.initDb();
    _loadChats();
    _socketService
        .connect('http://localhost:8000'); // Replace with your server URL
  }

  Future<void> _loadUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData =
        prefs.getString('user_data'); // Get user data as a String
    if (userData != null) {
      // Assuming userData is a JSON string; convert it to a User object
      currentUser = User.fromJson(userData as Map<String, dynamic>);
      await _loadChats(); // Load chats after user data is loaded
    }
  }

  // Future<void> _loadUsers() async {
  //   try {
  //     _users = await FrappeService.fetchUserData();
  //     setState(() {});
  //   } catch (e) {
  //     print('Failed to load users: $e');
  //   }
  // }

  Future<void> _loadChats() async {
    _chats = await _dbHelper.getChatsForUser(currentUser!.userId);
    setState(() {});
  }

  void _navigateToChat(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUser: currentUser!,
          group: chat.group,
          recipient: chat.recipient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat List'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _chats.isEmpty
          ? Center(child: Text('No chats available'))
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return ListTile(
                  title: Text(chat.group != null
                      ? chat.group!.groupName
                      : chat.recipient?.username ?? ''),
                  subtitle: Text(chat.lastMessage ?? ''),
                  leading: CircleAvatar(
                    backgroundImage: chat.recipient?.profilePicture != null
                        ? NetworkImage(chat.recipient!.profilePicture)
                        : AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                  ),
                  onTap: () => _navigateToChat(chat),
                );
              },
            ),
    );
  }
}
