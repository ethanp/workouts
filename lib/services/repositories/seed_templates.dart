import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';

List<WorkoutTemplate> buildSeedTemplates() {
  return [
    _kettlebellClubSession(),
    _ptRoutine(),
    _mobilityStrengthFoundation(),
  ];
}

WorkoutTemplate _kettlebellClubSession() {
  final warmup = WorkoutBlock(
    id: 'seed-kb-block-warmup-000000000001',
    title: 'Warmup & Mobility',
    type: WorkoutBlockType.warmup,
    targetDuration: const Duration(minutes: 8),
    description: 'Open shoulders, hips, and spine before load.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-club-halos-00000000001',
        name: 'Club Halos',
        modality: ExerciseModality.reps,
        prescription: '6 per direction',
        targetSets: 2,
        equipment: 'Club',
        cues: ['Smooth arc, open shoulders'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-hip-flexor-stretch-001',
        name: 'Half-kneeling Hip Flexor Stretch',
        modality: ExerciseModality.hold,
        prescription: '30s per side',
        targetSets: 2,
        equipment: 'Club overhead',
        cues: ['Posterior tilt, reach tall'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-cat-cow-thread-00000001',
        name: 'Cat-Cow to Thread Needle',
        modality: ExerciseModality.mobility,
        prescription: '5 per side',
        targetSets: 2,
        cues: ['Segment spine, reach long'],
      ),
    ],
  );

  final animalFlow = WorkoutBlock(
    id: 'seed-kb-block-animal-flow-000000001',
    title: 'Animal Movement Integration',
    type: WorkoutBlockType.animalFlow,
    targetDuration: const Duration(minutes: 12),
    description: 'Prime scapula, ribs, and core with dynamic patterns.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-beast-crawl-000000001',
        name: 'Beast Crawl',
        modality: ExerciseModality.timed,
        prescription: '3 × 20-30s',
        targetSets: 3,
        cues: ['Knees hover, contralateral steps'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-crab-reach-0000000001',
        name: 'Crab Reach',
        modality: ExerciseModality.reps,
        prescription: '3 × 5 per side',
        targetSets: 3,
        cues: ['Drive hips, open chest'],
      ),
    ],
  );

  final posteriorChain = WorkoutBlock(
    id: 'seed-kb-block-posterior-chain-0001',
    title: 'Posterior Chain + Scapula',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 10),
    description: 'Posterior chain hinge and scapular control.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-kb-rdl-000000000001',
        name: 'Kettlebell Romanian Deadlift',
        modality: ExerciseModality.reps,
        prescription: '3 × 8',
        targetSets: 3,
        equipment: 'Kettlebell',
        cues: ['Lat pack, hinge tall'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-front-shield-cast-0001',
        name: 'Club Front Shield Cast',
        modality: ExerciseModality.reps,
        prescription: '3 × 6 per side',
        targetSets: 3,
        cues: ['Brace ribs, smooth arc'],
      ),
    ],
  );

  final hipExtension = WorkoutBlock(
    id: 'seed-kb-block-hip-extension-00001',
    title: 'Hip Extension + Stability',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 10),
    description: 'Load unilateral press and anti-lateral flexion.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-hk-kb-press-000000001',
        name: 'Half-kneeling Kettlebell Press',
        modality: ExerciseModality.reps,
        prescription: '3 × 6 per side',
        targetSets: 3,
        cues: ['Glute lock, tall press'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-suitcase-carry-000001',
        name: 'Kettlebell Suitcase Carry',
        modality: ExerciseModality.timed,
        prescription: '3 × 40s per side',
        targetSets: 3,
        cues: ['Ribs stacked, smooth walk'],
      ),
    ],
  );

  final mobility = WorkoutBlock(
    id: 'seed-kb-block-mobility-focus-00001',
    title: 'Mobility Focus',
    type: WorkoutBlockType.mobility,
    targetDuration: const Duration(minutes: 10),
    description: 'Restore length and rotation after loading.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-goblet-deep-lunge-001',
        name: 'Goblet Deep Lunge Hold',
        modality: ExerciseModality.hold,
        prescription: '2 × 30s per side',
        targetSets: 2,
        cues: ['Knee tracks, hips square'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-club-side-bend-00001',
        name: 'Club Side Bend (Tall Kneel)',
        modality: ExerciseModality.reps,
        prescription: '2 × 6 per side',
        targetSets: 2,
        cues: ['Long spine, oblique squeeze'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-thoracic-rotation-01',
        name: 'Standing Thoracic Rotation with Club',
        modality: ExerciseModality.reps,
        prescription: '8 per side',
        targetSets: 2,
        cues: ['Hip lock, rotate through T-spine'],
      ),
    ],
  );

  final cooldown = WorkoutBlock(
    id: 'seed-kb-block-cooldown-000000001',
    title: 'Cooldown & Breathwork',
    type: WorkoutBlockType.cooldown,
    targetDuration: const Duration(minutes: 10),
    description: 'Downshift nervous system and integrate mobility gains.',
    exercises: [
      WorkoutExercise(
        id: 'seed-kb-ex-supine-9090-breath-01',
        name: 'Supine 90/90 Breathing',
        modality: ExerciseModality.breath,
        prescription: '2 × 5 breaths',
        targetSets: 2,
        cues: ['Nasal inhale, long exhale'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-childs-pose-side-001',
        name: "Child's Pose with Side Reach",
        modality: ExerciseModality.mobility,
        prescription: '45s per side',
        targetSets: 2,
        cues: ['Reach long, breathe lateral ribs'],
      ),
      WorkoutExercise(
        id: 'seed-kb-ex-box-breathing-00001',
        name: 'Box Breathing 4-4-4-4',
        modality: ExerciseModality.breath,
        prescription: '2 minutes',
        targetSets: 1,
        cues: ['Equal phases, relaxed jaw'],
      ),
    ],
  );

  return WorkoutTemplate(
    id: 'seed-template-kb-club-base-0000001',
    name: 'KB + Club Base Session',
    goal: 'Strength, mobility, scapular integration',
    blocks: [warmup, animalFlow, posteriorChain, hipExtension, mobility, cooldown],
    notes: '60-minute session blending load and flow.',
  );
}

