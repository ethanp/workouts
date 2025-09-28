import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/local_database.dart';

part 'app_bootstrap_provider.g.dart';

@riverpod
Future<void> appBootstrap(Ref ref) async {
  // Initialize local database
  ref.watch(localDatabaseProvider);
}
