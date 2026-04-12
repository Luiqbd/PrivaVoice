import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import '../native/llama_bindings.dart';
import 'system_prompts.dart';

/// TinyLlama 1.1B (4-bit quantized) NLP Service
/// Local processing for summaries and action items
/// Uses optimized system prompts for small model performance
class LLMService {
  static const String _modelName = 'tinyllama-1.1b-q4';
  static const String _llamaFileName = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  bool _isModelLoaded = false;
  Pointer<Void>? _ctx;

  /// Initialize TinyLlama model (quantized 4-bit ~700MB)
  Future<bool> initialize() async {
    if (_isModelLoaded && _ctx != null) return true;

    try {
      // Load native library
      final loaded = LlamaBindings.load();
      if (!loaded) {
        print('LLM: ❌ Failed to load libllama.so');
        return false;
      }

      // Find model path
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/models/$_llamaFileName';

      _ctx = LlamaBindings.initFromFile(modelPath);
      if (_ctx == null) {
        print('LLM: ❌ Failed to init model');
        return false;
      }

      _isModelLoaded = true;
      print('LLM: ✅ Model initialized');
      return true;
    } catch (e) {
      print('LLM: ❌ Init error: $e');
      return false;
    }
  }

  /// Generate structured summary from transcription
  /// Uses optimized system prompts for small model
  Future<LLMResult> generateSummary(String transcriptionText) async {
    if (!_isModelLoaded) {
      final ok = await initialize();
      if (!ok) {
        return LLMResult.error('Falha ao carregar modelo');
      }
    }

    // Use isolate for background processing
    final result = await Isolate.run(() async {
      try {
        final prompt = SystemPrompts.generateSummaryFull(transcriptionText);
        final llmResult = LlamaBindings.generate(
          ctx: Pointer<Void>.fromAddress(0), // Already loaded in service
          prompt: prompt,
        );

        if (llmResult == null) {
          return LLMResult.error('Falha na geração');
        }

        // Parse response - expect format:
        // TÍTULO: <title>
        // RESUMO: <summary>
        // AÇÕES:
        // 1. <action1>
        // 2. <action2>
        final text = llmResult['summary'] ?? llmResult['response'] ?? '';
        
        // Parse title
        String title = '';
        String summary = '';
        List<String> actions = [];
        
        final lines = text.split('\n');
        bool inActions = false;
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('TÍTULO:')) {
            title = trimmed.substring(7).trim();
          } else if (trimmed.startsWith('RESUMO:')) {
            summary = trimmed.substring(7).trim();
          } else if (trimmed == 'AÇÕES:' || trimmed == 'AÇÕES :' || trimmed.startsWith('AÇÕES')) {
            inActions = true;
          } else if (inActions && trimmed.isNotEmpty) {
            // Extract action text (remove "1. ", "2. " etc)
            final action = trimmed.replaceFirst(RegExp(r'^\d+\.\s*'), '');
            if (action.isNotEmpty) {
              actions.add(action);
            }
          }
        }

        return LLMResult.success(
          title: title.isEmpty ? 'Resumo' : title,
          summary: summary.isEmpty ? text : summary,
          actionItems: actions,
        );
      } catch (e) {
        return LLMResult.error('Erro: $e');
      }
    });

    return result;
  }

  /// Extract action items from transcription
  Future<LLMResult> extractActionItems(String transcriptionText) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    return await Isolate.run(() async {
      try {
        final prompt = SystemPrompts.generateActionItemsFull(transcriptionText);
        final llmResult = LlamaBindings.generate(
          ctx: Pointer<Void>.fromAddress(0),
          prompt: prompt,
        );

        if (llmResult == null) {
          return LLMResult.error('Falha na extração');
        }

        final text = llmResult['summary'] ?? llmResult['response'] ?? '';
        final actions = text
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => l.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList();

        return LLMResult.success(actionItems: actions);
      } catch (e) {
        return LLMResult.error('Erro: $e');
      }
    });
  }

  /// Analyze sentiment of transcription
  Future<LLMResult> analyzeSentiment(String text) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    return await Isolate.run(() async {
      try {
        final prompt = SystemPrompts.generateSentimentFull(text);
        final llmResult = LlamaBindings.generate(
          ctx: Pointer<Void>.fromAddress(0),
          prompt: prompt,
        );

        if (llmResult == null) {
          return LLMResult.error('Falha na análise');
        }

        final response = llmResult['summary'] ?? llmResult['response'] ?? '';
        
        Sentiment sentiment = Sentiment.neutral;
        String reason = '';
        
        if (response.toUpperCase().contains('POSITIVO')) {
          sentiment = Sentiment.positive;
          reason = response;
        } else if (response.toUpperCase().contains('NEGATIVO')) {
          sentiment = Sentiment.negative;
          reason = response;
        } else {
          reason = response;
        }

        return LLMResult.success(sentiment: sentiment, sentimentReason: reason);
      } catch (e) {
        return LLMResult.error('Erro: $e');
      }
    });
  }

  /// Question answering based on transcription
  Future<LLMResult> answerQuestion(String question, String context) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    return await Isolate.run(() async {
      try {
        final prompt = SystemPrompts.generateChatFull(context, question);
        final llmResult = LlamaBindings.generate(
          ctx: Pointer<Void>.fromAddress(0),
          prompt: prompt,
        );

        if (llmResult == null) {
          return LLMResult.error('Falha na resposta');
        }

        final response = llmResult['response'] ?? llmResult['summary'] ?? '';
        return LLMResult.success(response: response);
      } catch (e) {
        return LLMResult.error('Erro: $e');
      }
    });
  }

  /// Extract keywords from transcription
  Future<LLMResult> extractKeywords(String transcriptionText) async {
    if (!_isModelLoaded) {
      await initialize();
    }

    return await Isolate.run(() async {
      try {
        final prompt = SystemPrompts.generateKeywordsFull(transcriptionText);
        final llmResult = LlamaBindings.generate(
          ctx: Pointer<Void>.fromAddress(0),
          prompt: prompt,
        );

        if (llmResult == null) {
          return LLMResult.error('Falha na extração');
        }

        final response = llmResult['summary'] ?? llmResult['response'] ?? '';
        final keywords = response
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList();

        return LLMResult.success(keywords: keywords);
      } catch (e) {
        return LLMResult.error('Erro: $e');
      }
    });
  }

  /// Dynamic model loading/unloading for memory efficiency
  Future<void> unloadModel() async {
    if (_ctx != null) {
      LlamaBindings.unload();
      _ctx = null;
    }
    _isModelLoaded = false;
    print('LLM: Model unloaded');
  }

  Future<void> reloadModel() async {
    await initialize();
  }

  /// Dispose resources
  void dispose() {
    unloadModel();
  }
}

