import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/models/weight.dart';

const currentSeedTemplateIds = {'seed-template-full-gym-session-0001'};

List<WorkoutTemplate> buildSeedTemplates() {
  return [_fullGymSession()];
}

WorkoutTemplate _fullGymSession() {
  return WorkoutTemplate(
    id: 'seed-template-full-gym-session-0001',
    name: 'At-home Warmup + Gym Strength + Zone 2',
    goal: 'Activation, machine strength, aerobic base, and cooldown',
    notes:
        'Full session: 8-10 min at-home activation, gym strength, 25-30 min Zone 2, cooldown, and optional sauna.',
    blocks: [
      _warmupActivationBlock(),
      _gymStrengthBlock(),
      _zone2CardioBlock(),
      _cooldownBlock(),
      _optionalRecoveryBlock(),
    ],
  );
}

WorkoutBlock _warmupActivationBlock() {
  return WorkoutBlock(
    id: 'seed-full-block-warmup-activation-0001',
    title: 'At-home Warmup / Activation',
    type: WorkoutBlockType.warmup,
    targetDuration: const Duration(minutes: 10),
    description:
        'Wake up feet, ankles, glutes, core, and split-stance control.',
    exercises: [
      _durationExercise(
        id: 'seed-full-ex-short-foot-drill-0001',
        name: 'Short Foot Drill',
        prescription: '2 x 20s per side',
        setCount: 2,
        duration: const Duration(seconds: 20),
        modality: ExerciseModality.hold,
        isUnilateral: true,
        cues: ['Work one side at a time', 'Keep toes relaxed'],
      ),
      _durationExercise(
        id: 'seed-full-ex-ankle-circles-0001',
        name: 'Ankle Circles',
        prescription: '1 min each',
        setCount: 1,
        duration: const Duration(minutes: 1),
        modality: ExerciseModality.mobility,
        cues: ['Smooth circles', 'Move through full comfortable range'],
      ),
      _durationExercise(
        id: 'seed-full-ex-calf-rocks-0001',
        name: 'Calf Rocks',
        prescription: '1 min each',
        setCount: 1,
        duration: const Duration(minutes: 1),
        modality: ExerciseModality.mobility,
        cues: ['Rock slowly', 'Keep pressure through tripod foot'],
      ),
      _repsExercise(
        id: 'seed-full-ex-glute-bridge-0001',
        name: 'Glute Bridge',
        prescription: '2 x 10 slow reps',
        setCount: 2,
        reps: 10,
        cues: ['Slow reps', 'Reach knees forward as hips extend'],
      ),
      _repsExercise(
        id: 'seed-full-ex-bird-dog-0001',
        name: 'Bird Dog',
        prescription: '2 x 6 per side',
        setCount: 2,
        reps: 6,
        isUnilateral: true,
        cues: ['Keep pelvis level', 'Reach long instead of high'],
      ),
      _repsExercise(
        id: 'seed-full-ex-dead-bug-0001',
        name: 'Dead Bug',
        prescription: '2 x 6 per side',
        setCount: 2,
        reps: 6,
        isUnilateral: true,
        cues: ['Full exhale', 'Keep low back quiet'],
      ),
      _durationExercise(
        id: 'seed-full-ex-bodyweight-split-squat-hold-0001',
        name: 'Bodyweight Split Squat Hold',
        prescription: '20s per side',
        setCount: 1,
        duration: const Duration(seconds: 20),
        modality: ExerciseModality.hold,
        isUnilateral: true,
        cues: ['Stay tall', 'Keep front foot grounded'],
      ),
    ],
  );
}

WorkoutBlock _gymStrengthBlock() {
  return WorkoutBlock(
    id: 'seed-full-block-gym-strength-0001',
    title: 'Gym Strength Block',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 45),
    description:
        'Machine and cable strength work with controlled tempo and setup buffer.',
    exercises: [
      _repsExercise(
        id: 'seed-full-ex-chest-supported-row-machine-0001',
        name: 'Chest-supported Row Machine',
        prescription: '3 x 8-10',
        setCount: 3,
        reps: 8,
        weight: Weight.pounds(50),
        restDuration: const Duration(seconds: 90),
        cues: [
          'Keep chest glued to pad',
          'Shoulders down and back',
          'Slight pause at torso',
        ],
      ),
      _repsExercise(
        id: 'seed-full-ex-chest-press-machine-0001',
        name: 'Chest Press Machine',
        prescription: '3 x 8-10',
        setCount: 3,
        reps: 8,
        weight: Weight.pounds(50),
        restDuration: const Duration(seconds: 90),
        cues: ['Ribcage down', 'Smooth control', "Don't shrug"],
      ),
      _repsExercise(
        id: 'seed-full-ex-seated-cable-row-neutral-0001',
        name: 'Seated Cable Row (Neutral Grip)',
        prescription: '2 x 10',
        setCount: 2,
        reps: 10,
        weight: Weight.pounds(45),
        restDuration: const Duration(seconds: 75),
        cues: [
          'Let shoulder blades protract slightly forward',
          'Drive elbows back',
        ],
      ),
      _repsExercise(
        id: 'seed-full-ex-leg-curl-machine-0001',
        name: 'Leg Curl Machine',
        prescription: '2 x 10',
        setCount: 2,
        reps: 10,
        weight: Weight.pounds(60),
        restDuration: const Duration(seconds: 75),
        cues: ['Smooth squeeze at peak contraction', 'Control the return'],
      ),
      _repsExercise(
        id: 'seed-full-ex-leg-extension-machine-0001',
        name: 'Leg Extension Machine',
        prescription: '2 x 10 light/moderate',
        setCount: 2,
        reps: 10,
        weight: Weight.pounds(30),
        restDuration: const Duration(seconds: 75),
        cues: ['Moderate load only', 'No aggressive lockout'],
      ),
      _repsExercise(
        id: 'seed-full-ex-bent-leg-horizontal-calf-raise-0001',
        name: 'Bent Leg Horizontal Calf Raise',
        prescription: '2 x 12',
        setCount: 2,
        reps: 12,
        weight: Weight.pounds(70),
        restDuration: const Duration(seconds: 60),
        cues: ['Slow stretch at bottom', 'Slight pause at top'],
      ),
    ],
  );
}

