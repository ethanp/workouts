import 'package:workouts/models/workout_exercise.dart';

/// Domain view over an exercise's planned-set list focused on warmup
/// adjustment. Carries `(plannedSets, exercise, loggedSetCount)` and exposes
/// every rule the UI and repositories need: whether add/remove is currently
/// allowed, and how to produce the next list.
///
/// A logged set is identified by index < [loggedSetCount]; warmups behind a
/// logged set are immutable (the predicates and mutators only ever touch the
/// unlogged tail). This is the single source of truth for warmup-list rules
/// — no other code should reason about warmup add/remove directly.
class WarmupSets {
  const WarmupSets({
    required this.plannedSets,
    required this.exercise,
    required this.loggedSetCount,
  });

  final List<PlannedSet> plannedSets;
  final WorkoutExercise exercise;
  final int loggedSetCount;

  /// True when there is at least one unlogged set in front. A new warmup
  /// will be inserted at index [loggedSetCount], pushing the rest back.
  bool get canAdd => loggedSetCount < plannedSets.length;

  /// True when the next unlogged set is itself a warmup. Removing means
  /// dropping that next set; we never delete a logged set.
  bool get canRemove =>
      loggedSetCount < plannedSets.length &&
      plannedSets[loggedSetCount].type == PlannedSetType.warmup;

  /// Returns the planned-set list with one additional warmup inserted at
  /// [loggedSetCount]. Mirrors the next unlogged warmup when one exists so
  /// stacked warmups stay consistent.
  List<PlannedSet> withOneAdded() {
    final sibling = canRemove ? plannedSets[loggedSetCount] : null;
    final newWarmup = PlannedSet.newWarmup(
      exercise: exercise,
      sibling: sibling,
    );
    return [
      ...plannedSets.sublist(0, loggedSetCount),
      newWarmup,
      ...plannedSets.sublist(loggedSetCount),
    ];
  }

  /// Returns the planned-set list with the next unlogged warmup removed.
  /// Throws when [canRemove] is false; the rule "never delete a logged set"
  /// is enforced once here rather than at every call site.
  List<PlannedSet> withOneRemoved() {
    if (!canRemove) {
      throw StateError('WarmupSets.withOneRemoved called when canRemove is false');
    }
    return [
      ...plannedSets.sublist(0, loggedSetCount),
      ...plannedSets.sublist(loggedSetCount + 1),
    ];
  }
}
