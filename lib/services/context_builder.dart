import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/repositories/background_notes_repository_powersync.dart';
import 'package:workouts/services/repositories/goals_repository_powersync.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';

part 'context_builder.g.dart';

/// Context gathered for LLM workout generation.
class WorkoutContext {
  final List<FitnessGoal> goals;
  final List<BackgroundNote> backgroundNotes;
  final List<Session> recentSessions;
  final List<TrainingInfluence> influences;

  WorkoutContext({
    required this.goals,
    required this.backgroundNotes,
    required this.recentSessions,
    required this.influences,
  });

  bool get isEmpty => goals.isEmpty && backgroundNotes.isEmpty && influences.isEmpty;
}

class ContextBuilder {
  final GoalsRepositoryPowerSync goalsRepo;
  final BackgroundNotesRepositoryPowerSync notesRepo;
  final SessionRepositoryPowerSync sessionRepo;
  final InfluencesRepositoryPowerSync influencesRepo;

  ContextBuilder({
    required this.goalsRepo,
    required this.notesRepo,
    required this.sessionRepo,
    required this.influencesRepo,
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

    // Fetch active training influences
    final activeInfluences = await influencesRepo.fetchActiveInfluences();

    return WorkoutContext(
      goals: activeGoals,
      backgroundNotes: activeNotes,
      recentSessions: recentSessions,
      influences: activeInfluences,
    );
  }
}

@riverpod
ContextBuilder contextBuilder(Ref ref) {
  return ContextBuilder(
    goalsRepo: ref.watch(goalsRepositoryPowerSyncProvider),
    notesRepo: ref.watch(backgroundNotesRepositoryPowerSyncProvider),
    sessionRepo: ref.watch(sessionRepositoryPowerSyncProvider),
    influencesRepo: ref.watch(influencesRepositoryPowerSyncProvider),
  );
}
