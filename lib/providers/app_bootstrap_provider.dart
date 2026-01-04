import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'app_bootstrap_provider.g.dart';

@riverpod
Future<void> appBootstrap(Ref ref) async {
  // Initialize PowerSync database
  await ref.watch(powerSyncDatabaseProvider.future);
}
