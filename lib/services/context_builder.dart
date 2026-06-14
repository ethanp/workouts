import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/services/repositories/background_notes_repository_powersync.dart';
import 'package:workouts/services/repositories/goals_repository_powersync.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

part 'context_builder.g.dart';

/// Per-session preferences the user sets before generating a workout.
class WorkoutPreferences {
  final int? durationMinutes;
  final List<FitnessGoal> focusGoals;
  final TrainingLocation? location;
  final String? notes;

  const WorkoutPreferences({
    this.durationMinutes,
    this.focusGoals = const [],
    this.location,
    this.notes,
  });

  bool get isEmpty =>
      durationMinutes == null &&
      focusGoals.isEmpty &&
      location == null &&
      (notes == null || notes!.isEmpty);
}

/// Context gathered for LLM workout generation.
class WorkoutContext {
  final List<FitnessGoal> goals;
  final List<BackgroundNote> backgroundNotes;
  final List<Session> recentSessions;
  final List<TrainingInfluence> influences;
  final List<String> knownExerciseNames;
  final WorkoutPreferences? preferences;

  WorkoutContext({
    required this.goals,
    required this.backgroundNotes,
    required this.recentSessions,
    required this.influences,
    required this.knownExerciseNames,
    this.preferences,
  });

  bool get isEmpty =>
      goals.isEmpty && backgroundNotes.isEmpty && influences.isEmpty;
}

class ContextBuilder {
  final GoalsRepositoryPowerSync goalsRepo;
  final BackgroundNotesRepositoryPowerSync notesRepo;
  final SessionRepositoryPowerSync sessionRepo;
  final InfluencesRepositoryPowerSync influencesRepo;
  final TemplateRepositoryPowerSync templateRepo;

  ContextBuilder({
    required this.goalsRepo,
    required this.notesRepo,
    required this.sessionRepo,
    required this.influencesRepo,
    required this.templateRepo,
  });

  Future<WorkoutContext> build() async {
    // Fetch active goals, sorted by priority
    final goals = await goalsRepo.fetchGoals();
    final activeGoals = goals.whereL(
      (goal) => goal.status == GoalStatus.active,
    );

    // Fetch active background notes
    final allNotes = await notesRepo.fetchNotes();
    final activeNotes = allNotes.whereL((note) => note.isActive);

    // Fetch recent sessions (last 7 days, completed only)
    final sessions = await sessionRepo.fetchSessions();
    final cutoff = DateTime.now().shiftedByDays(-7);
    final recentSessions = sessions
        .where(
          (session) =>
              session.completedAt != null &&
              session.completedAt!.isAfter(cutoff),
        )
        .take(10) // Limit to last 10 sessions for token budget
        .toList();

    final activeInfluences = await influencesRepo.fetchActiveInfluences();

    final exerciseNames = await templateRepo.fetchExerciseNames();

    return WorkoutContext(
      goals: activeGoals,
      backgroundNotes: activeNotes,
      recentSessions: recentSessions,
      influences: activeInfluences,
      knownExerciseNames: exerciseNames,
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
    templateRepo: ref.watch(templateRepositoryPowerSyncProvider),
  );
}
