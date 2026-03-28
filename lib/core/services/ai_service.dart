import 'dart:io';
import '../../domain/entities/transcription.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';

/// AI Service Coordinator
/// Manages all AI services - uses demo mode when models not available
class AIService {
  bool _initialized = false;

  /// Initialize AI services
  Future<void> initializeAll() async {
    _initialized = true;
  }

  /// Full AI Pipeline: Transcription + Summary + Action Items
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
  }) async {
    print('AI: Starting full pipeline for $audioPath');
    
    // Verify audio file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }
    
    final fileSize = await file.length();
    print('AI: Audio file size: $fileSize bytes');
    
    // Simulate processing time (in real app, this would be Whisper + Llama)
    await Future.delayed(const Duration(seconds: 2));
    
    // Demo transcription (in production, this comes from Whisper)
    final demoText = _generateDemoTranscription();
    
    // Demo summary (in production, this comes from TinyLlama)
    final demoSummary = _generateDemoSummary(demoText);
    
    // Demo action items
    final demoActions = _generateDemoActionItems(demoText);
    
    print('AI: Pipeline complete!');
    
    return Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: demoText,
      wordTimestamps: _generateWordTimestamps(demoText),
      createdAt: DateTime.now(),
      duration: const Duration(minutes: 2, seconds: 30),
      isEncrypted: false,
      speakerSegments: _generateSpeakerSegments(demoText),
      summary: demoSummary,
      actionItems: demoActions,
    );
  }

  String _generateDemoTranscription() {
    return '''Esta é uma gravação de exemplo para demonstrar o funcionamento da transcrição.

Pessoa 1: Olá, tudo bem com você?
Pessoa 2: Sim, muito bem! E com você?
Pessoa 1: Estou ótimo, obrigado por perguntar. Estava pensando sobre o projeto que precisamos entregar na próxima semana.
Pessoa 2: Sim, precisamos resolver isso logo. O cliente está ansioso pelo resultado.
Pessoa 1: Concordo. Vou preparar uma lista de tarefas para gente organizar melhor.
Pessoa 2: Ótima ideia! Vamos nos reunir amanhã de manhã para discutir os detalhes.
Pessoa 1: Perfeito! Ajudar a ter tudo preparado para sexta-feira.
Pessoa 2: Combinado então!''';
  }

  String _generateDemoSummary(String text) {
    return '''Resumo da Reunião:

Os participantes discutiram sobre o projeto que precisa ser entregue na próxima semana. Foi acordado que uma lista de tarefas será preparada para organizar melhor o trabalho. Uma reunião foi agendada para amanhã de manhã para entrar nos detalhes, com objetivo de ter tudo preparado até sexta-feira.''';
  }

  List<String> _generateDemoActionItems(String text) {
    return [
      'Preparar lista de tarefas para o projeto',
      'Reunião amanhã de manhã para discutir detalhes',
      'Finalizar entrega até sexta-feira',
      'Entrar em contato com o cliente sobre o progresso',
    ];
  }

  List<WordTimestamp> _generateWordTimestamps(String text) {
    final words = text.split(' ');
    final timestamps = <WordTimestamp>[];
    var startMs = 0;
    
    for (var i = 0; i < words.length; i++) {
      final wordDuration = (words[i].length * 50).clamp(100, 300);
      timestamps.add(WordTimestamp(
        word: words[i],
        startTime: Duration(milliseconds: startMs),
        endTime: Duration(milliseconds: startMs + wordDuration),
        confidence: 0.9,
      ));
      startMs += wordDuration + 50;
    }
    
    return timestamps;
  }

  List<SpeakerSegment> _generateSpeakerSegments(String text) {
    return [
      SpeakerSegment(
        speakerId: 'speaker_1',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 15),
        text: 'Olá, tudo bem com você?',
      ),
      SpeakerSegment(
        speakerId: 'speaker_2',
        startTime: const Duration(seconds: 15),
        endTime: const Duration(seconds: 30),
        text: 'Sim, muito bem! E com você?',
      ),
      SpeakerSegment(
        speakerId: 'speaker_1',
        startTime: const Duration(seconds: 30),
        endTime: const Duration(seconds: 60),
        text: 'Estou ótimo, obrigado por perguntar. Estava pensando sobre o projeto...',
      ),
    ];
  }

  /// Unload Whisper from memory
  Future<void> unloadWhisper() async {
    print('AI: Unloading Whisper');
  }

  /// Unload LLM from memory
  Future<void> unloadLLM() async {
    print('AI: Unloading LLM');
  }
}
