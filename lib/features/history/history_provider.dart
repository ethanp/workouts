import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';

part 'history_provider.g.dart';

@riverpod
Stream<List<Session>> sessionHistory(Ref ref) async* {
  final repository = ref.watch(sessionRepositoryPowerSyncProvider);
  yield* repository.watchSessions();
}

@riverpod
Stream<Session> sessionById(Ref ref, String sessionId) {
  final repository = ref.watch(sessionRepositoryPowerSyncProvider);
  return repository.watchSessionById(sessionId);
}
