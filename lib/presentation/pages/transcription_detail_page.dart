import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../blocs/transcription/transcription_state.dart';
import '../widgets/speaker_avatar.dart';

class TranscriptionDetailPage extends StatefulWidget {
  final String transcriptionId;
  
  const TranscriptionDetailPage({
    super.key,
    required this.transcriptionId,
  });

  @override
  State<TranscriptionDetailPage> createState() => _TranscriptionDetailPageState();
}

class _TranscriptionDetailPageState extends State<TranscriptionDetailPage> {
  Transcription? _transcription;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTranscription();
  }

  Future<void> _loadTranscription() async {
    try {
      debugPrint('TranscriptionDetailPage: Loading ${widget.transcriptionId}');
      final repository = GetIt.instance<TranscriptionRepository>();
      final transcription = await repository.getTranscriptionById(widget.transcriptionId);
      debugPrint('TranscriptionDetailPage: Got ${transcription?.title}');
      if (mounted) {
        setState(() {
          _transcription = transcription;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TranscriptionDetailPage: Error - $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalhes',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Erro: $_error',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_transcription == null) {
      return const Center(
        child: Text(
          'Gravação não encontrada',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return _buildContent(_transcription!);
  }

  Widget _buildContent(Transcription transcription) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            transcription.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Duration and date
          Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDuration(transcription.duration),
                style: const TextStyle(color: AppColors.textTertiary),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDate(transcription.createdAt),
                style: const TextStyle(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Audio file info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.audio_file,
                    color: AppColors.primaryAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arquivo de Áudio',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transcription.audioPath.split('/').last,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Transcription text
          const Text(
            'Transcrição',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          if (transcription.text.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textTertiary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Transcrição em processamento... Toque no botão para processar com IA.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transcription.text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),

          // Summary
          if (transcription.summary != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Resumo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transcription.summary!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // Action Items
          if (transcription.actionItems != null && transcription.actionItems!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Ações a Fazer',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...transcription.actionItems!.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.secondaryAccent, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: AppColors.secondaryAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
