import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_list/cardio_workout_list_tile.dart';
import 'package:workouts/features/history/activity_list/dismissible_activity_tile.dart';
import 'package:workouts/features/history/activity_list/empty_activity_placeholder.dart';
import 'package:workouts/features/history/activity_list/session_list_tile.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/history/history_provider.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';

class HistoryActivityListTab extends ConsumerWidget {
  const HistoryActivityListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityListProvider);
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    return activityAsync.when(
      data: (items) => items.isEmpty
          ? EmptyActivityPlaceholder(
              onImport: dbReady
                  ? () => ref
                        .read(cardioImportControllerProvider.notifier)
                        .importRecentWorkouts()
                  : null,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _buildActivityTile(context, ref, items[index]),
            ),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load activity: $error',
          style: AppTypography.body,
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    WidgetRef ref,
    ActivityItem item,
  ) {
    return switch (item) {
      ActivityCardio(:final workout) => DismissibleActivityTile(
        key: Key('cardio-${workout.id}'),
        item: item,
        onDelete: () => _deleteWorkout(ref, workout),
        child: CardioWorkoutListTile(workout: workout),
      ),
      ActivitySession(:final session) => DismissibleActivityTile(
        key: Key('session-${session.id}'),
        item: item,
        onDelete: () => _deleteSession(ref, session),
        child: SessionListTile(session: session),
      ),
    };
  }

  Future<void> _deleteSession(WidgetRef ref, Session session) async {
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.discardSession(session.id);
    ref.invalidate(sessionHistoryProvider);
    final activeSession = ref.read(activeSessionProvider).value;
    if (activeSession?.id == session.id) {
      ref.read(activeSessionProvider.notifier).discard();
    }
  }

  Future<void> _deleteWorkout(WidgetRef ref, CardioWorkout workout) async {
    final cardioRepo = ref.read(cardioRepositoryPowerSyncProvider);
    await cardioRepo.deleteWorkout(workout.id);
  }
}
