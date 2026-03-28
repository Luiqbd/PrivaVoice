import 'package:get_it/get_it.dart';
import 'data/repositories/transcription_repository_impl.dart';
import 'domain/repositories/transcription_repository.dart';
import 'core/services/ai_service.dart';
import 'core/services/recording/recording_service.dart';
import 'presentation/blocs/recording/recording_bloc.dart';
import 'presentation/blocs/transcription/transcription_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies()
  setupPermissions() async {
  // Register services
  getIt.registerLazySingleton<AIService>(() => AIService());
  getIt.registerLazySingleton<RecordingService>(() => RecordingService());
  
  // Register BLoCs - using factory with NO parameters (they use default constructors)
  getIt.registerFactory<RecordingBloc>(() => RecordingBloc());
  getIt.registerFactory<TranscriptionBloc>(() => TranscriptionBloc());
  
  // Register repository
  getIt.registerLazySingleton<TranscriptionRepository>(
    () => TranscriptionRepositoryImpl(),
  );
}

import 'core/services/permission_service.dart';

void setupPermissions() {
  getIt.registerLazySingleton<PermissionService>(() => PermissionService());
}
