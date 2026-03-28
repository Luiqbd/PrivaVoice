import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class TranscriptionData {
  final String id;
  final String title;
  final String audioPath;
  final String text;
  final String wordTimestampsJson;
  final DateTime createdAt;
  final int durationMs;
  final bool isEncrypted;
  final String? speakerSegmentsJson;
  final String? summary;
  final String? actionItemsJson;

  TranscriptionData({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.text,
    required this.wordTimestampsJson,
    required this.createdAt,
    required this.durationMs,
    this.isEncrypted = true,
    this.speakerSegmentsJson,
    this.summary,
    this.actionItemsJson,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'audioPath': audioPath,
    'text': text,
    'wordTimestampsJson': wordTimestampsJson,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'durationMs': durationMs,
    'isEncrypted': isEncrypted ? 1 : 0,
    'speakerSegmentsJson': speakerSegmentsJson,
    'summary': summary,
    'actionItemsJson': actionItemsJson,
  };

  factory TranscriptionData.fromMap(Map<String, dynamic> map) => TranscriptionData(
    id: map['id'] as String,
    title: map['title'] as String,
    audioPath: map['audioPath'] as String,
    text: map['text'] as String,
    wordTimestampsJson: map['wordTimestampsJson'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    durationMs: map['durationMs'] as int,
    isEncrypted: map['isEncrypted'] == 1,
    speakerSegmentsJson: map['speakerSegmentsJson'] as String?,
    summary: map['summary'] as String?,
    actionItemsJson: map['actionItemsJson'] as String?,
  );
}

class AppDatabase {
  static Database? _database;
  static const String _dbName = 'privavoice.db';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    debugPrint('AppDatabase: Initializing database...');
    
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Get proper documents directory (persistent storage)
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'databases', _dbName);
    
    // Create databases directory if needed
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    debugPrint('AppDatabase: Database path = $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        debugPrint('AppDatabase: Creating table...');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transcriptions(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            audioPath TEXT NOT NULL,
            text TEXT NOT NULL DEFAULT '',
            wordTimestampsJson TEXT NOT NULL DEFAULT '[]',
            createdAt INTEGER NOT NULL,
            durationMs INTEGER NOT NULL DEFAULT 0,
            isEncrypted INTEGER NOT NULL DEFAULT 0,
            speakerSegmentsJson TEXT,
            summary TEXT,
            actionItemsJson TEXT
          )
        ''');
        debugPrint('AppDatabase: Table created successfully!');
      },
      onOpen: (db) async {
        debugPrint('AppDatabase: Database opened!');
        // Verify table exists
        final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='transcriptions'");
        debugPrint('AppDatabase: Tables = $result');
      },
    );
  }

  static Future<List<TranscriptionData>> getAllTranscriptions() async {
    final db = await database;
    debugPrint('AppDatabase: Fetching all transcriptions...');
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transcriptions',
      orderBy: 'createdAt DESC',
    );
    
    debugPrint('AppDatabase: Found ${maps.length} records');
    if (maps.isNotEmpty) {
      debugPrint('AppDatabase: First record = ${maps.first}');
    }
    
    return maps.map((map) => TranscriptionData.fromMap(map)).toList();
  }

  static Future<TranscriptionData?> getTranscriptionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transcriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TranscriptionData.fromMap(maps.first);
  }

  static Future<void> insertTranscription(TranscriptionData data) async {
    final db = await database;
    debugPrint('AppDatabase: Inserting: id=${data.id}, title=${data.title}');
    debugPrint('AppDatabase: audioPath=${data.audioPath}');
    
    try {
      await db.insert(
        'transcriptions',
        data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('AppDatabase: Insert successful!');
      
      // Verify insert
      final result = await db.query(
        'transcriptions',
        where: 'id = ?',
        whereArgs: [data.id],
      );
      debugPrint('AppDatabase: Verify insert = ${result.length} records');
    } catch (e) {
      debugPrint('AppDatabase: Insert error = $e');
      rethrow;
    }
  }

  static Future<void> updateTranscription(TranscriptionData data) async {
    final db = await database;
    await db.update(
      'transcriptions',
      data.toMap(),
      where: 'id = ?',
      whereArgs: [data.id],
    );
    debugPrint('AppDatabase: Update successful!');
  }

  static Future<int> deleteTranscription(String id) async {
    final db = await database;
    final result = await db.delete(
      'transcriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('AppDatabase: Delete result = $result');
    return result;
  }
}
