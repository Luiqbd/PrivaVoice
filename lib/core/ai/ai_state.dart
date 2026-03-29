/// AI Engine State Machine
enum AIState {
  loading,    // Loading models
  ready,      // Ready to process
  processing, // Currently transcribing
  error,      // Error occurred
}

/// AI Manager with state machine
class AIManager {
  static AIState _state = AIState.loading;
  static String _lastError = '';
  static double _progress = 0.0;
  static String _statusMessage = 'Inicializando...';

  static AIState get state => _state;
  static String get lastError => _lastError;
  static double get progress => _progress;
  static String get statusMessage => _statusMessage;

  static bool get isReady => _state == AIState.ready;
  static bool get isProcessing => _state == AIState.processing;
  static bool get hasError => _state == AIState.error;

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
