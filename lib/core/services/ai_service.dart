import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../domain/entities/transcription.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';

/// AIService with lazy loading, isolate processing, and timeout
class AIService {
  static bool _whisperLoaded = false;
  static bool _llmLoaded = false;
  static bool _whisperUnloaded = true;
  static bool _llmUnloaded = true;

  Future<void> initializeAll() async {
    print('AI: Checking native libraries...');
    
    // Lazy load Whisper first
    if (_whisperUnloaded) {
      print('AI: Lazy loading Whisper...');
      _whisperLoaded = WhisperBindings.load();
      _whisperUnloaded = false;
      print('AI: Whisper loaded = $_whisperLoaded');
    }
  }

  /// Process with timeout and lazy loading
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
    String? existingId,
  }) async {
    print('AI: Starting pipeline');
    print('AI: Audio path = $audioPath');
    
    // Verify file exists and readable
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('FILE_NOT_FOUND: $audioPath');
    }
    
    try {
      // Test read permission
      final bytes = await audioFile.readAsBytes();
      print('AI: File readable, size = ${bytes.length} bytes');
    } catch (e) {
      throw Exception('FILE_READ_ERROR: $e');
    }
    
    if (bytes.isEmpty) {
      throw Exception('EMPTY_FILE: $audioPath');
    }

    // Process with timeout (30 seconds max)
    final result = await processWithTimeout(
      audioPath: audioPath,
      title: title,
      existingId: existingId,
      timeout: const Duration(seconds: 30),
    );
    
    return result;
  }

  /// Process with timeout
  Future<Transcription> processWithTimeout({
    required String audioPath,
    required String title,
    String? existingId,
    required Duration timeout,
  }) async {
    final completer = Completer<Transcription>();
    final stopwatch = Stopwatch()..start();
    
    // Process in isolate
    Isolate.spawn(_isolateEntry, _IsolateArgs(audioPath, title), onError: (e) {
      print('AI Isolate error: $e');
      completer.completeError(e);
    });
    
    // Wait for result or timeout
    final result = await Future.any([
      completer.future,
      Future.delayed(timeout, () => throw Exception('TIMEOUT: Process took more than ${timeout.inSeconds}s')),
    ]);
    
    stopwatch.stop();
    print('AI: Pipeline complete in ${stopwatch.elapsedMilliseconds}ms');
    
    return result;
  }

  static void _isolateEntry(SendPort sendPort) {
    print('AI [Isolate]: Starting...');
    
    // Load Whisper (lazy)
    final whisperLoaded = WhisperBindings.load();
    print('AI [Isolate]: Whisper = $whisperLoaded');
    
    // Process
    final transcription = _processAudio();
    
    // Unload Whisper
    print('AI [Isolate]: Unloading Whisper...');
    WhisperBindings.unload();
    
    // Load Llama (lazy, after Whisper done)
    final llamaLoaded = LlamaBindings.load();
    print('AI [Isolate]: Llama = $llamaLoaded');
    
    // Generate summary
    final summary = _generateSummary(transcription);
    
    // Unload Llama
    print('AI [Isolate]: Unloading Llama...');
    LlamaBindings.unload();
    
    print('AI [Isolate]: Done');
    sendPort.send(Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '',
      audioPath: '',
      text: transcription,
      wordTimestamps: [],
      createdAt: DateTime.now(),
      duration: Duration.zero,
      isEncrypted: false,
      speakerSegments: [],
      summary: summary['summary'],
      actionItems: List<String>.from(summary['actionItems']),
    ));
  }

  static String _processAudio() {
    // Simulate Whisper processing
    print('AI [Isolate]: Processing audio with Whisper...');
    final endTime = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(endTime)) {}
    return _demoTranscription;
  }

  static Map<String, dynamic> _generateSummary(String text) {
    // Simulate Llama processing
    print('AI [Isolate]: Generating summary with Llama...');
    return {
      'summary': _demoSummary,
      'actionItems': _demoActionItems,
    };
  }

  static const String _demoTranscription = '''Pessoa 1: Olá, como você está?
Pessoa 2: Estou bem, obrigado! E você?
Pessoa 1: Muito bem também. Precisamos falar sobre o projeto.
Pessoa 2: Sim, o cliente está ansioso.
Pessoa 1: Vou preparar a lista de tarefas.
Pessoa 2: Ótimo! Nos vemos amanhã.''';

  static const String _demoSummary = 'Resumo: Reunião sobre projeto. Lista de tarefas preparada.';

  static const List<String> _demoActionItems = [
    'Preparar lista de tarefas',
    'Reunião amanhã',
    'Finalizar até sexta',
  ];
}

class _IsolateArgs {
  final String audioPath;
  final String title;
  _IsolateArgs(this.audioPath, this.title);
}
