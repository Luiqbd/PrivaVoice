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
  final String? keywordsJson; // Keywords from Llama
  final String? notes; // Notas do usuário
  final String? bookmarksJson; // Star timestamps
  final String? manualNote; // Manual note attachment
  final String? attachedImagePath; // Image attachment path
  final bool isHidden; // Vault hidden flag
  final String? speakerNamesJson; // Custom speaker names (Map<String, String>)

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
    this.keywordsJson,
    this.notes,
    this.bookmarksJson,
    this.manualNote,
    this.attachedImagePath,
    this.isHidden = false,
    this.speakerNamesJson,
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
    'keywordsJson': keywordsJson,
    'notes': notes,
    'bookmarksJson': bookmarksJson,
    'manualNote': manualNote,
    'attachedImagePath': attachedImagePath,
    'isHidden': isHidden ? 1 : 0,
    'speakerNamesJson': speakerNamesJson,
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
    keywordsJson: map['keywordsJson'] as String?,
    notes: map['notes'] as String?,
    bookmarksJson: map['bookmarksJson'] as String?,
    manualNote: map['manualNote'] as String?,
    attachedImagePath: map['attachedImagePath'] as String?,
    isHidden: map['isHidden'] == 1,
    speakerNamesJson: map['speakerNamesJson'] as String?,
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
      version: 3,
      singleInstance: true,  // Ensure single instance - fixes read-only issue
      onConfigure: (db) async {
        debugPrint("AppDatabase: Enabling WAL mode...");
        await db.execute("PRAGMA journal_mode=WAL;");
        debugPrint("AppDatabase: WAL mode enabled!");
      },
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
            actionItemsJson TEXT,
            keywordsJson TEXT,
            notes TEXT,
            speakerNamesJson TEXT
          )
        ''');
        debugPrint('AppDatabase: Table created successfully!');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('AppDatabase: Upgrading database v$oldVersion -> v$newVersion');
        // Migration for version 2: add notes column
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE transcriptions ADD COLUMN notes TEXT');
            debugPrint('AppDatabase: Added notes column');
          } catch (e) {
            debugPrint('AppDatabase: Notes column already exists');
          }
        }
        // Migration for version 3: add keywords column
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE transcriptions ADD COLUMN keywordsJson TEXT');
            debugPrint('AppDatabase: Added keywordsJson column');
          } catch (e) {
            debugPrint('AppDatabase: KeywordsJson column already exists');
          }
        }
        // Migration for version 4: add bookmarks, manualNote, attachedImage, isHidden
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE transcriptions ADD COLUMN bookmarksJson TEXT');
            await db.execute('ALTER TABLE transcriptions ADD COLUMN manualNote TEXT');
            await db.execute('ALTER TABLE transcriptions ADD COLUMN attachedImagePath TEXT');
            await db.execute('ALTER TABLE transcriptions ADD COLUMN isHidden INTEGER NOT NULL DEFAULT 0');
            debugPrint('AppDatabase: Added vault columns');
          } catch (e) {
            debugPrint('AppDatabase: Vault columns already exist');
          }
        }
      },
    );
  }
  
  static int get currentVersion => 4;

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

    // Decrypt sensitive fields when reading (only if isEncrypted = true)
    final decryptedMaps = <Map<String, dynamic>>[];
    for (final map in maps) {
      final decrypted = Map<String, dynamic>.from(map);
      final isEncrypted = map['isEncrypted'] == 1;
      debugPrint('AppDatabase: isEncrypted=$isEncrypted for id=${map['id']}');
      
      // Decrypt title if encrypted
      if (isEncrypted && map['title'] != null && map['title'].toString().isNotEmpty) {
        try {
          decrypted['title'] = await _decryptField(map['title'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt title error (returning raw): $e');
          decrypted['title'] = map['title'];
        }
      }
      
      // Decrypt text if encrypted
      if (isEncrypted && map['text'] != null && map['text'].toString().isNotEmpty) {
        try {
          decrypted['text'] = await _decryptField(map['text'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt text error (returning raw): $e');
          decrypted['text'] = map['text'];
        }
      }
      
      // Decrypt summary if encrypted
      if (isEncrypted && map['summary'] != null && map['summary'].toString().isNotEmpty) {
        try {
          decrypted['summary'] = await _decryptField(map['summary'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt summary error: $e');
          decrypted['summary'] = map['summary'];
        }
      }
      
      // Decrypt wordTimestampsJson if encrypted
      if (isEncrypted && map['wordTimestampsJson'] != null && map['wordTimestampsJson'].toString().isNotEmpty) {
        try {
          decrypted['wordTimestampsJson'] = await _decryptField(map['wordTimestampsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt wordTimestampsJson error: $e');
          decrypted['wordTimestampsJson'] = map['wordTimestampsJson'];
        }
      }
      
      // Decrypt speakerSegmentsJson if encrypted
      if (isEncrypted && map['speakerSegmentsJson'] != null && map['speakerSegmentsJson'].toString().isNotEmpty) {
        try {
          decrypted['speakerSegmentsJson'] = await _decryptField(map['speakerSegmentsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt speakerSegmentsJson error: $e');
          decrypted['speakerSegmentsJson'] = map['speakerSegmentsJson'];
        }
      }
      
      // Decrypt actionItemsJson if encrypted
      if (isEncrypted && map['actionItemsJson'] != null && map['actionItemsJson'].toString().isNotEmpty) {
        try {
          decrypted['actionItemsJson'] = await _decryptField(map['actionItemsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt actionItemsJson error: $e');
          decrypted['actionItemsJson'] = map['actionItemsJson'];
        }
      }
      
      // Decrypt speakerNamesJson if encrypted
      if (isEncrypted && map['speakerNamesJson'] != null && map['speakerNamesJson'].toString().isNotEmpty) {
        try {
          decrypted['speakerNamesJson'] = await _decryptField(map['speakerNamesJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt speakerNamesJson error: $e');
          decrypted['speakerNamesJson'] = map['speakerNamesJson'];
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
    
    // Decrypt before returning (only if isEncrypted = true)
    final map = maps.first;
    final isEncrypted = map['isEncrypted'] == 1;
    
    if (isEncrypted) {
      debugPrint('AppDatabase: Decrypting transcription $id');
      final decryptedMap = Map<String, dynamic>.from(map);
      
      // Decrypt title
      if (map['title'] != null && map['title'].toString().isNotEmpty) {
        try {
          decryptedMap['title'] = await _decryptField(map['title'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt title error: $e');
        }
      }
      
      // Decrypt text
      if (map['text'] != null && map['text'].toString().isNotEmpty) {
        try {
          decryptedMap['text'] = await _decryptField(map['text'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt text error: $e');
        }
      }
      
      // Decrypt summary
      if (map['summary'] != null && map['summary'].toString().isNotEmpty) {
        try {
          decryptedMap['summary'] = await _decryptField(map['summary'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt summary error: $e');
        }
      }
      
      // Decrypt wordTimestampsJson
      if (map['wordTimestampsJson'] != null && map['wordTimestampsJson'].toString().isNotEmpty) {
        try {
          decryptedMap['wordTimestampsJson'] = await _decryptField(map['wordTimestampsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt wordTimestampsJson error: $e');
        }
      }
      
      // Decrypt speakerSegmentsJson
      if (map['speakerSegmentsJson'] != null && map['speakerSegmentsJson'].toString().isNotEmpty) {
        try {
          decryptedMap['speakerSegmentsJson'] = await _decryptField(map['speakerSegmentsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt speakerSegmentsJson error: $e');
        }
      }
      
      // Decrypt actionItemsJson
      if (map['actionItemsJson'] != null && map['actionItemsJson'].toString().isNotEmpty) {
        try {
          decryptedMap['actionItemsJson'] = await _decryptField(map['actionItemsJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt actionItemsJson error: $e');
        }
      }
      
      // Decrypt speakerNamesJson
      if (map['speakerNamesJson'] != null && map['speakerNamesJson'].toString().isNotEmpty) {
        try {
          decryptedMap['speakerNamesJson'] = await _decryptField(map['speakerNamesJson'] as String);
        } catch (e) {
          debugPrint('AppDatabase: Decrypt speakerNamesJson error: $e');
        }
      }
      
      return TranscriptionData.fromMap(decryptedMap);
    } else {
      debugPrint('AppDatabase: Transcription $id not encrypted, skipping decrypt');
    }
    
    return TranscriptionData.fromMap(map);
  }

static Future<void> insertTranscription(TranscriptionData data) async {
    final db = await database;
    debugPrint('AppDatabase: Inserting: id=${data.id}, textLen=${data.text.length}');

    try {
      // For initial save with "Processando...", save without encryption first
      if (data.text == 'Processando...' || data.text.isEmpty) {
        debugPrint('AppDatabase: Saving without encryption (initial save)');
        await db.insert(
          'transcriptions',
          data.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('AppDatabase: Insert successful (no encryption)!');
        return;
      }

      // Encrypt for full transcription (including notes)
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
        notes: data.notes, // Include notes (not encrypted for now)
        speakerNamesJson: data.speakerNamesJson != null
            ? await _encryptField(data.speakerNamesJson!)
            : null,
      );

      await db.insert(
        'transcriptions',
        encryptedData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('AppDatabase: Insert successful (encrypted)!');
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
        _fallbackModeUsed = true;
      } catch (e2) {
        debugPrint('AppDatabase: Fallback error: $e2');
        rethrow;
      }
    }
  }


static Future<void> updateTranscription(TranscriptionData data) async {
    final db = await database;
    debugPrint('AppDatabase: Updating transcription: ${data.id}');

    try {
      await db.transaction((txn) async {
        // For updates with actual text, ALWAYS encrypt (ignore what AIService says)
        // This ensures all real transcriptions are encrypted regardless of AIService.isEncrypted
        if (data.text != 'Processando...' && data.text.isNotEmpty) {
          final encryptedData = TranscriptionData(
            id: data.id,
            title: await _encryptField(data.title),
            audioPath: data.audioPath,
            text: await _encryptField(data.text),
            wordTimestampsJson: await _encryptField(data.wordTimestampsJson),
            createdAt: data.createdAt,
            durationMs: data.durationMs,
            isEncrypted: true, // ALWAYS true for real transcriptions
            speakerSegmentsJson: data.speakerSegmentsJson != null
                ? await _encryptField(data.speakerSegmentsJson!)
                : null,
            summary: data.summary != null
                ? await _encryptField(data.summary!)
                : null,
            actionItemsJson: data.actionItemsJson != null
                ? await _encryptField(data.actionItemsJson!)
                : null,
            notes: data.notes,
            speakerNamesJson: data.speakerNamesJson != null
                ? await _encryptField(data.speakerNamesJson!)
                : null,
          );

          await txn.update(
            'transcriptions',
            encryptedData.toMap(),
            where: 'id = ?',
            whereArgs: [data.id],
          );
          debugPrint('AppDatabase: Update successful (encrypted)!');
        } else {
          // No encryption needed - for "Processando..." or notes updates
          await txn.update(
            'transcriptions',
            data.toMap(),
            where: 'id = ?',
            whereArgs: [data.id],
          );
          debugPrint('AppDatabase: Update successful!');
        }
      });
    } catch (e, st) {
      debugPrint('AppDatabase: Update error: $e');
      debugPrint('AppDatabase: Stack: $st');
      rethrow;
    }
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
