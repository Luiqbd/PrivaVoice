/// AI Engine State Machine - Com gestão de memória para 1.11GB
enum AIState {
  loading,        // Carregando modelos iniciais
  readyWhisper,   // Whisper pronto (transcrição)
  processing,    // Transcrevendo áudio
  loadingLlama,   // Carregando Llama (libertou Whisper)
  readyLlama,    // Llama pronto (chat)
  chatGenerating, // Gerando resposta
  error,         // Erro occurred
}

/// AI Manager com state machine e switch de memória
class AIManager {
  static AIState _state = AIState.loading;
  static String _lastError = '';
  static double _progress = 0.0;
  static String _statusMessage = 'Inicializando...';
  
  // Caminho do modelo Llama
  static String? _llamaModelPath;

  static AIState get state => _state;
  static String get lastError => _lastError;
  static double get progress => _progress;
  static String get statusMessage => _statusMessage;
  
  // Verificações de estado
  static bool get isReady => _state == AIState.readyWhisper || _state == AIState.readyLlama;
  static bool get isProcessing => _state == AIState.processing || _state == AIState.chatGenerating;
  static bool get hasError => _state == AIState.error;
  static bool get isWhisperReady => _state == AIState.readyWhisper;
  static bool get isLlamaReady => _state == AIState.readyLlama;
  static bool get canSendMessage => _state == AIState.readyLlama;

  /// Define o caminho do modelo Llama
  static void setLlamaPath(String path) {
    _llamaModelPath = path;
  }

  /// Troca de Whisper para Llama (libera RAM)
  /// IMPORTANTE: Deve ser chamado ANTES de carregar Llama
  static Future<bool> switchToChat(String modelPath) async {
    if (_state != AIState.readyWhisper && _state != AIState.processing) {
      print('AI: Estado inválido para switch. Estado atual: $_state');
      return false;
    }
    
    try {
      _state = AIState.loadingLlama;
      _statusMessage = 'Carregando IA...';
      print('AI: Mudando para loadingLlama (libertando Whisper...)');
      
      // Em Dart, signaliza para o Kotlin liberar
      // O KotlinWhisperBridge já é chamado pelo TranscriptionService
      // Aqui só mudamos o estado
      
      _llamaModelPath = modelPath;
      _state = AIState.readyLlama;
      _statusMessage = 'Priva Chat pronto';
      print('AI: Llama carregado! Estado: readyLlama');
      return true;
    } catch (e) {
      _state = AIState.error;
      _lastError = e.toString();
      _statusMessage = 'Erro ao carregar: $e';
      print('AI: Erro no switch: $e');
      return false;
    }
  }

  /// Volta para Whisper (libera Llama)
  static void switchToTranscribe() {
    if (_state != AIState.readyLlama) return;
    
    _state = AIState.readyWhisper;
    _statusMessage = 'Pronto para transcrever';
    print('AI: Voltou para Whisper');
  }

  static void setState(AIState newState, {String? message, double? progress}) {
    _state = newState;
    if (message != null) _statusMessage = message;
    if (progress != null) _progress = progress;
    print('AI State: $newState - $message');
  }

  static void setError(String error) {
    _state = AIState.error;
    _lastError = error;
    _statusMessage = 'Erro: $error';
    print('AI Error: $error');
  }

  static void reset() {
    _state = AIState.loading;
    _lastError = '';
    _progress = 0.0;
    _statusMessage = 'Inicializando...';
  }
}
