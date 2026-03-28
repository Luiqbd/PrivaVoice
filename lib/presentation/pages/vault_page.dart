import 'package:flutter/material.dart';
import '../../core/utils/haptic_utils.dart';
import 'package:flutter/services.dart';
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
  bool _isAuthenticating = false;
  final LocalAuthentication _auth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();
  
  // Demo PIN
  static const String _demoPIN = '1234';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      setState(() {
        _biometricsAvailable = canAuth && isDeviceSupported;
      });
      debugPrint('Biometrics available: $_biometricsAvailable');
    } catch (e) {
      debugPrint('Biometric check error: $e');
      setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    try {
      debugPrint('Starting biometric authentication...');
      
      final authenticated = await _auth.authenticate(
        localizedReason: 'Autentique para acessar o cofre',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
      
      debugPrint('Biometric auth result: $authenticated');
      
      if (authenticated) {
        setState(() => _isUnlocked = true);
        HapticUtils.mediumImpact();
      } else {
        _showAuthFailedSnackBar();
      }
    } catch (e) {
      debugPrint('Auth error: $e');
      _showAuthFailedSnackBar();
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  void _authenticateWithPIN() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildPINSheet(),
    );
  }

  Widget _buildPINSheet() {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Digite o código PIN',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.textTertiary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryAccent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_pinController.text == _demoPIN) {
                  Navigator.pop(context);
                  setState(() => _isUnlocked = true);
                  _pinController.clear();
                  _showSuccessSnackBar('Cofre desbloqueado!');
                } else {
                  _showErrorSnackBar('PIN incorreto');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Desbloquear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthFailedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autenticação falhou ou cancelada'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _lockVault() async {
    setState(() => _isUnlocked = false);
    HapticUtils.lightImpact();
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
                child: const Icon(
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
                    : 'PIN: 1234',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              
              // Biometric Button
              GestureDetector(
                onTap: _biometricsAvailable ? _authenticateWithBiometrics : _authenticateWithPIN,
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
                        _biometricsAvailable ? Icons.fingerprint : Icons.pin,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _biometricsAvailable ? 'Desbloquear' : 'Usar PIN',
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
              
              if (_biometricsAvailable) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _authenticateWithPIN,
                  child: const Text(
                    'Usar código PIN',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
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
            
            // Unlocked content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.lock_open,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Cofre Desbloqueado',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Suas gravações estão protegidas',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Show encrypted files count
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.folder_special,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '0 gravações protegidas',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Criptografadas com AES-256',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
