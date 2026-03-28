import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../../injection_container.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../blocs/transcription/transcription_event.dart';

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
  bool _isProcessing = false;
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
        
        // Auto-process if no transcription text
        if (transcription != null && transcription.text.isEmpty) {
          _processWithAI();
        }
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

  Future<void> _processWithAI() async {
    if (_transcription == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      debugPrint('TranscriptionDetailPage: Processing with AI...');
      final bloc = getIt<TranscriptionBloc>();
      
      bloc.add(ProcessAudio(
        audioPath: _transcription!.audioPath,
        title: _transcription!.title,
      ));
      
      // Wait for processing
      await Future.delayed(const Duration(seconds: 3));
      
      // Reload
      final repository = GetIt.instance<TranscriptionRepository>();
      final updated = await repository.getTranscriptionById(widget.transcriptionId);
      
      if (mounted) {
        setState(() {
          _transcription = updated;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('TranscriptionDetailPage: Processing error - $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString();
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
        title: const Text('Detalhes', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          if (_transcription != null && _transcription!.text.isEmpty && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppColors.primaryAccent),
              onPressed: _processWithAI,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent));
    }

    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryAccent),
            const SizedBox(height: 24),
            const Text('Processando com IA...', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Whisper transcrevendo + TinyLlama resumindo', style: TextStyle(color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error, color: AppColors.error, size: 48),
        const SizedBox(height: 16),
        Text('Erro: $_error', style: const TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    if (_transcription == null) {
      return const Center(child: Text('Gravação não encontrada', style: TextStyle(color: AppColors.textSecondary)));
    }

    return _buildContent(_transcription!);
  }

  Widget _buildContent(Transcription t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time, color: AppColors.textTertiary, size: 16),
            Text(' ${_formatDuration(t.duration)}', style: const TextStyle(color: AppColors.textTertiary)),
            const SizedBox(width: 16),
            const Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 16),
            Text(' ${_formatDate(t.createdAt)}', style: const TextStyle(color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 24),
          
          // AI Processing Button
          if (t.text.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryAccent.withOpacity(0.2), AppColors.secondaryAccent.withOpacity(0.2)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryAccent.withOpacity(0.5)),
              ),
              child: Column(children: [
                const Icon(Icons.auto_awesome, color: AppColors.primaryAccent, size: 40),
                const SizedBox(height: 12),
                const Text('Toque para processar com IA', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _processWithAI,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent, foregroundColor: Colors.white),
                ),
              ]),
            )
          else ...[
            // Transcription
            const Text('Transcrição', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Text(t.text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6))),
          ],

          // Summary
          if (t.summary != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.secondaryAccent.withOpacity(0.1), AppColors.tertiaryAccent.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.summarize, color: AppColors.secondaryAccent), const SizedBox(width: 8), const Text('Resumo', style: TextStyle(color: AppColors.secondaryAccent, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 12),
                Text(t.summary!, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              ]),
            ),
          ],

          // Action Items
          if (t.actionItems != null && t.actionItems!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Ações', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...t.actionItems!.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.secondaryAccent, width: 2)), child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: AppColors.secondaryAccent, fontSize: 12, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value, style: const TextStyle(color: AppColors.textSecondary))),
                ]),
              ),
            )),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
