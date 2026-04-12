import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ai/ai_state.dart';

/// Setup Initial Page - Elegant loading screen for 1.11GB model copy
/// Shows real progress during AI initialization
class SetupInitialPage extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SetupInitialPage({super.key, required this.onComplete});

  @override
  State<SetupInitialPage> createState() => _SetupInitialPageState();
}

class _SetupInitialPageState extends State<SetupInitialPage>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  String _statusMessage = 'Inicializando...';
  double _progress = 0.0;
  String _currentModel = '';
  
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    // Start monitoring AI state
    _startMonitoring();
  }

  void _startMonitoring() {
    _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      
      // Update from AIManager state
      setState(() {
        _statusMessage = AIManager.statusMessage;
        _progress = AIManager.progress;
        
        // Extract current model from status message
        if (_statusMessage.contains('Whisper')) {
          _currentModel = 'Whisper';
        } else if (_statusMessage.contains('Llama') || _statusMessage.contains('Chat')) {
          _currentModel = 'Llama';
        } else if (_statusMessage.contains('Inteligência') || _statusMessage.contains('Extraindo')) {
          _currentModel = 'Inteligência';
        }
      });
      
      // Check if ready to navigate
      if (AIManager.isWhisperReady || AIManager.state == AIState.readyWhisper) {
        _onComplete();
      }
    });
  }

  void _onComplete() {
    _checkTimer?.cancel();
    _pulseController.stop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress percentage
    final percent = (_progress * 100).round();
    
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryAccent.withOpacity(0.3 * _pulseAnimation.value),
                            AppColors.primaryAccent.withOpacity(0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryAccent.withOpacity(0.5),
                            blurRadius: 30 * _pulseAnimation.value,
                            spreadRadius: 10 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _progress >= 1.0 ? Icons.check : Icons.psychology,
                          size: 56,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 48),
              
              // Title
              Text(
                'PrivaVoice',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Inteligência Militar Offline',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Progress bar container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: _progress.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryAccent.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentModel.isNotEmpty 
                              ? 'Extraindo: $_currentModel'
                              : _statusMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Status text
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Feature hints
              _buildFeatureHint(
                icon: Icons.mic_none,
                text: 'Transcrição offline',
                isActive: _progress > 0.3,
              ),
              _buildFeatureHint(
                icon: Icons.chat_bubble_outline,
                text: 'Resumo com IA local',
                isActive: _progress > 0.6,
              ),
              _buildFeatureHint(
                icon: Icons.security,
                text: 'Soberania de dados',
                isActive: _progress > 0.9,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHint({
    required IconData icon,
    required String text,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? icon : Icons.circle_outlined,
            size: 16,
            color: isActive ? AppColors.primaryAccent : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}