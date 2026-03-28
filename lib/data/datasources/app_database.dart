import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'privavoice.db');

    debugPrint('AppDatabase: Opening database at $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transcriptions(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            audioPath TEXT NOT NULL,
            text TEXT NOT NULL,
            wordTimestampsJson TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            durationMs INTEGER NOT NULL,
            isEncrypted INTEGER NOT NULL DEFAULT 1,
            speakerSegmentsJson TEXT,
            summary TEXT,
            actionItemsJson TEXT
          )
        ''');
        debugPrint('AppDatabase: Table created!');
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
    debugPrint('AppDatabase: Found ${maps.length} transcriptions');
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
    debugPrint('AppDatabase: Inserting transcription: ${data.title}');
    debugPrint('AppDatabase: Audio path: ${data.audioPath}');
    await db.insert('transcriptions', data.toMap());
    debugPrint('AppDatabase: Insert complete!');
  }

  static Future<void> updateTranscription(TranscriptionData data) async {
    final db = await database;
    await db.update(
      'transcriptions',
      data.toMap(),
      where: 'id = ?',
      whereArgs: [data.id],
    );
  }

  static Future<int> deleteTranscription(String id) async {
    final db = await database;
    return await db.delete(
      'transcriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
