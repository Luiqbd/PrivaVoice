import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    try {
      final canAuth = await _auth.canCheckBiometrics;
      if (canAuth) {
        final didAuth = await _auth.authenticate(
          localizedReason: 'Autentique para acessar o Cofre',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        
        if (didAuth) {
          await HapticUtils.mediumImpact();
          setState(() => _isAuthenticated = true);
        }
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Cofre Seguro'),
        centerTitle: true,
      ),
      body: _isAuthenticated
          ? _buildUnlockedContent()
          : _buildLockedContent(),
    );
  }

  Widget _buildLockedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.primaryAccent, width: 2),
            ),
            child: Icon(
              _isAuthenticating ? Icons.fingerprint : Icons.lock,
              size: 60,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _isAuthenticating ? 'Autenticando...' : 'Cofre Bloqueado',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Use biometria para acessar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _authenticate,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Autenticar'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withOpacity(0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.folder_open, size: 60, color: AppColors.backgroundPrimary),
          ),
          const SizedBox(height: 32),
          Text(
            'Arquivos Protegidos',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Seus arquivos criptografados',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
