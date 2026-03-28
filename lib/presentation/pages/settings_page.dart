import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSubscriptionCard(context),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Segurança',
            items: [
              _SettingsItem(
                icon: Icons.fingerprint,
                title: 'Biometria',
                subtitle: 'Proteção por impressão digital',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.lock,
                title: 'Bloqueio do App',
                subtitle: 'Exigir biometria ao abrir',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Armazenamento',
            items: [
              _SettingsItem(
                icon: Icons.storage,
                title: 'Gerenciar Modelos',
                subtitle: 'Baixar/remover modelos de IA',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.delete_outline,
                title: 'Limpar Cache',
                subtitle: '释放 espaço temporário',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Sobre',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'Versão',
                subtitle: AppConstants.appVersion,
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: 'Termos de Uso',
                subtitle: 'Leia nossos termos',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacidade',
                subtitle: 'Nossa política de privacidade',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryAccent.withOpacity(0.2),
            AppColors.secondaryAccent.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '50% OFF',
                  style: TextStyle(
                    color: AppColors.backgroundPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.star, color: AppColors.primaryAccent, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'PrivaVoice Premium',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${AppConstants.discountedPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/mês',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'De R\$ ${AppConstants.monthlyPrice.toStringAsFixed(2)}/mês',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Testar Grátis por 7 Dias'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<_SettingsItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primaryAccent,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.map((item) => item).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}
