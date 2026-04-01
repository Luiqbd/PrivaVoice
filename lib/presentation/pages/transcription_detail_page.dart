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
    // Refresh transcription every 2 seconds while AI is processing
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isProcessing && _transcription != null) {
        debugPrint('TranscriptionDetailPage: Auto-refresh...');
        final repo = GetIt.instance<TranscriptionRepository>();
        final updated = await repo.getTranscriptionById(_transcription!.id);
        if (updated != null && updated.text != 'Processando...' && mounted) {
          debugPrint('TranscriptionDetailPage: AI finished! Text: ${updated.text.substring(0, updated.text.length > 50 ? 50 : updated.text.length)}...');
          setState(() {
            _transcription = updated;
            _isProcessing = false;
          });
          timer.cancel();
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

        if (t != null && File(t.audioPath).existsSync()) {
          await _audioPlayer.setFilePath(t.audioPath);
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _processWithAI() async {
    if (_transcription == null || _isProcessing) return;

    debugPrint('xxx STARTING AI PROCESSING xxx');\n    debugPrint('xxx Audio: ${_transcription!.audioPath}');
    debugPrint('xxx BEFORE setState'); setState(() => _isProcessing = true); debugPrint('xxx AFTER setState');

    try {
      debugPrint("xxx CALLING AIService.processAudio"); final result = await AIService.processAudio(
        audioPath: _transcription!.audioPath,
        title: _transcription!.title,
      );

      if (result == null) throw Exception('AI processing returned null');

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
        debugPrint('TranscriptionDetailPage: UI updated!');
      }
    } catch (e) {
      debugPrint('TranscriptionDetailPage: Error: $e');
      if (mounted) setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
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

    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryAccent),
            SizedBox(height: 24),
            Text('Processando IA...',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Erro: $_error',
              style: const TextStyle(color: AppColors.error)),
        ),
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
        if (_transcription!.summary != null) ...[
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
      ],
    );
  }

  Widget _buildSpeakerBubble(SpeakerSegment segment, int index, bool isActive) {
    final color = _getSpeakerColor(index);
    final initials = 'P${index + 1}';
    final timeStr = _formatDuration(segment.startTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              // Avatar com Glow Neon pulsante
              GestureDetector(
                onTap: () => _seekToSegment(segment),
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
                      initials,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                        initials,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Texto com alto contraste
                    Text(
                      segment.text,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainTextView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transcricao',
          style: TextStyle(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
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
          const Text(
            'Toque para processar com IA',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (_isProcessing)
            const CircularProgressIndicator(color: AppColors.primaryAccent)
          else
            ElevatedButton(
              onPressed: _processWithAI,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
              child: const Text('Iniciar Processamento'),
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
                value: _currentPosition.inMilliseconds.toDouble(),
                max: _totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
                onChanged: (value) {
                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
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
}