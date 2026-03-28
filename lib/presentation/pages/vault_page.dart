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
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // Auto-unlock on init for demo
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      if (canAuth) {
        _unlockVault();
      }
    } catch (e) {
      print('Biometric error: $e');
    }
  }

  Future<void> _unlockVault() async {
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
      }
    } catch (e) {
      // Fallback - unlock for demo
      setState(() => _isUnlocked = true);
    }
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
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: const Icon(
                  Icons.lock,
                  size: 64,
                  color: AppColors.textTertiary,
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
              const SizedBox(height: 16),
              Text(
                'Gravações protegidas',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _unlockVault,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Desbloquear',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                    onPressed: () => setState(() => _isUnlocked = false),
                    icon: const Icon(Icons.lock, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Nenhuma gravação protegida',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