WorkoutBlock _zone2CardioBlock() {
  return WorkoutBlock(
    id: 'seed-full-block-zone2-cardio-0001',
    title: 'Zone 2 Cardio',
    type: WorkoutBlockType.conditioning,
    targetDuration: const Duration(minutes: 30),
    description: 'Preferred: Precor elliptical / AMT.',
    exercises: [
      _durationExercise(
        id: 'seed-full-ex-precor-elliptical-amt-zone2-0001',
        name: 'Precor Elliptical / AMT',
        prescription: '25-30 min Zone 2',
        setCount: 1,
        duration: const Duration(minutes: 25),
        modality: ExerciseModality.timed,
        cues: [
          'Stay around conversational pace',
          'Focus foot pressure between 2nd-3rd toes',
          'Relax shoulders',
          'Gradually ramp intensity instead of jumping HR immediately',
        ],
      ),
    ],
  );
}

WorkoutBlock _cooldownBlock() {
  return WorkoutBlock(
    id: 'seed-full-block-cooldown-0001',
    title: 'Cooldown',
    type: WorkoutBlockType.cooldown,
    targetDuration: const Duration(minutes: 8),
    description: 'Walk, stretch, and decompress gently.',
    exercises: [
      _durationExercise(
        id: 'seed-full-ex-easy-walk-0001',
        name: 'Easy Walk',
        prescription: '3 min',
        setCount: 1,
        duration: const Duration(minutes: 3),
        modality: ExerciseModality.timed,
        cues: ['Easy pace', 'Let breathing settle'],
      ),
      _durationExercise(
        id: 'seed-full-ex-hip-flexor-stretch-0001',
        name: 'Hip Flexor Stretch',
        prescription: '30s per side',
        setCount: 1,
        duration: const Duration(seconds: 30),
        modality: ExerciseModality.hold,
        isUnilateral: true,
        cues: ['Posterior tilt', 'Reach tall'],
      ),
      _durationExercise(
        id: 'seed-full-ex-pull-up-bar-hang-0001',
        name: 'Pull-up Bar Hang',
        prescription: '2 x 20-30s',
        setCount: 2,
        duration: const Duration(seconds: 20),
        modality: ExerciseModality.hold,
        restDuration: const Duration(seconds: 30),
        cues: ['Only if available', 'Gentle decompression only'],
      ),
    ],
  );
}

WorkoutBlock _optionalRecoveryBlock() {
  return WorkoutBlock(
    id: 'seed-full-block-optional-recovery-0001',
    title: 'Optional',
    type: WorkoutBlockType.cooldown,
    targetDuration: const Duration(minutes: 10),
    description: 'Optional sauna finish.',
    exercises: [
      _durationExercise(
        id: 'seed-full-ex-sauna-0001',
        name: 'Sauna',
        prescription: '5-10 min moderate heat',
        setCount: 1,
        duration: const Duration(minutes: 5),
        modality: ExerciseModality.breath,
        cues: [
          'Moderate heat',
          'Nasal breathing as tolerated',
          'Switch to mouth breathing if nostrils start burning again',
        ],
      ),
    ],
  );
}

WorkoutExercise _repsExercise({
  required String id,
  required String name,
  required String prescription,
  required int setCount,
  required int reps,
  Weight? weight,
  Duration? restDuration,
  bool isUnilateral = false,
  required List<String> cues,
}) {
  return WorkoutExercise(
    id: id,
    name: name,
    modality: ExerciseModality.reps,
    prescription: prescription,
    targetSets: setCount,
    restDuration: restDuration,
    isUnilateral: isUnilateral,
    cues: cues,
    plannedSets: [
      for (var setIndex = 0; setIndex < setCount; setIndex++)
        PlannedSet(reps: reps, weight: weight),
    ],
  );
}

WorkoutExercise _durationExercise({
  required String id,
  required String name,
  required String prescription,
  required int setCount,
  required Duration duration,
  required ExerciseModality modality,
  required List<String> cues,
  Duration? restDuration,
  bool isUnilateral = false,
}) {
  return WorkoutExercise(
    id: id,
    name: name,
    modality: modality,
    prescription: prescription,
    targetSets: setCount,
    restDuration: restDuration,
    isUnilateral: isUnilateral,
    cues: cues,
    workDuration: duration,
    plannedSets: [
      for (var setIndex = 0; setIndex < setCount; setIndex++)
        PlannedSet(duration: duration),
    ],
  );
}
