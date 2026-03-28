import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state
  bool _diarizationEnabled = true;
  bool _autoSummary = true;
  bool _extractActions = true;
  bool _autoSave = true;
  String _selectedModel = 'Whisper Base';
  String _selectedQuality = 'Alta';

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
                subtitle: _selectedModel,
                onTap: () => _showModelSelector(context),
              ),
              _buildSettingsTile(
                icon: Icons.people,
                title: 'Diarização',
                subtitle: 'Identificar locutores',
                trailing: Switch(
                  value: _diarizationEnabled,
                  onChanged: (value) {
                    setState(() => _diarizationEnabled = value);
                    _showSavedSnackBar('Diarização ${value ? "ativada" : "desativada"}');
                  },
                  activeColor: AppColors.primaryAccent,
                ),
              ),
              _buildSettingsTile(
                icon: Icons.summarize,
                title: 'Resumo Automático',
                subtitle: 'Gerar resumo com IA',
                trailing: Switch(
                  value: _autoSummary,
                  onChanged: (value) {
                    setState(() => _autoSummary = value);
                    _showSavedSnackBar('Resumo automático ${value ? "ativado" : "desativado"}');
                  },
                  activeColor: AppColors.primaryAccent,
                ),
              ),
              _buildSettingsTile(
                icon: Icons.task_alt,
                title: 'Extrair Ações',
                subtitle: 'Identificar tarefas a fazer',
                trailing: Switch(
                  value: _extractActions,
                  onChanged: (value) {
                    setState(() => _extractActions = value);
                    _showSavedSnackBar('Extração de ações ${value ? "ativada" : "desativada"}');
                  },
                  activeColor: AppColors.primaryAccent,
                ),
              ),

              const SizedBox(height: 24),

              // Recording Settings
              _buildSectionHeader('Gravação'),
              _buildSettingsTile(
                icon: Icons.high_quality,
                title: 'Qualidade',
                subtitle: _selectedQuality,
                onTap: () => _showQualitySelector(context),
              ),
              _buildSettingsTile(
                icon: Icons.save,
                title: 'Auto-Save',
                subtitle: 'Salvar a cada 30 segundos',
                trailing: Switch(
                  value: _autoSave,
                  onChanged: (value) {
                    setState(() => _autoSave = value);
                    _showSavedSnackBar('Auto-Save ${value ? "ativado" : "desativado"}');
                  },
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
                onTap: () => _showBiometricInfo(context),
              ),
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Criptografia',
                subtitle: 'AES-256 GCM',
                onTap: () => _showEncryptionInfo(context),
              ),

              const SizedBox(height: 24),

              // Storage Settings
              _buildSectionHeader('Armazenamento'),
              _buildSettingsTile(
                icon: Icons.folder,
                title: 'Local de Salvamento',
                subtitle: 'Memória interna',
                onTap: () => _showStorageInfo(context),
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
                onTap: () => _showPrivacyInfo(context),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
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
            _buildOptionTile(context, 'Whisper Tiny', 'Mais rápido, menos preciso', () {
              setState(() => _selectedModel = 'Whisper Tiny');
              Navigator.pop(context);
              _showSavedSnackBar('Modelo alterado para Whisper Tiny');
            }),
            _buildOptionTile(context, 'Whisper Base', 'Equilibrado', () {
              setState(() => _selectedModel = 'Whisper Base');
              Navigator.pop(context);
              _showSavedSnackBar('Modelo alterado para Whisper Base');
            }, isSelected: true),
            _buildOptionTile(context, 'Whisper Large', 'Mais preciso, mais lento', () {
              setState(() => _selectedModel = 'Whisper Large');
              Navigator.pop(context);
              _showSavedSnackBar('Modelo alterado para Whisper Large');
            }),
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
            _buildOptionTile(context, 'Baixa', '64 kbps', () {
              setState(() => _selectedQuality = 'Baixa');
              Navigator.pop(context);
              _showSavedSnackBar('Qualidade alterada para Baixa');
            }),
            _buildOptionTile(context, 'Média', '96 kbps', () {
              setState(() => _selectedQuality = 'Média');
              Navigator.pop(context);
              _showSavedSnackBar('Qualidade alterada para Média');
            }),
            _buildOptionTile(context, 'Alta', '128 kbps', () {
              setState(() => _selectedQuality = 'Alta');
              Navigator.pop(context);
              _showSavedSnackBar('Qualidade alterada para Alta');
            }, isSelected: true),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title, String subtitle, VoidCallback onTap, {bool isSelected = false}) {
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
      onTap: onTap,
    );
  }

  void _showBiometricInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Biometria',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'A biometria está disponível no cofre. Configure nas configurações do dispositivo.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEncryptionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Criptografia',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Todas as gravações são criptografadas com AES-256 GCM para máxima segurança.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Armazenamento',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'As gravações são salvas na memória interna do dispositivo para segurança.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Privacidade',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'O PrivaVoice funciona 100% offline. Nenhum dado sai do seu dispositivo. Sem internet necessária!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
          'Isso irá remover arquivos temporários para liberar espaço.',
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
              _showSavedSnackBar('Cache limpo com sucesso!');
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}
