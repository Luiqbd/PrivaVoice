import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  OnboardingBloc() : super(const OnboardingState()) {
    on<PageChanged>(_onPageChanged);
    on<NextPage>(_onNextPage);
    on<PreviousPage>(_onPreviousPage);
    on<SkipOnboarding>(_onSkipOnboarding);
    on<CompleteOnboarding>(_onCompleteOnboarding);
    on<SelectNiche>(_onSelectNiche);
  }
  
  void _onPageChanged(PageChanged event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }
  
  void _onNextPage(NextPage event, Emitter<OnboardingState> emit) {
    if (state.currentPage < 2) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
    }
  }
  
  void _onPreviousPage(PreviousPage event, Emitter<OnboardingState> emit) {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
    }
  }
  
  Future<void> _onSkipOnboarding(
    SkipOnboarding event,
    Emitter<OnboardingState> emit,
  ) async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
    emit(state.copyWith(isCompleted: true));
  }
  
  Future<void> _onCompleteOnboarding(
    CompleteOnboarding event,
    Emitter<OnboardingState> emit,
  ) async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
    emit(state.copyWith(isCompleted: true));
  }
  
  Future<void> _onSelectNiche(
    SelectNiche event,
    Emitter<OnboardingState> emit,
  ) async {
    await _storage.write(key: 'user_niche', value: event.niche);
    emit(state.copyWith(selectedNiche: event.niche));
  }
  
  Future<bool> checkOnboardingCompleted() async {
    final value = await _storage.read(key: 'onboarding_completed');
    return value == 'true';
  }
}
