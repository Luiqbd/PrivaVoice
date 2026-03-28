import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_colors.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  bool _isUnlocked = false;
  bool _biometricsAvailable = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      setState(() {
        _biometricsAvailable = canAuth && isDeviceSupported;
      });
      print('Biometrics available: $_biometricsAvailable');
    } catch (e) {
      print('Biometric check error: $e');
      setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _unlockVault() async {
    if (!_biometricsAvailable) {
      // Fallback - unlock for demo if no biometrics
      setState(() => _isUnlocked = true);
      return;
    }

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Autentique para acessar o cofre',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        setState(() => _isUnlocked = true);
      } else {
        // Show message if auth failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autenticação falhou'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Auth error: $e');
      // Fallback
      setState(() => _isUnlocked = true);
    }
  }

  Future<void> _lockVault() async {
    setState(() => _isUnlocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockedState();
    }
    return _buildUnlockedState();
  }

  Widget _buildLockedState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.primaryAccent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.lock,
                  size: 64,
                  color: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Cofre Seguro',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _biometricsAvailable 
                    ? 'Suas gravações protegidas'
                    : 'Configure biometria nos ajustes',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              
              // Unlock Button
              GestureDetector(
                onTap: _unlockVault,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _biometricsAvailable ? Icons.fingerprint : Icons.lock_open,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _biometricsAvailable ? 'Desbloquear' : 'Acessar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (!_biometricsAvailable) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() => _isUnlocked = true),
                  child: const Text(
                    'Modo Demo: Acessar sem biometria',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedState() {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Text(
                    'Cofre',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _lockVault,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Protected files
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_special,
                      size: 64,
                      color: AppColors.textTertiary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma gravação protegida',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Moves gravações para o cofre para protegê-las',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
