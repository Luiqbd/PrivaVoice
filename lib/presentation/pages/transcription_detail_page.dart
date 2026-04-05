import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/services/ai_service.dart';
import '../../core/ai/ai_state.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';

class TranscriptionDetailPage extends StatefulWidget {
  final String transcriptionId;
  const TranscriptionDetailPage({super.key, required this.transcriptionId});

  @override
  State<TranscriptionDetailPage> createState() => _TranscriptionDetailPageState();
}

class _TranscriptionDetailPageState extends State<TranscriptionDetailPage> {
  Transcription? _transcription;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _activeSpeakerIndex = -1;
  
  // Notes functionality
  final TextEditingController _notesController = TextEditingController();
  bool _isSavingNotes = false;
  Timer? _notesSaveTimer;
  
  // Playback speed control
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [1.0, 1.25, 1.5, 2.0];
  
  // Timer for auto-refreshing transcription while AI processes
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTranscription();
    _setupAudioPlayer();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    // Refresh transcription more frequently while AI is processing (every 1 second)
    // Also add timeout to stop after 5 minutes
    var refreshCount = 0;
    const maxRefreshes = 300; // 5 minutes max
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      refreshCount++;
      
      // Timeout after 5 minutes - stop processing indicator
      if (refreshCount > maxRefreshes) {
        debugPrint('TranscriptionDetailPage: TIMEOUT - stopping processing indicator');
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        timer.cancel();
        return;
      }
      
