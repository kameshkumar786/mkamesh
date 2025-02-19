import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'file_records.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE file_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT,
        fileUrl TEXT UNIQUE,
        localPath TEXT
      )
    ''');
  }

  Future<void> insertFileRecord(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert(
      'file_records',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getFileRecord(String fileUrl) async {
    final db = await database;
    final result = await db.query(
      'file_records',
      where: 'fileUrl = ?',
      whereArgs: [fileUrl],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<bool> fileExists(String fileUrl) async {
    final record = await getFileRecord(fileUrl);
    if (record == null) return false;

    final file = File(record['localPath']);
    return await file.exists();
  }
}
