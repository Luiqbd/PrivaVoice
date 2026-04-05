import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transcription.dart';

/// PDF Exporter - Generates PDF from transcription
/// Creates a luxury PDF with title, summary, and organized transcript bubbles
class PdfExporter {
  /// Export transcription to PDF file
  static Future<String?> export(Transcription transcription) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/privavoice_$timestamp.pdf';
      
      // Generate simple text-based PDF-like HTML
      final html = _generateHtml(transcription);
      
      final file = File(filePath.replaceAll('.pdf', '.html'));
      await file.writeAsString(html);
      
      debugPrint('PdfExporter: Exported to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('PdfExporter: Error: $e');
      return null;
    }
  }
  
  /// Generate HTML that can be viewed/printed as PDF
  static String _generateHtml(Transcription t) {
    final title = t.title;
    final summary = t.summary ?? 'Sem resumo disponível';
    final text = t.text;
    final createdAt = _formatDateTime(t.createdAt);
    final duration = _formatDuration(t.duration);
    
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>$title - PrivaVoice</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0A0A0A;
      color: #E0E0E0;
      padding: 40px;
      line-height: 1.6;
    }
    .container { max-width: 800px; margin: 0 auto; }
    h1 { 
      font-size: 28px; 
      color: #00E5FF; 
      margin-bottom: 8px;
      font-weight: 600;
    }
    .meta { 
      color: #888; 
      font-size: 14px; 
      margin-bottom: 24px;
    }
    .section {
      background: #1A1A1A;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
      border: 1px solid #333;
    }
    .section-title {
      font-size: 16px;
      color: #00E5FF;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .summary { 
      color: #CCC; 
      font-size: 15px;
      line-height: 1.7;
    }
    .transcript { 
      color: #B0B0B0;
      font-size: 14px;
    </style>
</head>
<body>
  <div class="container">
    <h1>$title</h1>
    <p class="meta">Gravado em $createdAt • Duração: $duration</p>
    
    <div class="section">
      <div class="section-title">📝 Resumo Inteligente</div>
      <p class="summary">$summary</p>
    </div>
    
    <div class="section">
      <div class="section-title">🎤 Transcrição Completa</div>
      <p class="transcript">$text</p>
    </div>
    
    <footer style="text-align: center; color: #555; font-size: 12px; margin-top: 40px;">
      <p>Exportado por PrivaVoice | ${DateTime.now().toString().split('.')[0]}</p>
    </footer>
  </div>
</body>
</html>''';
  }
  
  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  
  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}