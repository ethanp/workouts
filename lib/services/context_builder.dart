import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/repositories/background_notes_repository_powersync.dart';
import 'package:workouts/services/repositories/goals_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';

part 'context_builder.g.dart';

/// Context gathered for LLM workout generation.
class WorkoutContext {
  final List<FitnessGoal> goals;
  final List<BackgroundNote> backgroundNotes;
  final List<Session> recentSessions;

  WorkoutContext({
    required this.goals,
    required this.backgroundNotes,
    required this.recentSessions,
  });

  bool get isEmpty => goals.isEmpty && backgroundNotes.isEmpty;
}

class ContextBuilder {
  final GoalsRepositoryPowerSync goalsRepo;
  final BackgroundNotesRepositoryPowerSync notesRepo;
  final SessionRepositoryPowerSync sessionRepo;

  ContextBuilder({
    required this.goalsRepo,
    required this.notesRepo,
    required this.sessionRepo,
  });

  Future<WorkoutContext> build() async {
    // Fetch active goals, sorted by priority
    final goals = await goalsRepo.fetchGoals();
    final activeGoals = goals
        .where((g) => g.status == GoalStatus.active)
        .toList();

    // Fetch active background notes
    final allNotes = await notesRepo.fetchNotes();
    final activeNotes = allNotes.where((n) => n.isActive).toList();

    // Fetch recent sessions (last 7 days, completed only)
    final sessions = await sessionRepo.fetchSessions();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recentSessions = sessions
        .where((s) => s.completedAt != null && s.completedAt!.isAfter(cutoff))
        .take(10) // Limit to last 10 sessions for token budget
        .toList();

    return WorkoutContext(
      goals: activeGoals,
      backgroundNotes: activeNotes,
      recentSessions: recentSessions,
    );
  }
}

@riverpod
ContextBuilder contextBuilder(Ref ref) {
  return ContextBuilder(
    goalsRepo: ref.watch(goalsRepositoryPowerSyncProvider),
    notesRepo: ref.watch(backgroundNotesRepositoryPowerSyncProvider),
    sessionRepo: ref.watch(sessionRepositoryPowerSyncProvider),
  );
}
