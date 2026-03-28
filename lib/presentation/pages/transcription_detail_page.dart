import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transcription.dart';
import '../../injection_container.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../widgets/speaker_avatar.dart';

class TranscriptionDetailPage extends StatelessWidget {
  final String transcriptionId;
  
  const TranscriptionDetailPage({
    super.key,
    required this.transcriptionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TranscriptionBloc>()..add(SelectTranscription(transcriptionId))),
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: BlocBuilder<TranscriptionBloc, TranscriptionState>(
            builder: (context, state) {
              if (state.selectedTranscription == null) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryAccent),
                );
              }
              
              final transcription = state.selectedTranscription!;
              return _buildContent(context, transcription, state);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Transcription transcription, TranscriptionState state) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            transcription.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.textPrimary),
              onPressed: () {},
            ),
          ],
        ),

        // Speakers Section (Diarization)
        if (transcription.speakerSegments != null && transcription.speakerSegments!.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSpeakersSection(transcription.speakerSegments!),
          ),

        // Transcription Text
        SliverToBoxAdapter(
          child: _buildTranscriptionText(transcription),
        ),

        // Summary Section
        if (transcription.summary != null)
          SliverToBoxAdapter(
            child: _buildSummarySection(transcription.summary!),
          ),

        // Action Items
        if (transcription.actionItems != null && transcription.actionItems!.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildActionItemsSection(transcription.actionItems!),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildSpeakersSection(List<SpeakerSegment> segments) {
    // Get unique speakers
    final speakers = segments.map((s) => s.speakerId).toSet().toList();
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Locutores Identificados',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: speakers.map((speaker) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    SpeakerAvatar(
                      speakerId: speaker,
                      isActive: false,
                      size: 56,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getSpeakerName(speaker),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getSpeakerName(String speakerId) {
    final speakerNum = int.tryParse(speakerId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return 'Pessoa $speakerNum';
  }

  Widget _buildTranscriptionText(Transcription transcription) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transcrição',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (transcription.speakerSegments != null && transcription.speakerSegments!.isNotEmpty)
            _buildDiarizedText(transcription.speakerSegments!)
          else
            Text(
              transcription.text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiarizedText(List<SpeakerSegment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SpeakerAvatar(
                speakerId: segment.speakerId,
                isActive: false,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSpeakerName(segment.speakerId),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      segment.text,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(segment.startTime),
                      style: TextStyle(
                        color: AppColors.textTertiary.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummarySection(String summary) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize,
                  color: AppColors.primaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resumo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemsSection(List<String> actionItems) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.task_alt,
                  color: AppColors.secondaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ações a Fazer',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...actionItems.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
