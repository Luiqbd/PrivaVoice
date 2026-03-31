import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../../core/utils/encryption_utils.dart';

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
  static bool _encryptedInitialized = false;
  static bool _fallbackModeUsed = false;  // Track fallback for security transparency
  
  // Security transparency flag
  static bool get isFallbackModeUsed => _fallbackModeUsed;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    debugPrint('AppDatabase: Initializing database...');
    
    // Initialize encryption FIRST - critical for database to work
    try {
      await EncryptionUtils.initialize();
      debugPrint('AppDatabase: Encryption initialized');
    } catch (e) {
      debugPrint('AppDatabase: Encryption init failed: $e');
    }
    _encryptedInitialized = true;
    
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Get proper documents directory
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
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('AppDatabase: Upgrading database v$oldVersion -> v$newVersion');
        // Future migrations can be added here
        // Example:
        // if (oldVersion < 2) {
        //   await db.execute('ALTER TABLE transcriptions ADD COLUMN newColumn TEXT');
        // }
      },
    );
  }

  /// Encrypt data before storing (AES-256 GCM)
  static Future<String> _encryptField(String plainText) async {
    if (!_encryptedInitialized) {
      await EncryptionUtils.initialize();
    }
    return await EncryptionUtils.encrypt(plainText);
  }

  /// Decrypt data when reading
  static Future<String> _decryptField(String encryptedText) async {
    if (!_encryptedInitialized) {
      await EncryptionUtils.initialize();
    }
    try {
      return await EncryptionUtils.decrypt(encryptedText);
    } catch (e) {
      debugPrint('AppDatabase: Decryption failed, returning raw: $e');
      return encryptedText; // Return raw if decryption fails
    }
  }

  static Future<List<TranscriptionData>> getAllTranscriptions() async {
    final db = await database;
    debugPrint('AppDatabase: Fetching all transcriptions...');
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transcriptions',
      orderBy: 'createdAt DESC',
    );
    
    debugPrint('AppDatabase: Raw records: ${maps.length}');

    // Decrypt sensitive fields when reading
    final decryptedMaps = <Map<String, dynamic>>[];
    for (final map in maps) {
      final decrypted = Map<String, dynamic>.from(map);
      if (map['text'] != null && map['text'].toString().isNotEmpty) {
        try {
          decrypted['text'] = await _decryptField(map['text'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt error: $e');
          decrypted['text'] = map['text'];
        }
      }
      if (map['summary'] != null && map['summary'].toString().isNotEmpty) {
        try {
          decrypted['summary'] = await _decryptField(map['summary'] as String);
        } catch (e) {
          decrypted['summary'] = map['summary'];
        }
      }
      decryptedMaps.add(decrypted);
    }
    
    return decryptedMaps.map((map) => TranscriptionData.fromMap(map)).toList();
  }

  static Future<TranscriptionData?> getTranscriptionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transcriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    // Decrypt before returning
    final map = maps.first;
    if (map['text'] != null && map['text'].toString().isNotEmpty) {
      map['text'] = await _decryptField(map['text'] as String);
    }
    if (map['summary'] != null && map['summary'].toString().isNotEmpty) {
      map['summary'] = await _decryptField(map['summary'] as String);
    }
    
    return TranscriptionData.fromMap(map);
  }

  static Future<void> insertTranscription(TranscriptionData data) async {
    final db = await database;
    debugPrint('AppDatabase: Inserting encrypted data: id=${data.id}');
    
    try {
      // Encrypt sensitive fields before storing
      final encryptedData = TranscriptionData(
        id: data.id,
        title: await _encryptField(data.title),
        audioPath: data.audioPath, // Path is not sensitive
        text: await _encryptField(data.text),
        wordTimestampsJson: await _encryptField(data.wordTimestampsJson),
        createdAt: data.createdAt,
        durationMs: data.durationMs,
        isEncrypted: true,
        speakerSegmentsJson: data.speakerSegmentsJson != null 
            ? await _encryptField(data.speakerSegmentsJson!) 
            : null,
        summary: data.summary != null 
            ? await _encryptField(data.summary!) 
            : null,
        actionItemsJson: data.actionItemsJson != null 
            ? await _encryptField(data.actionItemsJson!) 
            : null,
      );
      
      await db.insert(
        'transcriptions',
        encryptedData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('AppDatabase: Insert successful!');
    } catch (e, st) {
      debugPrint('AppDatabase: Insert error: $e');
      debugPrint('AppDatabase: Stack: $st');
      // Fallback - try without encryption
      try {
        await db.insert(
          'transcriptions',
          data.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('AppDatabase: Fallback insert OK! (SECURITY NOTE: Fallback mode used)');
        _fallbackModeUsed = true;  // Track for security transparency
      } catch (e2) {
        debugPrint('AppDatabase: Fallback error: $e2');
        rethrow;
      }
    }
  }

  static Future<void> updateTranscription(TranscriptionData data) async {
    final db = await database;
    
    // Encrypt before updating
    final encryptedData = TranscriptionData(
      id: data.id,
      title: await _encryptField(data.title),
      audioPath: data.audioPath,
      text: await _encryptField(data.text),
      wordTimestampsJson: await _encryptField(data.wordTimestampsJson),
      createdAt: data.createdAt,
      durationMs: data.durationMs,
      isEncrypted: true,
      speakerSegmentsJson: data.speakerSegmentsJson != null 
          ? await _encryptField(data.speakerSegmentsJson!) 
          : null,
      summary: data.summary != null 
          ? await _encryptField(data.summary!) 
          : null,
      actionItemsJson: data.actionItemsJson != null 
          ? await _encryptField(data.actionItemsJson!) 
          : null,
    );
    
    await db.update(
      'transcriptions',
      encryptedData.toMap(),
      where: 'id = ?',
      whereArgs: [data.id],
    );
    debugPrint('AppDatabase: ✅ Encrypted update successful!');
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
