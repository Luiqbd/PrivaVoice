import 'package:get_it/get_it.dart';

import 'data/repositories/transcription_repository_impl.dart';
import 'domain/repositories/transcription_repository.dart';
import 'core/services/ai_service.dart';
import 'core/services/recording/recording_service.dart';
import 'presentation/blocs/recording/recording_bloc.dart';
import 'presentation/blocs/transcription/transcription_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Register services
  getIt.registerLazySingleton<AIService>(() => AIService());
  getIt.registerLazySingleton<RecordingService>(() => RecordingService());
  
  // Register BLoCs - using factory for fresh instances
  getIt.registerFactory<RecordingBloc>(
    () => RecordingBloc(
      recordingService: getIt<RecordingService>(),
      aiService: getIt<AIService>(),
    ),
  );
  
  getIt.registerFactory<TranscriptionBloc>(
    () => TranscriptionBloc(
      aiService: getIt<AIService>(),
      repository: getIt<TranscriptionRepository>(),
    ),
  );
  
  // Register repository
  getIt.registerLazySingleton<TranscriptionRepository>(
    () => TranscriptionRepositoryImpl(),
  );
}
