import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/cardio/cardio_import_controller.dart';
import 'package:workouts/features/history/activity_list/activity_type_filter_strip.dart';
import 'package:workouts/features/history/activity_list/cardio_workout_list_tile.dart';
import 'package:workouts/features/history/activity_list/dismissible_activity_tile.dart';
import 'package:workouts/features/history/activity_list/empty_activity_placeholder.dart';
import 'package:workouts/features/history/activity_list/session_list_tile.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/history/history_provider.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/session.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';

class const HistoryActivityListTab({
  required final CardioType? activityType,
  required final ValueChanged<CardioType?> onActivityTypeSelected,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityListProvider);
    final dbReady = ref.watch(powerSyncDatabaseProvider).hasValue;

    return activityAsync.when(
      data: (items) => _loadedList(context, ref, items, dbReady),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load activity: $error',
          style: EText.body.medium,
        ),
      ),
    );
  }

  Widget _loadedList(
    BuildContext context,
    WidgetRef ref,
    List<ActivityItem> items,
    bool dbReady,
  ) {
    if (items.isEmpty) {
      return EmptyActivityPlaceholder(
        onImport: dbReady
            ? () => ref
                  .read(cardioImportControllerProvider.notifier)
                  .importRecentWorkouts()
            : null,
      );
    }

    final CardioType? listedActivityType = _activityTypeStillPresent(items);
    final List<ActivityItem> visibleItems = items.whereL(
      (activityItem) =>
          activityItem.matchesListedActivityType(listedActivityType),
    );

    return Column(
      children: [
        if (_offersActivityTypeFilter(items))
          ActivityTypeFilterStrip(
            activityTypes: _activityTypesIn(items),
            selectedActivityType: listedActivityType,
            onActivityTypeSelected: onActivityTypeSelected,
          ),
        Expanded(
          child: visibleItems.isEmpty
              ? _noneOfThisType(listedActivityType)
              : _activityList(context, ref, visibleItems),
        ),
      ],
    );
  }

  Widget _activityList(
    BuildContext context,
    WidgetRef ref,
    List<ActivityItem> items,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(ELayout.spaceLg)
          .withOverlaidTabBar(context),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: ELayout.spaceSm),
      itemBuilder: (context, index) =>
          _buildActivityTile(context, ref, items[index]),
    );
  }

  Widget _noneOfThisType(CardioType? listedActivityType) {
    final String label = listedActivityType?.displayName ?? 'matching';
    return Center(
      child: Text(
        'No $label workouts',
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
      ),
    );
  }

  bool _offersActivityTypeFilter(List<ActivityItem> items) {
    final int typeCount = _activityTypesIn(items).length;
    if (typeCount == 0) return false;
    final bool hasSession = items.any(
      (activityItem) => activityItem is ActivitySession,
    );
    if (hasSession) return true;
    return typeCount > 1;
  }

  CardioType? _activityTypeStillPresent(List<ActivityItem> items) {
    final CardioType? listedActivityType = activityType;
    if (listedActivityType == null) return null;
    if (_activityTypesIn(items).contains(listedActivityType)) {
      return listedActivityType;
    }
    return null;
  }

  List<CardioType> _activityTypesIn(List<ActivityItem> items) {
    final Set<CardioType> present = {};
    for (final ActivityItem item in items) {
      if (item case ActivityCardio(:final workout)) {
        present.add(workout.activityType);
      }
    }
    return CardioType.values.where(present.contains).toList();
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
