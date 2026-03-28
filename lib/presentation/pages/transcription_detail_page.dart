import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../blocs/transcription/transcription_bloc.dart';
import '../blocs/transcription/transcription_event.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTranscription();
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
        
        if (t != null && t.text.isEmpty) {
          _processWithAI();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _processWithAI() async {
    if (_transcription == null || _isProcessing) return;
    
    setState(() { _isProcessing = true; });
    
    try {
      debugPrint('Processing with AI...');
      final bloc = getIt<TranscriptionBloc>();
      
      bloc.add(ProcessAudio(
        audioPath: _transcription!.audioPath,
        title: _transcription!.title,
      ));
      
      // Wait for bloc to process - check every 500ms
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final repo = GetIt.instance<TranscriptionRepository>();
        final updated = await repo.getTranscriptionById(widget.transcriptionId);
        if (updated != null && updated.text.isNotEmpty) {
          if (mounted) setState(() { _transcription = updated; _isProcessing = false; });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    
    if (mounted) setState(() { _isProcessing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Detalhes'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_isProcessing) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 24),
      const Text('Processando IA...', style: TextStyle(fontSize: 18)),
    ]));
    if (_error != null) return Center(child: Text('Erro: $_error'));
    if (_transcription == null) return const Center(child: Text('Não encontrado'));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_transcription!.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Duração: ${_transcription!.duration.inMinutes}:${(_transcription!.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
          const SizedBox(height: 24),
          
          if (_transcription!.text.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Icon(Icons.auto_awesome, size: 40),
                const SizedBox(height: 12),
                const Text('Toque para processar com IA'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _processWithAI, child: const Text('Iniciar')),
              ]),
            )
          else ...[
            const Text('Transcrição', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_transcription!.text, style: const TextStyle(height: 1.5)),
          ],
          
          if (_transcription!.summary != null) ...[
            const SizedBox(height: 24),
            const Text('Resumo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(_transcription!.summary!),
          ],
          
          if (_transcription!.actionItems != null && _transcription!.actionItems!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Ações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._transcription!.actionItems!.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ]),
            )),
          ],
        ],
      ),
    );
  }
}