WorkoutTemplate _ptRoutine() {
  final mobilityCircuit = WorkoutBlock(
    id: 'seed-pt-block-mobility-circuit-001',
    title: 'Powerset Mobility Circuit',
    type: WorkoutBlockType.mobility,
    targetDuration: const Duration(minutes: 20),
    description: 'Tissue prep for cervical decompression.',
    rounds: 2,
    exercises: [
      WorkoutExercise(
        id: 'seed-pt-ex-neck-smash-000000001',
        name: 'Side Lower Neck Smash',
        modality: ExerciseModality.timed,
        prescription: '30s setup, 2m on',
        cues: ['Slow pressure along scalene line'],
        setupDuration: const Duration(seconds: 30),
        workDuration: const Duration(minutes: 2),
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-doorway-pec-stretch01',
        name: 'Doorway Pec Stretch',
        modality: ExerciseModality.timed,
        prescription: '30s setup, 2m on',
        cues: ['Elbow at shoulder height, breathe lateral ribs'],
        setupDuration: const Duration(seconds: 30),
        workDuration: const Duration(minutes: 2),
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-rhomboids-smash-0001',
        name: 'Rhomboids Smash',
        modality: ExerciseModality.timed,
        prescription: '30s setup, 2m on',
        cues: ['Lean into ball, glide along medial scapula'],
        setupDuration: const Duration(seconds: 30),
        workDuration: const Duration(minutes: 2),
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-upper-chest-smash-01',
        name: 'Upper Side Chest Smash',
        modality: ExerciseModality.timed,
        prescription: '30s setup, 2m on',
        cues: ['Support head, open ribs as you roll'],
        setupDuration: const Duration(seconds: 30),
        workDuration: const Duration(minutes: 2),
      ),
    ],
  );

  final strengthCircuit = WorkoutBlock(
    id: 'seed-pt-block-strength-circuit-01',
    title: 'Powerset Strength Circuit',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 10),
    description: 'Scapular control and rotator cuff endurance.',
    rounds: 2,
    exercises: [
      WorkoutExercise(
        id: 'seed-pt-ex-band-fonzy-000000001',
        name: 'Band Fonzy',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        cues: ['Thumbs back, scapula glides down'],
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-scapular-punches-001',
        name: 'Scapular Punches',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        cues: ['Reach long, protract smoothly'],
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-low-band-row-000001',
        name: 'Low Band Row',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        cues: ['Elbows sweep low, ribs stacked'],
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-internal-rot-ecc-001',
        name: 'Internal Rotator Eccentrics',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        cues: ['Control return, elbow pinned'],
      ),
      WorkoutExercise(
        id: 'seed-pt-ex-external-rot-ecc-001',
        name: 'External Rotator Eccentrics',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        cues: ['Slow lowering, forearm parallel'],
      ),
    ],
  );

  return WorkoutTemplate(
    id: 'seed-template-c7-pt-routine-00001',
    name: 'C7 Radiculopathy PT Routine',
    goal: 'Rehabilitation, mobility, scapular stability',
    blocks: [mobilityCircuit, strengthCircuit],
    notes: 'Two-round tissue prep + scapular stability progression.',
  );
}

