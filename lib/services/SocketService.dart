import 'package:flutter/material.dart';
import 'package:mkamesh/data/DataLocalChat.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService with ChangeNotifier {
  IO.Socket? _socket;
  bool isConnected = false;

  void connect(String serverUrl) {
    _socket = IO.io('http://localhost:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket?.onConnect((_) {
      isConnected = true;
      notifyListeners();
      print("Socket connected.");
    });

    _socket?.onDisconnect((_) {
      isConnected = false;
      notifyListeners();
      print("Socket disconnected.");
    });

    _socket?.onError((data) {
      print("Socket error: $data");
    });
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void sendMessage(Message message) {
    _socket?.emit("send_message", message.toJson());
  }

  void listenForMessages(Function(Message) onMessageReceived) {
    _socket?.on("receive_message", (data) {
      onMessageReceived(Message.fromJson(data));
    });
  }

  void updateUserStatus(String userId, bool isTyping) {
    _socket?.emit("update_status", {
      "userId": userId,
      "isTyping": isTyping,
    });
  }

  void listenForUserStatus(Function(String, bool) onUserStatus) {
    _socket?.on("user_status", (data) {
      onUserStatus(data["userId"], data["isTyping"]);
    });
  }
}
