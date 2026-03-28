import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../blocs/onboarding/onboarding_bloc.dart';
import '../blocs/onboarding/onboarding_event.dart';
import '../blocs/onboarding/onboarding_state.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingPage({super.key, required this.onComplete});
  
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.isCompleted) {
          widget.onComplete();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    context.read<OnboardingBloc>().add(PageChanged(index));
                  },
                  children: const [
                    _OnboardingSlide(
                      icon: Icons.mic_off,
                      title: '100% Offline',
                      description: 'Seus áudios e transcrições ficam apenas no seu dispositivo. Segurança militar sem internet.',
                    ),
                    _OnboardingSlide(
                      icon: Icons.security,
                      title: 'Criptografia AES-256',
                      description: 'Cada arquivo é criptografado com chaves geradas localmente. Sua privacidade em primeiro lugar.',
                    ),
                    _OnboardingNicheSlide(),
                  ],
                ),
              ),
              _buildBottomSection(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomSection(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  AppConstants.onboardingPageCount,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: state.currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: state.currentPage == index
                          ? AppColors.primaryAccent
                          : AppColors.surfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (state.currentPage > 0)
                    TextButton(
                      onPressed: () {
                        context.read<OnboardingBloc>().add(PreviousPage());
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text(
                        'Voltar',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  const Spacer(),
                  if (state.currentPage < AppConstants.onboardingPageCount - 1)
                    ElevatedButton(
                      onPressed: () {
                        HapticUtils.selectionClick();
                        context.read<OnboardingBloc>().add(NextPage());
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Próximo'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        HapticUtils.mediumImpact();
                        context.read<OnboardingBloc>().add(CompleteOnboarding());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                      ),
                      child: const Text('Começar'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
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
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: 60, color: AppColors.backgroundPrimary),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingNicheSlide extends StatelessWidget {
  const _OnboardingNicheSlide();
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.work_outline,
                size: 80,
                color: AppColors.primaryAccent,
              ),
              const SizedBox(height: 32),
              Text(
                'Selecione seu setor',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              ...state.availableNiches.map((niche) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GlassmorphismButton(
                  label: niche,
                  isSelected: state.selectedNiche == niche,
                  onTap: () {
                    HapticUtils.selectionClick();
                    context.read<OnboardingBloc>().add(SelectNiche(niche));
                  },
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _GlassmorphismButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _GlassmorphismButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected 
              ? AppColors.primaryAccent.withOpacity(0.2)
              : AppColors.surface.withOpacity(0.5),
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryAccent.withOpacity(0.2),
              blurRadius: 20,
            ),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.primaryAccent : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
