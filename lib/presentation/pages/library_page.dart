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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _transcriptionBloc = getIt<TranscriptionBloc>();
    _transcriptionBloc.add(LoadTranscriptions());
  }

  @override
  void dispose() {
    _searchController.dispose();
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

              // Search Field (Ciano Neon)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar notas...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryAccent),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryAccent, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryAccent, width: 2),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

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

                    // Filter by search query
                    final filteredTranscriptions = _searchQuery.isEmpty
                        ? state.transcriptions
                        : state.transcriptions.where((t) {
                            return t.title.toLowerCase().contains(_searchQuery);
                          }).toList();

                    if (filteredTranscriptions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum resultado para "$_searchQuery"',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        _transcriptionBloc.add(LoadTranscriptions());
                      },
                      color: AppColors.primaryAccent,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredTranscriptions.length,
                        itemBuilder: (context, index) {
                          final transcription = filteredTranscriptions[index];
                          return TranscriptionCard(
                            transcription: transcription,
                            onTap: () => _openTranscription(transcription.id),
                            onLongPress: () => _showOptionsMenu(context, transcription.id, transcription.title),
                            onDelete: () => _showDeleteConfirmation(context, transcription.id).then((confirm) {
                              if (confirm == true) {
                                _deleteTranscription(transcription.id, transcription.audioPath);
                              }
                            }),
                            onRename: () => _showRenameModal(context, transcription.id, transcription.title),
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

  Future<bool> _showDeleteConfirmation(BuildContext context, String id) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmar Exclusão',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Deseja apagar permanentemente esta inteligência?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apagar'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _deleteTranscription(String id, String audioPath) {
    // Delete from database and file system
    _transcriptionBloc.add(DeleteTranscription(id));
    // TODO: Delete audio file from filesystem
  }

  void _showRenameModal(BuildContext context, String id, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Renomear',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Novo título',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _transcriptionBloc.add(RenameTranscription(id, controller.text));
                Navigator.pop(context);
              }
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

  void _showOptionsMenu(BuildContext context, String id, String currentTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
