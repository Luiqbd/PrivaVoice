import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../domain/entities/transcription.dart';

/// AIService with proper error handling and Isolate processing
class AIService {
  static bool _initialized = false;

  Future<void> initializeAll() async {
    if (_initialized) return;
    print('AI: Initializing...');
    _initialized = true;
  }

  /// Process audio in background isolate
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
    String? existingId,  // Accept existing ID
  }) async {
    print('AI: Starting pipeline');
    print('AI: Audio path = $audioPath');
    
    try {
      // Verify file exists
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('FILE_NOT_FOUND: $audioPath');
      }
      
      final fileSize = await audioFile.length();
      print('AI: File size = $fileSize bytes');
      
      if (fileSize == 0) {
        throw Exception('EMPTY_FILE: $audioPath');
      }
      
      // Process in isolate
      final result = await Isolate.run(() => _processInBackground(audioPath, title));
      
      print('AI: Pipeline complete!');
      
      // Return with original ID if provided
      return Transcription(
        id: existingId ?? result.id,
        title: title,
        audioPath: audioPath,
        text: result.text,
        wordTimestamps: result.wordTimestamps,
        createdAt: result.createdAt,
        duration: result.duration,
        isEncrypted: false,
        speakerSegments: result.speakerSegments,
        summary: result.summary,
        actionItems: result.actionItems,
      );
    } catch (e) {
      print('AI ERROR: $e');
      rethrow;
    }
  }

  /// Background isolate function
  static Transcription _processInBackground(String audioPath, String title) {
    print('AI [Isolate]: Processing audio...');
    
    // Heavy processing simulation
    final endTime = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(endTime)) {
      // Simulate work
    }
    
    print('AI [Isolate]: Done');
    
    return Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: _demoTranscription,
      wordTimestamps: _demoWordTimestamps,
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2, seconds: 30),
      isEncrypted: false,
      speakerSegments: _demoSpeakerSegments,
      summary: _demoSummary,
      actionItems: _demoActionItems,
    );
  }

  static const String _demoTranscription = '''Pessoa 1: Olá, como você está?
Pessoa 2: Estou bem, obrigado! E você?
Pessoa 1: Muito bem também. Precisamos falar sobre o projeto da próxima semana.
Pessoa 2: Sim, o cliente está ansioso pelo resultado final.
Pessoa 1: Concordou. Vou preparar a lista de tarefas para organizarmos melhor.
Pessoa 2: Ótima ideia! Vamos nos reunir amanhã de manhã.
Pessoa 1: Perfeito! A gente se vê amanhã então.''';

  static const String _demoSummary = 'Resumo: Reunião sobre o projeto. Lista de tarefas será preparada. Nova reunião agendada para amanhã.';

  static const List<String> _demoActionItems = [
    'Preparar lista de tarefas',
    'Reunião amanhã de manhã', 
    'Finalizar entrega até sexta-feira',
  ];

  static List<WordTimestamp> get _demoWordTimestamps {
    final words = ['Olá', 'como', 'você', 'está'];
    final ts = <WordTimestamp>[];
    var start = 0;
    for (var w in words) {
      ts.add(WordTimestamp(
        word: w,
        startTime: Duration(milliseconds: start),
        endTime: Duration(milliseconds: start + 200),
        confidence: 0.9,
      ));
      start += 250;
    }
    return ts;
  }

  static List<SpeakerSegment> get _demoSpeakerSegments => [
    SpeakerSegment(speakerId: 'speaker_1', startTime: Duration.zero, endTime: const Duration(seconds: 15), text: 'Olá, como você está?'),
    SpeakerSegment(speakerId: 'speaker_2', startTime: const Duration(seconds: 15), endTime: const Duration(seconds: 30), text: 'Estou bem, obrigado!'),
  ];
}
