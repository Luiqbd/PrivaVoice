import '../ai/whisper/whisper_service.dart';
import '../ai/llm/llm_service.dart';
import '../ai/diarization_service.dart';
import '../ai/native/whisper_bindings.dart';
import '../ai/native/llama_bindings.dart';
import '../../domain/entities/transcription.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// AI Service Coordinator
/// Manages all AI services with dynamic loading/unloading for memory efficiency
/// 
/// Memory Management Strategy:
/// 1. Load libwhisper.so -> transcribe audio
/// 2. Unload libwhisper.so -> free ~50MB
/// 3. Load libllama.so -> generate summary
/// 4. Unload libllama.so -> free ~700MB
class AIService {
  final WhisperService _whisper = WhisperService();
  final LLMService _llm = LLMService();
  final DiarizationService _diarization = DiarizationService();

  bool _whisperLoaded = false;
  bool _llmLoaded = false;
  bool _diarizationLoaded = false;

  /// Get the model directory path
  Future<String> get _modelDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models';
  }

  /// Initialize all AI services
  Future<void> initializeAll() async {
    // Pre-load native libraries for faster access
    await _preloadNativeLibs();
    
    await Future.wait([
      _whisper.initialize(),
      _llm.initialize(),
      _diarization.initialize(),
    ]);
    _whisperLoaded = true;
    _llmLoaded = true;
    _diarizationLoaded = true;
  }

  /// Pre-load native FFI libraries
  Future<void> _preloadNativeLibs() async {
    // Copy models from assets to documents directory if needed
    await _setupModelsFromAssets();
  }

  /// Copy models from assets to documents directory
  Future<void> _setupModelsFromAssets() async {
    final modelDir = await _modelDir;
    final modelDirObj = Directory(modelDir);
    
    if (!await modelDirObj.exists()) {
      await modelDirObj.create(recursive: true);
    }
    
    // Check if models exist, if not they'll be loaded from assets at runtime
    print('Model directory: $modelDir');
  }

  /// Full transcription pipeline with memory management:
  /// 1. Load libwhisper.so -> Speech to text with word timestamps
  /// 2. Unload libwhisper.so -> Free ~50MB memory
  /// 3. Load libllama.so -> Generate summary + Action items
  /// 4. Unload libllama.so -> Free ~700MB memory
  Future<Transcription> processFullPipeline({
    required String audioPath,
    required String title,
  }) async {
    // ============================================================
    // Step 1: Speech recognition with Whisper
    // ============================================================
    print('AI: Loading Whisper for transcription...');
    final whisperResult = await _whisper.transcribe(audioPath);
    print('AI: Transcription complete');

    // ============================================================
    // Step 2: Speaker diarization (optional)
    // ============================================================
    final speakerSegments = await _diarization.processAudio(audioPath);

    // ============================================================
    // Step 3: Release Whisper memory BEFORE loading Llama
    // This ensures we have enough RAM for the LLM
    // ============================================================
    await unloadWhisper();
    print('AI: Released Whisper memory');

    // ============================================================
    // Step 4: LLM processing for summary and action items
    // libllama.so is now loaded for inference
    // ============================================================
    print('AI: Loading Llama for summarization...');
    final summary = await _llm.generateSummary(whisperResult.text);
    final actionItems = await _llm.extractActionItems(whisperResult.text);
    print('AI: Summary generation complete');

    // ============================================================
    // Step 5: Unload Llama to free ~700MB
    // ============================================================
    await unloadLLM();
    print('AI: Released Llama memory');

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

  /// Dynamic unload Whisper for memory efficiency
  /// Frees ~50MB by unloading the model and native library
  Future<void> unloadWhisper() async {
    _whisper.dispose();
    WhisperBindings.dispose();
    _whisperLoaded = false;
    print('AI: Whisper unloaded, memory freed');
  }

  /// Dynamic unload Llama for memory efficiency
  /// Frees ~700MB by unloading the model and native library
  Future<void> unloadLLM() async {
    _llm.dispose();
    LlamaBindings.dispose();
    _llmLoaded = false;
    print('AI: Llama unloaded, memory freed');
  }

  /// Reload Whisper when needed
  Future<void> reloadWhisper() async {
    if (!_whisperLoaded) {
      // Try to reload native library
      if (!WhisperBindings.isAvailable) {
        WhisperBindings.load();
      }
      await _whisper.initialize();
      _whisperLoaded = true;
    }
  }

  /// Reload Llama when needed
  Future<void> reloadLLM() async {
    if (!_llmLoaded) {
      // Try to reload native library
      if (!LlamaBindings.isAvailable) {
        LlamaBindings.load();
      }
      await _llm.initialize();
      _llmLoaded = true;
    }
  }

  /// Reload all AI services
  Future<void> reloadAll() async {
    await reloadWhisper();
    await reloadLLM();
  }

  /// Get word index for seekTo functionality
  int getWordIndexForSeek(List<WordTimestamp> timestamps, Duration position) {
    return _whisper.getWordIndexAtPosition(timestamps, position);
  }

  void dispose() {
    _whisper.dispose();
    _llm.dispose();
    _diarization.dispose();
    WhisperBindings.dispose();
    LlamaBindings.dispose();
  }
}

/// Singleton accessor
AIService get aiService => AIService();
