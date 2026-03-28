import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final bool isCompleted;
  final String? selectedNiche;
  final List<String> availableNiches;
  
  const OnboardingState({
    this.currentPage = 0,
    this.isCompleted = false,
    this.selectedNiche,
    this.availableNiches = const ['Jurídico', 'Médico', 'Corporativo'],
  });
  
  OnboardingState copyWith({
    int? currentPage,
    bool? isCompleted,
    String? selectedNiche,
    List<String>? availableNiches,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      isCompleted: isCompleted ?? this.isCompleted,
      selectedNiche: selectedNiche ?? this.selectedNiche,
      availableNiches: availableNiches ?? this.availableNiches,
    );
  }
  
  @override
  List<Object?> get props => [currentPage, isCompleted, selectedNiche, availableNiches];
}