      if (_isProcessing && _transcription != null) {
        debugPrint('TranscriptionDetailPage: Auto-refresh...');
        try {
          final repo = GetIt.instance<TranscriptionRepository>();
          final updated = await repo.getTranscriptionById(_transcription!.id);
          if (updated != null && mounted) {
            // Update UI even if still processing - show partial results
            if (updated.text != _transcription!.text) {
              debugPrint('TranscriptionDetailPage: Text changed! Updating UI...');
              setState(() {
                _transcription = updated;
              });
            }
            // Check if processing is complete (text is not empty and not "Processando...")
            if (updated.text.isNotEmpty && updated.text != 'Processando...') {
              debugPrint('TranscriptionDetailPage: AI finished! Text: ${updated.text.substring(0, updated.text.length > 50 ? 50 : updated.text.length)}...');
              setState(() {
                _isProcessing = false;
              });
              timer.cancel();
            }
          }
        } catch (e) {
          debugPrint('TranscriptionDetailPage: Refresh error: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
        _updateActiveSpeaker(position);
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _totalDuration = duration);
      }
    });
  }

  void _updateActiveSpeaker(Duration position) {
    if (_transcription?.speakerSegments == null) return;

    for (int i = 0; i < _transcription!.speakerSegments!.length; i++) {
      final segment = _transcription!.speakerSegments![i];
      if (position >= segment.startTime && position <= segment.endTime) {
        if (_activeSpeakerIndex != i) {
          setState(() => _activeSpeakerIndex = i);
        }
        return;
      }
    }
  }

  Future<void> _seekToSegment(SpeakerSegment segment) async {
    await _audioPlayer.seek(segment.startTime);
    if (!_isPlaying) {
      await _audioPlayer.play();
    }
  }

  Future<void> _loadTranscription() async {
    try {
      final repo = GetIt.instance<TranscriptionRepository>();
      final t = await repo.getTranscriptionById(widget.transcriptionId);

      if (mounted) {
        setState(() {
          _transcription = t;
          _isLoading = false;
        });

        // Load notes if available
        if (t != null && t.notes != null) {
          _notesController.text = t.notes!;
        }

        if (t != null && File(t.audioPath).existsSync()) {
          await _audioPlayer.setFilePath(t.audioPath);
          
          // Auto-start AI if text is still "Processando..."
          if (t.text == 'Processando...') {
            debugPrint('xxx AUTO-STARTING AI...');
            _processWithAI();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Save notes with debounce (wait 1 second after user stops typing)
  void _saveNotesDebounced(String value) {
    _notesSaveTimer?.cancel();
    _notesSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveNotes(value);
    });
  }

  Future<void> _saveNotes(String notes) async {
    if (_transcription == null) return;
    
    setState(() => _isSavingNotes = true);
    
    try {
      final repo = GetIt.instance<TranscriptionRepository>();
      
      // Update transcription with new notes
      final updatedTranscription = Transcription(
        id: _transcription!.id,
        title: _transcription!.title,
        audioPath: _transcription!.audioPath,
        text: _transcription!.text,
        wordTimestamps: _transcription!.wordTimestamps,
        createdAt: _transcription!.createdAt,
        duration: _transcription!.duration,
        isEncrypted: _transcription!.isEncrypted,
        speakerSegments: _transcription!.speakerSegments,
        summary: _transcription!.summary,
        actionItems: _transcription!.actionItems,
        notes: notes,
      );
      
      await repo.saveTranscription(updatedTranscription);
      debugPrint('Notes saved successfully!');
      
      // Update local state
      _transcription = updatedTranscription;
    } catch (e) {
      debugPrint('Error saving notes: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingNotes = false);
      }
    }
  }

  Future<void> _processWithAI() async {
    if (_transcription == null || _isProcessing) return;

    debugPrint('xxx STARTING AI PROCESSING xxx');
    debugPrint('xxx Audio: ${_transcription!.audioPath}');
    debugPrint('xxx BEFORE setState');
    setState(() {
      _isProcessing = true;
      _currentStage = 'Iniciando...';
    });
    debugPrint('xxx AFTER setState');
    
    // Start real-time progress tracking
    _startProgressTracking();

    // Wrap AI call in try-catch to prevent UI crash
    // Player will stay visible even if AI fails
    try {
      debugPrint('xxx CALLING AIService.processAudio');
      
      final result = await AIService.processAudio(
        audioPath: _transcription!.audioPath,
        title: _transcription!.title,
        onProgress: (prog, status) {
          // Real-time callback - update partial text while processing
          if (mounted) {
            setState(() {
              _currentStage = status;
            });
          }
        },
      );

      if (result == null) {
        // AI returned null - show error but keep player visible
        debugPrint('TranscriptionDetailPage: AI returned null');
        if (mounted) {
          setState(() {
            _error = 'IA retornou nulo - erro no processamento';
            _isProcessing = false;
          });
        }
        return;
      }

      debugPrint('TranscriptionDetailPage: AI returned text: ${result.text.substring(0, result.text.length > 50 ? 50 : result.text.length)}...');

      final finalResult = Transcription(
        id: _transcription!.id,  // Use EXACT same ID from the existing record
        title: _transcription!.title,
        audioPath: _transcription!.audioPath,
        text: result.text,
        wordTimestamps: result.wordTimestamps,
        createdAt: _transcription!.createdAt,
        duration: _transcription!.duration,
        isEncrypted: result.isEncrypted,
        speakerSegments: result.speakerSegments,
        summary: result.summary,
        actionItems: result.actionItems,
      );

      debugPrint('TranscriptionDetailPage: Saving with ID: ${finalResult.id}');
      
      final repo = GetIt.instance<TranscriptionRepository>();
      await repo.saveTranscription(finalResult);

      debugPrint('TranscriptionDetailPage: Saved, now reloading...');
      final updated = await repo.getTranscriptionById(_transcription!.id);

      debugPrint('TranscriptionDetailPage: Reloaded! Text: ${updated?.text.substring(0, 50) ?? "NULL"}...');

      if (mounted) {
        setState(() {
          _transcription = updated;
          _isProcessing = false;
        });
        _progressTimer?.cancel(); // Stop progress tracking
        debugPrint('TranscriptionDetailPage: UI updated!');
      }
    } catch (e) {
      // Catch any AI error and keep player visible
      // Don't let AI errors crash the UI
      debugPrint('TranscriptionDetailPage: AI Error (caught): $e');
      if (mounted) {
        setState(() {
          _error = 'Erro na IA: ${e.toString()}';
          _isProcessing = false;
        });
        _progressTimer?.cancel(); // Stop progress tracking
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _progressTimer?.cancel();
    _notesSaveTimer?.cancel();
    _notesController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Real-time progress tracking
  Timer? _progressTimer;
  double _currentProgress = 0.0;
  DateTime? _startTime;
  String _currentStage = 'Iniciando...';

  void _startProgressTracking() {
    _startTime = DateTime.now();
    _currentProgress = 0.0;
    
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_isProcessing) {
        _progressTimer?.cancel();
        return;
      }
      
      // Update progress from AIManager
      setState(() {
        _currentProgress = AIManager.progress;
        
        // Map status to stage messages
        final status = AIManager.statusMessage.toLowerCase();
        if (status.contains('carregando')) {
          _currentStage = 'Carregando modelo...';
        } else if (status.contains('preparando')) {
          _currentStage = 'Preparando IA...';
        } else if (status.contains('processando') || status.contains('transcrevendo')) {
          _currentStage = 'Transcrevendo áudio...';
        } else if (status.contains('voz') || status.contains('speaker')) {
          _currentStage = 'Identificando vozes...';
        } else if (status.contains('sincroniz') || status.contains('texto')) {
          _currentStage = 'Sincronizando texto...';
        } else if (status.contains('pronto') || status.contains('completo')) {
          _currentStage = 'Finalizando...';
        } else {
          _currentStage = AIManager.statusMessage.isNotEmpty 
              ? AIManager.statusMessage 
              : 'Processando...';
        }
      });
    });
  }

  String _formatRemainingTime() {
    if (_startTime == null || _currentProgress <= 0) return '--:--';
    
    // Estimate remaining time based on progress
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    if (elapsed < 5) return 'Calculando...';
    
    final totalEstimated = elapsed / _currentProgress;
    final remaining = (totalEstimated - elapsed).round();
    
    if (remaining < 60) {
      return '0:${remaining.toString().padLeft(2, '0')}';
    } else {
      final minutes = remaining ~/ 60;
      final seconds = remaining % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Build processing status indicator (real-time UX)
  Widget _buildProcessingIndicator() {
    if (!_isProcessing) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAccent.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage message
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _currentStage,
                style: const TextStyle(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Linear Progress with Cyan Glow
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _currentProgress.clamp(0.0, 1.0),
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress percentage and countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_currentProgress * 100).toInt()}%',
                style: TextStyle(
                  color: AppColors.primaryAccent.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.primaryAccent.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Finalizando em ${_formatRemainingTime()}',
                    style: TextStyle(
                      color: AppColors.primaryAccent.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<Color> speakerColors = [
    Color(0xFF00FFFF),  // Cyan - P1
    Color(0xFFFF00FF),   // Magenta - P2
    Color(0xFF8B5CF6),   // Violet - P3
    Color(0xFF84CC16),   // Lime - P4
    Color(0xFFFF6B6B),   // Coral - P5
  ];

  Color _getSpeakerColor(int index) {
    return speakerColors[index % speakerColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _transcription?.title ?? 'Transcricao',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryAccent),
      );
    }

    if (_transcription == null) {
      return const Center(child: Text('Nao encontrado'));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildTimeline(),
          ),
        ),
        _buildAudioPlayerBar(),
      ],
    );
  }

  Widget _buildTimeline() {
    if (_transcription!.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_transcription!.speakerSegments == null ||
        _transcription!.speakerSegments!.isEmpty) {
      return _buildPlainTextView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Linha do Tempo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _transcription!.speakerSegments!.length,
          (index) {
            final segment = _transcription!.speakerSegments![index];
            final isActive = _activeSpeakerIndex == index && _isPlaying;
            return _buildSpeakerBubble(segment, index, isActive);
          },
        ),
        const SizedBox(height: 24),
        
        // Show "Generate Summary" button if no summary yet
        if (_transcription!.summary == null || _transcription!.summary!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _generateSummary(),
              icon: _isProcessing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.summarize),
              label: Text(_isProcessing ? 'Gerando resumo...' : 'Gerar Resumo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        
        // Show summary if available
        if (_transcription!.summary != null && _transcription!.summary!.isNotEmpty) ...[
          _buildSection(
              'Resumo', Icons.summarize, AppColors.secondaryAccent, _transcription!.summary!),
          const SizedBox(height: 16),
        ],
        if (_transcription!.actionItems != null &&
            _transcription!.actionItems!.isNotEmpty) ...[
          const Text('Action Items',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._transcription!.actionItems!.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondaryAccent),
                    ),
                    child: const Icon(Icons.check,
                        size: 14, color: AppColors.secondaryAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(color: AppColors.textSecondary))),
                ],
              ),
            ),
          ),
        ],
        
        // Notas Section
        const SizedBox(height: 24),
        _buildNotesSection(),
      ],
    );
  }
  
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt, color: AppColors.primaryAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Minhas Notas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isSavingNotes)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 5,
            style: const TextStyle(color: AppColors.textSecondary),
            decoration: InputDecoration(
              hintText: 'Adicione suas anotações aqui...',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _saveNotesDebounced(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerBubble(SpeakerSegment segment, int index, bool isActive) {
    final color = _getSpeakerColor(index);
    // Use custom name if available, otherwise "Voz 1", "Voz 2", etc.
    final speakerId = segment.speakerId;
    final displayName = _transcription?.getSpeakerDisplayName(speakerId) ?? 'Voz ${index + 1}';
    final timeStr = _formatDuration(segment.startTime);
    
    // Allow editing speaker name on tap (only for voice 2)
    void Function()? onSpeakerTap;
    if (index == 0) {
      // Voice 1 is locked - tap to seek
      onSpeakerTap = () => _seekToSegment(segment);
    } else if (index == 1) {
      // Voice 2 can be edited
      onSpeakerTap = () => _showSpeakerEditDialog(speakerId);
    } else {
      onSpeakerTap = () => _seekToSegment(segment);
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              // Avatar com Glow Neon pulsante
              GestureDetector(
                onTap: onSpeakerTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(
                      color: color,
                      width: isActive ? 3 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(color: color.withOpacity(0.8), blurRadius: 20, spreadRadius: 3),
                            BoxShadow(color: color.withOpacity(0.5), blurRadius: 40, spreadRadius: 8),
                            BoxShadow(color: color.withOpacity(0.3), blurRadius: 60, spreadRadius: 12),
                          ]
                        : [
                            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
                          ],
                  ),
                  child: Center(
                    child: Text(
                      // Show only voice number in circle: "Voz 1", "Voz 2"
                      'Voz ${index + 1}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: isActive
                            ? [Shadow(color: color, blurRadius: 8)]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _seekToSegment(segment),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // Glassmorphism com contraste alto
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(
                    color: isActive ? color.withOpacity(0.9) : color.withOpacity(0.4),
                    width: isActive ? 2.5 : 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
                          BoxShadow(color: color.withOpacity(0.2), blurRadius: 32, spreadRadius: 4),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.5)),
                      ),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Texto com efeito karaoke - destaca palavras conforme reproduz
                    _buildKaraokeText(segment, isActive),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Karaoke effect - highlight words being spoken based on time
  Widget _buildKaraokeText(SpeakerSegment segment, bool isActive) {
    if (segment.text.isEmpty) return const SizedBox.shrink();
    
    final words = segment.text.split(' ');
    final segmentDuration = segment.endTime - segment.startTime;
    final now = _currentPosition;
    final color = _getSpeakerColor(_transcription!.speakerSegments!.indexOf(segment));
    
    // Calculate which word should be highlighted
    int highlightedIndex = -1;
    if (isActive && now >= segment.startTime && now <= segment.endTime) {
      final progress = (now - segment.startTime).inMilliseconds / segmentDuration.inMilliseconds;
      highlightedIndex = (progress * words.length).floor().clamp(0, words.length - 1);
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(words.length, (index) {
        final isHighlighted = index == highlightedIndex && isActive;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: isHighlighted ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
          decoration: isHighlighted
              ? BoxDecoration(
                  color: color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            words[index],
            style: TextStyle(
              color: isHighlighted ? Colors.white : Colors.white.withOpacity(0.95),
              fontSize: 15,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w400,
              height: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPlainTextView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Transcricao',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isProcessing) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Transcrevendo...',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surface.withOpacity(0.6),
            border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
          ),
          child: Text(
            _transcription!.text,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primaryAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _isProcessing 
                ? 'Transcrevendo...'
                : 'Toque para transcrever com IA',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const CircularProgressIndicator(color: AppColors.primaryAccent)
          else
            ElevatedButton(
              onPressed: _processWithAI,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
              child: const Text('Transcrever'),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          // Glassmorphism effect
          color: AppColors.surface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryAccent.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryAccent.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress slider - thicker and neon cyan
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,  // Thicker
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                activeTrackColor: const Color(0xFF00FFFF),  // Neon Ciano
                inactiveTrackColor: AppColors.textTertiary.withOpacity(0.3),
                thumbColor: const Color(0xFF00FFFF),
                overlayColor: const Color(0xFF00FFFF).withOpacity(0.2),
              ),
              child: Slider(
                // SECURITY: Clamp value to prevent "value > max" error
                value: _currentPosition.inMilliseconds.toDouble().clamp(0.0, _totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                max: _totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
                onChanged: (value) {
                  // Validate value before seeking
                  if (_totalDuration.inMilliseconds > 0) {
                    final clampedValue = value.clamp(0.0, _totalDuration.inMilliseconds.toDouble());
                    _audioPlayer.seek(Duration(milliseconds: clampedValue.toInt()));
                  }
                },
              ),
            ),
            // Time labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_currentPosition),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(_formatDuration(_totalDuration),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            // Controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Replay from start
                IconButton(
                  icon: const Icon(Icons.replay, color: AppColors.textSecondary, size: 28),
                  onPressed: () async {
                    await _audioPlayer.seek(Duration.zero);
                  },
                ),
                // Rewind 10s
                IconButton(
                  icon: const Icon(Icons.replay_10, color: AppColors.textSecondary, size: 28),
                  onPressed: () async {
                    final newPos = _currentPosition - const Duration(seconds: 10);
                    await _audioPlayer.seek(newPos.isNegative ? Duration.zero : newPos);
                  },
                ),
                // Play/Pause
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00FFFF),
                        const Color(0xFF00FFFF).withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFFF).withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.backgroundPrimary,
                      size: 36,
                    ),
                    onPressed: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        await _audioPlayer.play();
                      }
                    },
                  ),
                ),
                // Forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10, color: AppColors.textSecondary, size: 28),
                  onPressed: () async {
                    final newPos = _currentPosition + const Duration(seconds: 10);
                    if (newPos < _totalDuration) {
                      await _audioPlayer.seek(newPos);
                    }
                  },
                ),
                // Go to end
                IconButton(
                  icon: const Icon(Icons.last_page, color: AppColors.textSecondary, size: 28),
                  onPressed: () async {
                    await _audioPlayer.seek(_totalDuration);
                  },
                ),
                // Speed button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryAccent.withOpacity(0.5)),
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      final currentIndex = _speedOptions.indexOf(_playbackSpeed);
                      final nextIndex = (currentIndex + 1) % _speedOptions.length;
                      setState(() {
                        _playbackSpeed = _speedOptions[nextIndex];
                      });
                      await _audioPlayer.setSpeed(_playbackSpeed);
                      debugPrint('Playback speed: $_playbackSpeed');
                    },
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSpeakerEditDialog(String speakerId) {
    final currentName = _transcription?.getSpeakerDisplayName(speakerId) ?? 'Voz';
    final controller = TextEditingController(text: currentName.replaceFirst('Voz ', ''));
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Editar Locutor',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite o nome do locutor:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ex: Dr. Ricardo',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryAccent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                // Save to database
                _saveSpeakerName(speakerId, newName);
              }
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveSpeakerName(String speakerId, String newName) async {
    if (_transcription == null) return;
    try {
      final repo = GetIt.instance<TranscriptionRepository>();
      await repo.updateSpeakerName(_transcription!.id, speakerId, newName);
      // Reload transcription
      _loadTranscription();
    } catch (e) {
      debugPrint('Error saving speaker name: $e');
    }
  }
  
  /// Generate summary on-demand when user clicks button
  /// This loads Llama only when needed, preventing OOM
  Future<void> _generateSummary() async {
    if (_transcription == null || _transcription!.text.isEmpty) {
      debugPrint('Cannot generate summary: no transcription text');
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      debugPrint('Generating summary for: ${_transcription!.title}');
      
      // Use AIService to generate summary (pass text directly)
      final result = await AIService.generateSummary(
        transcriptionId: _transcription!.id,
        text: _transcription!.text,
      );
      
      if (result != null && result.summary != null && result.summary!.isNotEmpty) {
        // Update local transcription with new summary
        setState(() {
          _transcription = Transcription(
            id: _transcription!.id,
            title: _transcription!.title,
            audioPath: _transcription!.audioPath,
            text: _transcription!.text,
            wordTimestamps: _transcription!.wordTimestamps,
            createdAt: _transcription!.createdAt,
            duration: _transcription!.duration,
            isEncrypted: _transcription!.isEncrypted,
            speakerSegments: _transcription!.speakerSegments,
            summary: result.summary,
            actionItems: result.actionItems,
            notes: _transcription!.notes,
          );
        });
        
        // Save to database
        final repo = GetIt.instance<TranscriptionRepository>();
        await repo.saveTranscription(_transcription!);
        debugPrint('Summary saved successfully!');
      }
    } catch (e) {
      debugPrint('Error generating summary: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
