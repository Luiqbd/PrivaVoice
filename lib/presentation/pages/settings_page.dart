import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../injection_container.dart';
import '../blocs/transcription/transcription_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ajustes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // AI Settings Section
              _buildSectionHeader('Inteligência Artificial'),
              _buildSettingsTile(
                icon: Icons.mic,
                title: 'Modelo de Transcrição',
                subtitle: 'Whisper Base',
                onTap: () => _showModelSelector(context),
              ),
              _buildSettingsTile(
                icon: Icons.people,
                title: 'Diarização',
                subtitle: 'Identificar locutores',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppColors.primaryAccent,
                ),
              ),
              _buildSettingsTile(
                icon: Icons.summarize,
                title: 'Resumo Automático',
                subtitle: 'Gerar resumo com IA',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppColors.primaryAccent,
                ),
              ),
              _buildSettingsTile(
                icon: Icons.task_alt,
                title: 'Extrair Ações',
                subtitle: 'Identificar tarefas a fazer',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppColors.primaryAccent,
                ),
              ),

              const SizedBox(height: 24),

              // Recording Settings
              _buildSectionHeader('Gravação'),
              _buildSettingsTile(
                icon: Icons.high_quality,
                title: 'Qualidade',
                subtitle: 'Alta (128kbps)',
                onTap: () => _showQualitySelector(context),
              ),
              _buildSettingsTile(
                icon: Icons.save,
                title: 'Auto-Save',
                subtitle: 'Salvar a cada 30 segundos',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: AppColors.primaryAccent,
                ),
              ),

              const SizedBox(height: 24),

              // Security Settings
              _buildSectionHeader('Segurança'),
              _buildSettingsTile(
                icon: Icons.fingerprint,
                title: 'Biometria',
                subtitle: 'Proteger app com digital',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Criptografia',
                subtitle: 'AES-256 GCM',
                onTap: () {},
              ),

              const SizedBox(height: 24),

              // Storage Settings
              _buildSectionHeader('Armazenamento'),
              _buildSettingsTile(
                icon: Icons.folder,
                title: 'Local de Salvamento',
                subtitle: 'Memória interna',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.delete_sweep,
                title: 'Limpar Cache',
                subtitle: 'Libera espaço',
                onTap: () => _showClearCacheDialog(context),
              ),

              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader('Sobre'),
              _buildSettingsTile(
                icon: Icons.info,
                title: 'Versão',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                title: 'Privacidade',
                subtitle: '100% Offline',
                onTap: () {},
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryAccent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryAccent, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
        ),
        trailing: trailing ?? const Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showModelSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modelo de Transcrição',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionTile('Whisper Tiny', 'Mais rápido, menos preciso'),
            _buildOptionTile('Whisper Base', 'Equilibrado', isSelected: true),
            _buildOptionTile('Whisper Large', 'Mais preciso, mais lento'),
          ],
        ),
      ),
    );
  }

  void _showQualitySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qualidade de Gravação',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionTile('Baixa', '64 kbps'),
            _buildOptionTile('Média', '96 kbps'),
            _buildOptionTile('Alta', '128 kbps', isSelected: true),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Limpar Cache?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Isso irá remover arquivos temporários.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache limpo!')),
              );
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(String title, String subtitle, {bool isSelected = false}) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textTertiary),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primaryAccent)
          : null,
      onTap: () {},
    );
  }
}
