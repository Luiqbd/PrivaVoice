import 'package:get_it/get_it.dart';

import 'data/repositories/transcription_repository_impl.dart';
import 'domain/repositories/transcription_repository.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Database - AppDatabase handles its own singleton
  // Just register the repository
  getIt.registerLazySingleton<TranscriptionRepository>(
    () => TranscriptionRepositoryImpl(),
  );
}