WorkoutTemplate _mobilityStrengthFoundation() {
  final mobilityBlock = WorkoutBlock(
    id: 'seed-msf-block-mobility-act-0001',
    title: 'Mobility & Activation',
    type: WorkoutBlockType.warmup,
    targetDuration: const Duration(minutes: 10),
    description: '0–10 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-treadmill-warmup-01',
        name: 'Treadmill Warm-up',
        modality: ExerciseModality.timed,
        prescription: '4 minutes',
        targetSets: 1,
        cues: ['2.5–3.0 mph', 'Loose arms', 'Shoulders down', 'Normal breathing', 'No posture forcing'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-open-books-000001',
        name: 'Open Books',
        modality: ExerciseModality.reps,
        prescription: '6 per side',
        targetSets: 1,
        cues: ['Gentle rotation', 'Follow hand with eyes', 'Keep knees stacked'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-cat-cow-0000000001',
        name: 'Cat-Cow',
        modality: ExerciseModality.reps,
        prescription: '10 slow reps',
        targetSets: 1,
        cues: ['Gentle movements', 'Breathe with motion', 'Segment the spine'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-sternum-float-0001',
        name: 'Sternum Float',
        modality: ExerciseModality.breath,
        prescription: '3 × 5 breaths',
        targetSets: 3,
        cues: ['1 cm lift', 'Shoulders DOWN', 'Gentle elevation only'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-wall-slides-000001',
        name: 'Wall Slides',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        targetSets: 1,
        cues: ['Elbows and wrists on wall', 'Slide up smoothly', 'Keep shoulders relaxed'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-scap-retractions-1',
        name: 'Scapular Retractions',
        modality: ExerciseModality.reps,
        prescription: '10 reps',
        targetSets: 1,
        cues: ['30% effort', 'Gentle squeeze', 'No neck tension'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-serratus-pushup-01',
        name: 'Serratus Wall Push-up',
        modality: ExerciseModality.reps,
        prescription: '8 reps',
        targetSets: 1,
        cues: ['Protract shoulder blades', 'Push through palms', 'Keep elbows straight'],
      ),
    ],
  );

  final lowerBodyBlock = WorkoutBlock(
    id: 'seed-msf-block-lower-body-00001',
    title: 'Lower Body Strength',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 15),
    description: '10–25 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-goblet-squat-00001',
        name: 'Goblet Squat',
        modality: ExerciseModality.reps,
        prescription: '8–12 reps',
        targetSets: 3,
        equipment: '16 kg KB or 20 lb DB',
        restDuration: const Duration(seconds: 60),
        cues: ['Chest soft', 'Elbows inside knees', 'Torso vertical', 'No pinching shoulder blades'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-step-ups-000000001',
        name: 'Step-Ups',
        modality: ExerciseModality.reps,
        prescription: '8–10 per leg',
        targetSets: 3,
        equipment: 'Bodyweight or light DBs',
        restDuration: const Duration(seconds: 45),
        cues: ['Slow lowering', 'Drive through heel', 'Arms hang loose'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-glute-bridge-00001',
        name: 'Glute Bridge',
        modality: ExerciseModality.reps,
        prescription: '10–12 reps',
        targetSets: 3,
        cues: ['Squeeze glutes at top', 'Ribs down', 'No neck pushing into floor'],
      ),
    ],
  );

  final coreBlock = WorkoutBlock(
    id: 'seed-msf-block-core-lower-cross1',
    title: 'Core & Lower-Cross Fix',
    type: WorkoutBlockType.core,
    targetDuration: const Duration(minutes: 10),
    description: '25–35 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-dead-bug-000000001',
        name: 'Dead Bug',
        modality: ExerciseModality.reps,
        prescription: '8 per side (slow)',
        targetSets: 3,
        cues: [
          'Ribs down',
          'Low back gently touching floor',
          'Move limbs like wet noodles — not stiff',
          'No neck involvement',
        ],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-hollow-body-00001',
        name: 'Modified Hollow Body Hold',
        modality: ExerciseModality.hold,
        prescription: '10–20 seconds',
        targetSets: 3,
        cues: [
          'Knees bent 90°',
          'Ribs down',
          'Arms by sides or lightly overhead',
          'Head barely floated off ground',
          'STOP if neck takes over',
        ],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-stir-the-pot-0001',
        name: 'Stir-the-Pot',
        modality: ExerciseModality.hold,
        prescription: '10–20 sec each direction',
        targetSets: 2,
        equipment: 'Stability ball',
        cues: ['Tiny circles', 'Torso rigid', "Don't let shoulders shrug", 'Neck neutral, looking slightly down'],
      ),
    ],
  );

  final pullBlock = WorkoutBlock(
    id: 'seed-msf-block-pull-scapular-001',
    title: 'Pull / Scapular Strength',
    type: WorkoutBlockType.strength,
    targetDuration: const Duration(minutes: 10),
    description: '35–45 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-low-row-000000001',
        name: 'Low Row',
        modality: ExerciseModality.reps,
        prescription: '10–12 reps',
        targetSets: 3,
        equipment: 'Band or cable (light)',
        cues: ['Keep elbows tucked', 'No shoulder retraction pinch', 'Think "elbows slide back"', 'Stop immediately if triceps tingles'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-face-pull-000000001',
        name: 'Face Pull',
        modality: ExerciseModality.reps,
        prescription: '12 reps',
        targetSets: 2,
        equipment: 'Band (NOT cable)',
        cues: ['Elbows high', 'Pull toward forehead', 'Light resistance only', 'Feel mid-back, NOT traps'],
      ),
    ],
  );

  final conditioningBlock = WorkoutBlock(
    id: 'seed-msf-block-conditioning-001',
    title: 'Conditioning Flush',
    type: WorkoutBlockType.conditioning,
    targetDuration: const Duration(minutes: 10),
    description: '45–55 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-easy-bike-treadmill1',
        name: 'Easy Bike or Treadmill Walk',
        modality: ExerciseModality.timed,
        prescription: '8 minutes',
        targetSets: 1,
        cues: ['Relaxed gait', 'Arms loose', 'Shallow incline optional', 'Avoid posture forcing'],
      ),
    ],
  );

  final cooldownBlock = WorkoutBlock(
    id: 'seed-msf-block-cooldown-000001',
    title: 'Cool-down',
    type: WorkoutBlockType.cooldown,
    targetDuration: const Duration(minutes: 5),
    description: '55–60 min',
    exercises: [
      WorkoutExercise(
        id: 'seed-msf-ex-foam-thoracic-0001',
        name: 'Foam Roller Thoracic Extensions',
        modality: ExerciseModality.reps,
        prescription: '6 reps',
        targetSets: 2,
        cues: ['Gentle extensions', 'Avoid the neck entirely'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-shoulder-drop-0001',
        name: 'Shoulder Drop + Long Exhale',
        modality: ExerciseModality.breath,
        prescription: '1 minute',
        targetSets: 1,
        cues: ['Inhale 4 sec → exhale 6 sec', 'Let the rib cage gently settle'],
      ),
      WorkoutExercise(
        id: 'seed-msf-ex-hip-flexor-str-001',
        name: 'Hip Flexor Stretch',
        modality: ExerciseModality.hold,
        prescription: '30 sec per side',
        targetSets: 1,
        cues: ['Gentle posterior tilt', 'No arching low back'],
      ),
    ],
  );

  return WorkoutTemplate(
    id: 'seed-template-mobility-strength-1',
    name: 'Mobility & Strength Foundation',
    goal: 'Nerve-safe strength, mobility, and scapular stability',
    blocks: [mobilityBlock, lowerBodyBlock, coreBlock, pullBlock, conditioningBlock, cooldownBlock],
    notes: '60-minute session designed for thoracic mobility and lower-cross pattern correction with detailed form cues.',
  );
}
