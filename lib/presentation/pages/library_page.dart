import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final recordings = List.generate(5, (index) => _RecordingItem(
      id: '$index',
      title: 'Gravação ${index + 1}',
      duration: Duration(minutes: index + 1, seconds: 30),
      date: DateTime.now().subtract(Duration(days: index)),
      hasTranscription: index % 2 == 0,
    ));

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Text(
                    'Biblioteca',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${recordings.length} gravações',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textTertiary),
                    SizedBox(width: 12),
                    Text(
                      'Buscar transcrições...',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recordings List
            Expanded(
              child: recordings.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: recordings.length,
                      itemBuilder: (context, index) => _buildRecordingCard(recordings[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music_outlined, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            'Nenhuma gravação ainda',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Suas transcrições aparecerão aqui',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(_RecordingItem recording) {
    final minutes = recording.duration.inMinutes;
    final seconds = recording.duration.inSeconds.remainder(60);
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          // Play Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: const Icon(Icons.play_arrow, color: AppColors.backgroundPrimary),
          ),
          
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      durationText,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(recording.date),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
                if (recording.hasTranscription) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '✓ Transcrita',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // More Options
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textTertiary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _RecordingItem {
  final String id;
  final String title;
  final Duration duration;
  final DateTime date;
  final bool hasTranscription;

  _RecordingItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.date,
    required this.hasTranscription,
  });
}
