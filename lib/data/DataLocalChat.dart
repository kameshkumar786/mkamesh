class User {
  final String userId;
  final String username;
  final bool isOnline;
  final String profilePicture;

  User({
    required this.userId,
    required this.username,
    this.isOnline = false,
    required this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      username: json['username'],
      isOnline: json['isOnline'] ?? false,
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'isOnline': isOnline,
    };
  }
}

class Message {
  final String messageId;
  final String senderId;
  final String content;
  final String type; // e.g., text, image, video
  final DateTime timestamp;
  final bool isSent;
  final bool isSeen;

  Message({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isSent = false,
    this.isSeen = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['messageId'],
      senderId: json['senderId'],
      content: json['content'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      isSent: json['isSent'] ?? false,
      isSeen: json['isSeen'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isSeen': isSeen,
    };
  }
}

class Group {
  final String groupId;
  final String groupName;
  final List<User> members;

  Group({
    required this.groupId,
    required this.groupName,
    required this.members,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['groupId'],
      groupName: json['groupName'],
      members: (json['members'] as List).map((e) => User.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'members': members.map((user) => user.toJson()).toList(),
    };
  }
}

class Chat {
  final Group? group;
  final User? recipient;
  final String? lastMessage; // Last message sent/received

  Chat({this.group, this.recipient, this.lastMessage});
}
