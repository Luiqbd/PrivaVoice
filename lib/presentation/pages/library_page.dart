import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/transcription/transcription_state.dart';
import '../blocs/transcription/transcription_event.dart';
import '../../core/theme/app_colors.dart';
import '../../injection_container.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../widgets/transcription_card.dart';
import 'transcription_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> {
  late TranscriptionBloc _transcriptionBloc;

  @override
  void initState() {
    super.initState();
    _transcriptionBloc = getIt<TranscriptionBloc>();
    _transcriptionBloc.add(LoadTranscriptions());
  }

  @override
  void dispose() {
    _transcriptionBloc.close();
    super.dispose();
  }

  void refreshLibrary() {
    debugPrint('LibraryPage: Refreshing...');
    _transcriptionBloc.add(LoadTranscriptions());
  }

  void _openTranscription(String id) {
    debugPrint('LibraryPage: Opening transcription $id');
    _transcriptionBloc.add(SelectTranscription(id));
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _transcriptionBloc,
          child: TranscriptionDetailPage(transcriptionId: id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _transcriptionBloc,
      child: Scaffold(
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
                    IconButton(
                      onPressed: () {
                        _transcriptionBloc.add(LoadTranscriptions());
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: BlocBuilder<TranscriptionBloc, TranscriptionState>(
                  builder: (context, state) {
                    if (state.status == TranscriptionStatus.loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryAccent,
                        ),
                      );
                    }

                    if (state.transcriptions.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        _transcriptionBloc.add(LoadTranscriptions());
                      },
                      color: AppColors.primaryAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.transcriptions.length,
                        itemBuilder: (context, index) {
                          final transcription = state.transcriptions[index];
                          return TranscriptionCard(
                            transcription: transcription,
                            onTap: () => _openTranscription(transcription.id),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const Icon(
              Icons.mic_none,
              size: 40,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhuma gravação',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suas gravações aparecerão aqui',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _transcriptionBloc.add(LoadTranscriptions());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
