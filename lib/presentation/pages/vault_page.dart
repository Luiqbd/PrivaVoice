import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:get_it/get_it.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../domain/repositories/transcription_repository.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  bool _isUnlocked = false;
  bool _biometricsAvailable = false;
  bool _deviceAuthAvailable = false;
  bool _isAuthenticating = false;
  final LocalAuthentication _auth = LocalAuthentication();
  
  // Hidden transcriptions list
  List<dynamic> _hiddenTranscriptions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      // Check available biometric types (fingerprint, face, etc.)
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      
      // Get available biometric types
      final availableBiometrics = await _auth.getAvailableBiometrics();
      
      setState(() {
        _biometricsAvailable = canCheckBiometrics && isDeviceSupported && availableBiometrics.isNotEmpty;
        _deviceAuthAvailable = isDeviceSupported; // Device supports any auth (biometric, PIN, pattern)
      });
      
      debugPrint('Biometrics available: $_biometricsAvailable');
      debugPrint('Device auth available: $_deviceAuthAvailable');
      debugPrint('Available biometrics: $availableBiometrics');
    } catch (e) {
      debugPrint('Biometric check error: $e');
      setState(() {
        _biometricsAvailable = false;
        _deviceAuthAvailable = false;
      });
    }
  }

  /// Authenticate using device credentials (biometric OR PIN/password/pattern)
  /// This uses the same authentication as the phone's lock screen
  Future<void> _authenticateWithDeviceCredentials() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    try {
      debugPrint('Starting device authentication...');
      
      // Use biometricOnly: false to allow both biometric AND device PIN/password
      final authenticated = await _auth.authenticate(
        localizedReason: 'Autentique para acessar o cofre',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,  // Allow both biometric AND device PIN/password
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      
      debugPrint('Device auth result: $authenticated');
      
      if (authenticated) {
        setState(() => _isUnlocked = true);
        HapticUtils.mediumImpact();
        _showSuccessSnackBar('Cofre desbloqueado!');
        _loadHiddenTranscriptions();
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

  /// Authenticate using ONLY biometric (fingerprint/face)
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    try {
      debugPrint('Starting biometric-only authentication...');
      
      final authenticated = await _auth.authenticate(
        localizedReason: 'Use a digital para acessar o cofre',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,  // ONLY biometric, no PIN fallback
          useErrorDialogs: true,
        ),
      );
      
      debugPrint('Biometric auth result: $authenticated');
      
      if (authenticated) {
        setState(() => _isUnlocked = true);
        HapticUtils.mediumImpact();
        _showSuccessSnackBar('Cofre desbloqueado!');
        _loadHiddenTranscriptions();
      } else {
        _showAuthFailedSnackBar();
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      _showAuthFailedSnackBar();
    } finally {
      setState(() => _isAuthenticating = false);
    }
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
  
  Future<void> _loadHiddenTranscriptions() async {
    setState(() => _isLoading = true);
    try {
      final repository = GetIt.instance<TranscriptionRepository>();
      final all = await repository.getAllTranscriptions();
      final hidden = all.where((t) => t.isHidden == true).toList();
      setState(() {
        _hiddenTranscriptions = hidden;
        _isLoading = false;
      });
      debugPrint('Vault: Loaded ${hidden.length} hidden transcriptions');
    } catch (e) {
      debugPrint('Error loading hidden transcriptions: $e');
      setState(() => _isLoading = false);
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
                _deviceAuthAvailable 
                    ? 'Suas gravações protegidas'
                    : 'Autenticação não disponível',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              
              // Unlock Button - Uses device credentials (biometric OR PIN)
              GestureDetector(
                onTap: _deviceAuthAvailable ? _authenticateWithDeviceCredentials : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _deviceAuthAvailable ? AppColors.primaryGradient : null,
                    color: _deviceAuthAvailable ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _deviceAuthAvailable ? [
                      BoxShadow(
                        color: AppColors.primaryAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _biometricsAvailable ? Icons.fingerprint : Icons.lock_open,
                        color: _deviceAuthAvailable ? Colors.white : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _biometricsAvailable ? 'Desbloquear' : 'Usar PIN do Aparelho',
                        style: TextStyle(
                          color: _deviceAuthAvailable ? Colors.white : AppColors.textTertiary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // If both biometric AND device auth available, show option to use only biometric
              if (_biometricsAvailable && _deviceAuthAvailable) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _authenticateWithBiometrics,
                  child: const Text(
                    'Usar apenas digital',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hiddenTranscriptions.isEmpty
                      ? _buildEmptyVault()
                      : _buildHiddenList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyVault() {
    return Center(
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
            'Nenhuma gravação protegida',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHiddenList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hiddenTranscriptions.length,
      itemBuilder: (context, index) {
        final t = _hiddenTranscriptions[index];
        return ListTile(
          title: Text(t.title, style: const TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(t.text.substring(0, t.text.length > 50 ? 50 : t.text.length), 
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          leading: const Icon(Icons.lock, color: AppColors.warning),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockedState();
    }
    return _buildUnlockedState();
  }
}