/// Sentiment analysis result
class SentimentAnalysis {
  final Sentiment sentiment;
  final double confidence;
  
  const SentimentAnalysis({
    required this.sentiment,
    required this.confidence,
  });
}

enum Sentiment { positive, negative, neutral }

/// Result from LLM processing
class LLMResult {
  final bool isError;
  final String? error;
  final String? title;
  final String? summary;
  final String? response;
  final List<String>? actionItems;
  final List<String>? keywords;
  final Sentiment? sentiment;
  final String? sentimentReason;

  const LLMResult._({
    required this.isError,
    this.error,
    this.title,
    this.summary,
    this.response,
    this.actionItems,
    this.keywords,
    this.sentiment,
    this.sentimentReason,
  });

  factory LLMResult.error(String message) {
    return LLMResult._(isError: true, error: message);
  }

  factory LLMResult.success({
    String? title,
    String? summary,
    String? response,
    List<String>? actionItems,
    List<String>? keywords,
    Sentiment? sentiment,
    String? sentimentReason,
  }) {
    return LLMResult._(
      isError: false,
      title: title,
      summary: summary,
      response: response,
      actionItems: actionItems,
      keywords: keywords,
      sentiment: sentiment,
      sentimentReason: sentimentReason,
    );
  }

  // Getters for convenient access
  String get titleOrDefault => title ?? 'Resumo';
  String get summaryOrResponse => summary ?? response ?? '';
  List<String> get actionItemsOrEmpty => actionItems ?? [];
  List<String> get keywordsOrEmpty => keywords ?? [];
}
