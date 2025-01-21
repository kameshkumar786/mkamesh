import 'package:mkamesh/data/DataLocalChat.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._();
  static Database? _db;

  DBHelper._();

  factory DBHelper() => _instance;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    String path = await getDatabasesPath() + 'chat_app.db';
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Users (
        userId TEXT PRIMARY KEY,
        username TEXT,
        isOnline INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE Messages (
        messageId TEXT PRIMARY KEY,
        senderId TEXT,
        content TEXT,
        type TEXT,
        timestamp TEXT,
        isSent INTEGER,
        isSeen INTEGER
      )
    ''');
  }

  Future<void> insertUser(User user) async {
    final dbClient = await db;
    await dbClient.insert('Users', user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getUsers() async {
    final dbClient = await db;
    final result = await dbClient.query('Users');
    return result.map((e) => User.fromJson(e)).toList();
  }

  Future<void> insertMessage(Message message) async {
    final dbClient = await db;
    await dbClient.insert('Messages', message.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages() async {
    final dbClient = await db;
    final result = await dbClient.query('Messages', orderBy: 'timestamp DESC');
    return result.map((e) => Message.fromJson(e)).toList();
  }

  Future<List<Chat>> getChatsForUser(String userId) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> chatMaps = await dbClient.rawQuery('''
      SELECT * FROM chats 
      WHERE recipientId = ? OR groupId IS NOT NULL
    ''', [userId]);

    List<Chat> chats = [];
    for (var chatMap in chatMaps) {
      User? recipient;
      Group? group;
      if (chatMap['recipientId'] != null) {
        // Fetch recipient details from your user table
        recipient = User(
          userId: chatMap['recipientId'],
          username:
              'User ${chatMap['recipientId']}', // Fetch username from the database if available
          profilePicture:
              '', // Fetch profile picture from the database if available
        );
      } else if (chatMap['groupId'] != null) {
        // Fetch group details from your group table
        group = Group(
          groupId: chatMap['groupId'],
          groupName: 'Group ${chatMap['groupId']}',
          members: [], // Fetch group name from the database if available
        );
      }

      chats.add(Chat(
        group: group,
        recipient: recipient,
        lastMessage: chatMap['lastMessage'],
      ));
    }

    return chats;
  }
}
