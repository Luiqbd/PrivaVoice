import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../domain/entities/transcription.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../blocs/transcription/transcription_event.dart';
import '../blocs/transcription/transcription_state.dart';

/// Transcription Detail Page with Karaoke Word-Level Highlighting
class TranscriptionDetailPage extends StatefulWidget {
  final String transcriptionId;
  
  const TranscriptionDetailPage({super.key, required this.transcriptionId});
  
  @override
  State<TranscriptionDetailPage> createState() => _TranscriptionDetailPageState();
}

class _TranscriptionDetailPageState extends State<TranscriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<TranscriptionBloc>().add(SelectTranscription(widget.transcriptionId));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Transcrição'),
        backgroundColor: AppColors.backgroundPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<TranscriptionBloc, TranscriptionState>(
        builder: (context, state) {
          if (state.selectedTranscription == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            );
          }
          
          final transcription = state.selectedTranscription!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  transcription.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                // Date & Duration
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(transcription.createdAt),
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(transcription.duration),
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Summary Card (from TinyLlama)
                if (transcription.summary != null) ...[
                  _buildSectionTitle('Resumo', Icons.summarize),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      transcription.summary!,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Action Items (from TinyLlama)
                if (transcription.actionItems != null && transcription.actionItems!.isNotEmpty) ...[
                  _buildSectionTitle('Action Items', Icons.task_alt),
                  const SizedBox(height: 8),
                  ...transcription.actionItems!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.tertiaryAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item, style: TextStyle(color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),
                ],
                
                // Speaker Diarization
                if (transcription.speakerSegments != null && transcription.speakerSegments!.isNotEmpty) ...[
                  _buildSectionTitle('Locutores', Icons.people),
                  const SizedBox(height: 8),
                  ...transcription.speakerSegments!.map((segment) => _buildSpeakerSegment(segment)),
                  const SizedBox(height: 24),
                ],
                
                // Karaoke Word-Level Transcript
                _buildSectionTitle('Transcrição', Icons.text_fields),
                const SizedBox(height: 8),
                _buildKaraokeText(transcription, state.currentWordIndex),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryAccent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.primaryAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSpeakerSegment(SpeakerSegment segment) {
    final speakerLabel = segment.speakerId == 'speaker_1' ? 'Participante 1' : 'Participante 2';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.secondaryAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                speakerLabel,
                style: TextStyle(
                  color: AppColors.secondaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(segment.endTime),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(segment.text, style: TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
  
  Widget _buildKaraokeText(Transcription transcription, int currentWordIndex) {
    return Wrap(
      children: List.generate(
        transcription.wordTimestamps.length,
        (index) {
          final word = transcription.wordTimestamps[index];
          final isActive = index == currentWordIndex;
          final isPast = index < currentWordIndex;
          
          return GestureDetector(
            onTap: () {
              HapticUtils.selectionClick();
              context.read<TranscriptionBloc>().add(SeekToWord(index));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive 
                    ? AppColors.primaryAccent.withOpacity(0.3)
                    : isPast 
                        ? AppColors.primaryAccent.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: isActive 
                    ? Border.all(color: AppColors.primaryAccent, width: 2)
                    : null,
              ),
              child: Text(
                word.word,
                style: TextStyle(
                  color: isActive 
                      ? AppColors.primaryAccent
                      : isPast 
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
