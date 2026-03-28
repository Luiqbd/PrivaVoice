import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();
  @override
  List<Object?> get props => [];
}

class PageChanged extends OnboardingEvent {
  final int pageIndex;
  const PageChanged(this.pageIndex);
  @override
  List<Object?> get props => [pageIndex];
}

class NextPage extends OnboardingEvent {}

class PreviousPage extends OnboardingEvent {}

class SkipOnboarding extends OnboardingEvent {}

class CompleteOnboarding extends OnboardingEvent {}

class SelectNiche extends OnboardingEvent {
  final String niche;
  const SelectNiche(this.niche);
  @override
  List<Object?> get props => [niche];
}
