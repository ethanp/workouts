import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';

class SessionBuilder {
  String _id = 'test-session-id';
  String _templateId = 'test-template-id';
  DateTime _startedAt = DateTime(2024, 1, 1, 10, 0);
  DateTime? _completedAt;
  Duration? _duration;
  String? _notes;
  String? _feeling;
  List<SessionBlock> _blocks = [];
  List<BreathSegment> _breathSegments = [];
  bool _isPaused = false;
  DateTime? _pausedAt;
  Duration _totalPausedDuration = Duration.zero;
  DateTime? _updatedAt;

  SessionBuilder withId(String id) {
    _id = id;
    return this;
  }

  SessionBuilder withTemplateId(String templateId) {
    _templateId = templateId;
    return this;
  }

  SessionBuilder withStartedAt(DateTime startedAt) {
    _startedAt = startedAt;
    return this;
  }

  SessionBuilder withCompletedAt(DateTime? completedAt) {
    _completedAt = completedAt;
    return this;
  }

  SessionBuilder withDuration(Duration? duration) {
    _duration = duration;
    return this;
  }

  SessionBuilder withNotes(String? notes) {
    _notes = notes;
    return this;
  }

  SessionBuilder withFeeling(String? feeling) {
    _feeling = feeling;
    return this;
  }

  SessionBuilder withBlocks(List<SessionBlock> blocks) {
    _blocks = blocks;
    return this;
  }

  SessionBuilder withBreathSegments(List<BreathSegment> segments) {
    _breathSegments = segments;
    return this;
  }

  SessionBuilder paused() {
    _isPaused = true;
    _pausedAt = DateTime.now();
    return this;
  }

  SessionBuilder pausedAt(DateTime pausedAt) {
    _isPaused = true;
    _pausedAt = pausedAt;
    return this;
  }

  SessionBuilder withTotalPausedDuration(Duration duration) {
    _totalPausedDuration = duration;
    return this;
  }

  SessionBuilder completed() {
    _completedAt = DateTime.now();
    _duration = Duration(minutes: 60);
    return this;
  }

  SessionBuilder withUpdatedAt(DateTime updatedAt) {
    _updatedAt = updatedAt;
    return this;
  }

  Session build() {
    return Session(
      id: _id,
      templateId: _templateId,
      startedAt: _startedAt,
      completedAt: _completedAt,
      duration: _duration,
      notes: _notes,
      feeling: _feeling,
      blocks: _blocks,
      breathSegments: _breathSegments,
      isPaused: _isPaused,
      pausedAt: _pausedAt,
      totalPausedDuration: _totalPausedDuration,
      updatedAt: _updatedAt,
    );
  }
}

SessionBlock createTestBlock({
  required String id,
  required String sessionId,
  WorkoutBlockType type = WorkoutBlockType.strength,
  int blockIndex = 0,
  List<WorkoutExercise> exercises = const [],
  List<SessionSetLog> logs = const [],
  Duration targetDuration = const Duration(minutes: 5),
  Duration? actualDuration,
  String? notes,
  int? roundIndex,
  int? totalRounds,
}) {
  return SessionBlock(
    id: id,
    sessionId: sessionId,
    type: type,
    blockIndex: blockIndex,
    exercises: exercises,
    logs: logs,
    targetDuration: targetDuration,
    actualDuration: actualDuration,
    notes: notes,
    roundIndex: roundIndex,
    totalRounds: totalRounds,
  );
}

SessionSetLog createTestLog({
  required String id,
  required String sessionBlockId,
  required String exerciseId,
  required int setIndex,
  double? weightKg,
  int? reps,
  Duration? duration,
  double? rpe,
  String? notes,
}) {
  return SessionSetLog(
    id: id,
    sessionBlockId: sessionBlockId,
    exerciseId: exerciseId,
    setIndex: setIndex,
    weightKg: weightKg,
    reps: reps,
    duration: duration,
    rpe: rpe,
    notes: notes,
  );
}

BreathSegment createTestBreathSegment({
  required String id,
  required String sessionId,
  String pattern = '4-4-4-4',
  Duration targetDuration = const Duration(minutes: 1),
  Duration? actualDuration,
}) {
  return BreathSegment(
    id: id,
    sessionId: sessionId,
    pattern: pattern,
    targetDuration: targetDuration,
    actualDuration: actualDuration,
  );
}

WorkoutExercise createTestExercise({
  required String id,
  required String name,
  ExerciseModality modality = ExerciseModality.reps,
  String prescription = '',
  int targetSets = 3,
  String equipment = '',
  List<String> cues = const [],
}) {
  return WorkoutExercise(
    id: id,
    name: name,
    modality: modality,
    prescription: prescription,
    targetSets: targetSets,
    equipment: equipment,
    cues: cues,
  );
}

void assertSessionEquals(Session expected, Session actual) {
  assert(expected.id == actual.id, 'Session ID mismatch');
  assert(expected.templateId == actual.templateId, 'Template ID mismatch');
  assert(expected.startedAt == actual.startedAt, 'StartedAt mismatch');
  assert(expected.completedAt == actual.completedAt, 'CompletedAt mismatch');
  assert(expected.duration == actual.duration, 'Duration mismatch');
  assert(expected.notes == actual.notes, 'Notes mismatch');
  assert(expected.feeling == actual.feeling, 'Feeling mismatch');
  assert(expected.isPaused == actual.isPaused, 'IsPaused mismatch');
  assert(expected.pausedAt == actual.pausedAt, 'PausedAt mismatch');
  assert(
    expected.totalPausedDuration == actual.totalPausedDuration,
    'TotalPausedDuration mismatch',
  );
  assert(expected.blocks.length == actual.blocks.length, 'Blocks length mismatch');
  assert(
    expected.breathSegments.length == actual.breathSegments.length,
    'BreathSegments length mismatch',
  );
}

