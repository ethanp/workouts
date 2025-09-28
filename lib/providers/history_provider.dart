import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/repositories/session_repository.dart';

part 'history_provider.g.dart';

@riverpod
Future<List<Session>> sessionHistory(Ref ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  final sessions = await repository.history();
  return sessions;
}
