import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mkamesh/data/DBHelper.dart';
import 'package:mkamesh/data/DataLocalChat.dart';
import 'package:mkamesh/services/SocketService.dart';

class ChatScreen extends StatefulWidget {
  final User currentUser;
  final Group? group; // Group can be null for individual chat
  final User? recipient; // Recipient user for one-on-one chat

  const ChatScreen(
      {Key? key, required this.currentUser, this.group, this.recipient})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();
  final DBHelper _dbHelper = DBHelper();

  List<Message> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    await _dbHelper.initDb();
    _socketService
        .connect('hhttp://localhost:8000'); // Replace with your server URL

    if (widget.group != null) {
      _socketService.listenForMessages((message) {
        setState(() {
          _messages.insert(0, message);
        });
      });
    }

    _loadMessages();
  }

  Future<void> _loadMessages() async {
    _messages = await _dbHelper.getMessages();
    setState(() {});
  }

  void _sendMessage(String text, {String type = 'text', File? file}) async {
    final message = Message(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUser.userId,
      content: text,
      type: type,
      timestamp: DateTime.now(),
      isSent: true,
      isSeen: false,
    );

    await _dbHelper.insertMessage(message);
    setState(() {
      _messages.insert(0, message);
    });

    _socketService.sendMessage(message);
  }

  void _pickFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _sendMessage(pickedFile.path, type: 'image', file: File(pickedFile.path));
    }
  }

  void _handleTyping(bool isTyping) {
    setState(() {
      _isTyping = isTyping;
    });
    _socketService.updateUserStatus(widget.currentUser.userId, isTyping);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group != null
            ? widget.group!.groupName
            : widget.recipient?.username ?? ''),
        actions: [
          IconButton(
            icon: Icon(Icons.photo),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              // Show user profile or group info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == widget.currentUser.userId;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.type == 'text')
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blueAccent : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                                color: isMe ? Colors.white : Colors.black),
                          ),
                        ),
                      if (message.type == 'image')
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 8),
                          child: Image.file(
                            File(message.content),
                            width: 150,
                          ),
                        ),
                      Row(
                        children: [
                          Text(
                            message.timestamp.toLocal().toString(),
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          if (!isMe && message.isSeen)
                            Icon(Icons.check, size: 14, color: Colors.blue),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const Text("User is typing..."),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(hintText: "Type a message..."),
              onChanged: (value) {
                _handleTyping(value.isNotEmpty);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                _sendMessage(_messageController.text.trim());
                _messageController.clear();
                _handleTyping(false);
              }
            },
          ),
        ],
      ),
    );
  }
}
