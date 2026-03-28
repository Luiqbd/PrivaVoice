import '../ai/whisper/whisper_service.dart';
import '../ai/llm/llm_service.dart';
import '../ai/diarization_service.dart';
import '../../domain/entities/transcription.dart';

/// AI Service Coordinator
/// Manages all AI services with dynamic loading/unloading for memory efficiency
class AIService {
  final WhisperService _whisper = WhisperService();
  final LLMService _llm = LLMService();
  final DiarizationService _diarization = DiarizationService();
  
  bool _whisperLoaded = false;
  bool _llmLoaded = false;
  bool _diarizationLoaded = false;
  
  /// Initialize all AI services
  Future<void> initializeAll() async {
    await Future.wait([
      _whisper.initialize(),
      _llm.initialize(),
      _diarization.initialize(),
    ]);
    _whisperLoaded = true;
    _llmLoaded = true;
    _diarizationLoaded = true;
  }
  
  /// Full transcription pipeline:
  /// 1. Whisper: Speech to text with word timestamps
  /// 2. Diarization: Speaker separation
  /// 3. TinyLlama: Summary + Action items
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
  }) async {
    // Step 1: Speech recognition with Whisper
    final whisperResult = await _whisper.transcribe(audioPath);
    
    // Step 2: Speaker diarization (optional)
    final speakerSegments = await _diarization.processAudio(audioPath);
    
    // Step 3: LLM processing for summary and action items
    final summary = await _llm.generateSummary(whisperResult.text);
    final actionItems = await _llm.extractActionItems(whisperResult.text);
    
    return Transcription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      audioPath: audioPath,
      text: whisperResult.text,
      wordTimestamps: whisperResult.wordTimestamps,
      createdAt: DateTime.now(),
      duration: whisperResult.duration,
      isEncrypted: true,
      speakerSegments: speakerSegments,
      summary: summary,
      actionItems: actionItems,
    );
  }
  
  /// Just transcribe (faster, no LLM processing)
  Future<TranscriptionResult> transcribeOnly(String audioPath) async {
    return await _whisper.transcribe(audioPath);
  }
  
  /// Dynamic unload for memory efficiency
  Future<void> unloadWhisper() async {
    _whisper.dispose();
    _whisperLoaded = false;
  }
  
  Future<void> unloadLLM() async {
    _llm.dispose();
    _llmLoaded = false;
  }
  
  Future<void> reloadAll() async {
    if (!_whisperLoaded) await _whisper.initialize();
    if (!_llmLoaded) await _llm.initialize();
    _whisperLoaded = true;
    _llmLoaded = true;
  }
  
  /// Get word index for seekTo functionality
  int getWordIndexForSeek(List<WordTimestamp> timestamps, Duration position) {
    return _whisper.getWordIndexAtPosition(timestamps, position);
  }
  
  void dispose() {
    _whisper.dispose();
    _llm.dispose();
    _diarization.dispose();
  }
}

/// Singleton accessor
AIService get aiService => AIService();
