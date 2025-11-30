import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/sync/sync_service.dart';

part 'template_repository.g.dart';

const _uuid = Uuid();

class TemplateRepository {
  TemplateRepository(this._db, this._syncService);

  final LocalDatabase _db;
  final SyncService _syncService;

  static const int currentTemplateVersion = 5;

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    final localRows = await _db.readTemplates();
    if (localRows.isEmpty) {
      return _reseedTemplates();
    }

    // Check if any templates are outdated and need regeneration
    final needsUpdate = localRows.any(
      (row) => row.version < currentTemplateVersion,
    );
    if (needsUpdate) {
      // Clear outdated templates and regenerate
      await _db.delete(_db.workoutTemplatesTable).go();
      return _reseedTemplates();
    }

    return localRows.map(_mapTemplate).toList();
  }

  Future<List<WorkoutTemplate>> _reseedTemplates() async {
    final templates = _buildSeedTemplates();
    for (final template in templates) {
      await saveTemplate(template);
    }
    return templates;
  }

  List<WorkoutTemplate> _buildSeedTemplates() {
    return [
      _buildDefaultTemplate(),
      _buildPTRoutineTemplate(),
      _buildMobilityStrengthTemplate(),
    ];
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    final blocksJson = jsonEncode(
      template.blocks.map((block) => block.toJson()).toList(),
    );
    final companion = WorkoutTemplatesTableCompanion.insert(
      id: template.id,
      name: template.name,
      goal: template.goal,
      blocksJson: blocksJson,
      notes: Value(template.notes),
      createdAt: template.createdAt ?? DateTime.now(),
      updatedAt: Value(template.updatedAt ?? DateTime.now()),
      version: Value(currentTemplateVersion),
    );
    await _db.upsertTemplate(companion);

    final row = await _db.readTemplateById(template.id);
    if (row != null) {
      unawaited(_syncService.pushTemplate(row));
    }
  }

  WorkoutTemplate _buildDefaultTemplate() {
    final halos = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Halos',
      modality: ExerciseModality.reps,
      prescription: '6 per direction',
      targetSets: 2,
      equipment: 'Club',
      cues: ['Smooth arc, open shoulders'],
    );
    final hipFlexorStretch = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Half-kneeling Hip Flexor Stretch',
      modality: ExerciseModality.hold,
      prescription: '30s per side',
      targetSets: 2,
      equipment: 'Club overhead',
      cues: ['Posterior tilt, reach tall'],
    );
    final catCow = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Cat-Cow to Thread Needle',
      modality: ExerciseModality.mobility,
      prescription: '5 per side',
      targetSets: 2,
      cues: ['Segment spine, reach long'],
    );
    final beastCrawl = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Beast Crawl',
      modality: ExerciseModality.timed,
      prescription: '3 × 20-30s',
      targetSets: 3,
      cues: ['Knees hover, contralateral steps'],
    );
    final crabReach = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Crab Reach',
      modality: ExerciseModality.reps,
      prescription: '3 × 5 per side',
      targetSets: 3,
      cues: ['Drive hips, open chest'],
    );
    final kbRdl = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Kettlebell Romanian Deadlift',
      modality: ExerciseModality.reps,
      prescription: '3 × 8',
      targetSets: 3,
      equipment: 'Kettlebell',
      cues: ['Lat pack, hinge tall'],
    );
    final clubShield = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Front Shield Cast',
      modality: ExerciseModality.reps,
      prescription: '3 × 6 per side',
      targetSets: 3,
      cues: ['Brace ribs, smooth arc'],
    );
    final halfKneelingPress = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Half-kneeling Kettlebell Press',
      modality: ExerciseModality.reps,
      prescription: '3 × 6 per side',
      targetSets: 3,
      cues: ['Glute lock, tall press'],
    );
    final suitcaseCarry = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Kettlebell Suitcase Carry',
      modality: ExerciseModality.timed,
      prescription: '3 × 40s per side',
      targetSets: 3,
      cues: ['Ribs stacked, smooth walk'],
    );
    final gobletDeepLunge = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Goblet Deep Lunge Hold',
      modality: ExerciseModality.hold,
      prescription: '2 × 30s per side',
      targetSets: 2,
      cues: ['Knee tracks, hips square'],
    );
    final clubSideBend = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Side Bend (Tall Kneel)',
      modality: ExerciseModality.reps,
      prescription: '2 × 6 per side',
      targetSets: 2,
      cues: ['Long spine, oblique squeeze'],
    );
    final thoracicRotation = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Standing Thoracic Rotation with Club',
      modality: ExerciseModality.reps,
      prescription: '8 per side',
      targetSets: 2,
      cues: ['Hip lock, rotate through T-spine'],
    );
    final supineBreathing = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Supine 90/90 Breathing',
      modality: ExerciseModality.breath,
      prescription: '2 × 5 breaths',
      targetSets: 2,
      cues: ['Nasal inhale, long exhale'],
    );
    final childsPose = WorkoutExercise(
      id: _uuid.v4(),
      name: "Child's Pose with Side Reach",
      modality: ExerciseModality.mobility,
      prescription: '45s per side',
      targetSets: 2,
      cues: ['Reach long, breathe lateral ribs'],
    );
    final boxBreathing = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Box Breathing 4-4-4-4',
      modality: ExerciseModality.breath,
      prescription: '2 minutes',
      targetSets: 1,
      cues: ['Equal phases, relaxed jaw'],
    );

    WorkoutBlock buildBlock(
      String title,
      WorkoutBlockType type,
      Duration duration,
      List<WorkoutExercise> exercises,
      String description,
    ) {
      return WorkoutBlock(
        id: _uuid.v4(),
        title: title,
        type: type,
        targetDuration: duration,
        exercises: exercises,
        description: description,
      );
    }

    final blocks = [
      buildBlock(
        'Warmup & Mobility',
        WorkoutBlockType.warmup,
        const Duration(minutes: 8),
        [halos, hipFlexorStretch, catCow],
        'Open shoulders, hips, and spine before load.',
      ),
      buildBlock(
        'Animal Movement Integration',
        WorkoutBlockType.animalFlow,
        const Duration(minutes: 12),
        [beastCrawl, crabReach],
        'Prime scapula, ribs, and core with dynamic patterns.',
      ),
      buildBlock(
        'Posterior Chain + Scapula',
        WorkoutBlockType.strength,
        const Duration(minutes: 10),
        [kbRdl, clubShield],
        'Posterior chain hinge and scapular control.',
      ),
      buildBlock(
        'Hip Extension + Stability',
        WorkoutBlockType.strength,
        const Duration(minutes: 10),
        [halfKneelingPress, suitcaseCarry],
        'Load unilateral press and anti-lateral flexion.',
      ),
      buildBlock(
        'Mobility Focus',
        WorkoutBlockType.mobility,
        const Duration(minutes: 10),
        [gobletDeepLunge, clubSideBend, thoracicRotation],
        'Restore length and rotation after loading.',
      ),
      buildBlock(
        'Cooldown & Breathwork',
        WorkoutBlockType.cooldown,
        const Duration(minutes: 10),
        [supineBreathing, childsPose, boxBreathing],
        'Downshift nervous system and integrate mobility gains.',
      ),
    ];

    return WorkoutTemplate(
      id: _uuid.v4(),
      name: 'KB + Club Base Session',
      goal: 'Strength, mobility, scapular integration',
      blocks: blocks,
      notes: '60-minute session blending load and flow.',
    );
  }

  WorkoutTemplate _buildPTRoutineTemplate() {
    final sideLowerNeckSmash = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Side Lower Neck Smash',
      modality: ExerciseModality.timed,
      prescription: '30s setup, 2m on',
      cues: ['Slow pressure along scalene line'],
      setupDuration: const Duration(seconds: 30),
      workDuration: const Duration(minutes: 2),
    );
    final doorwayPecStretch = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Doorway Pec Stretch',
      modality: ExerciseModality.timed,
      prescription: '30s setup, 2m on',
      cues: ['Elbow at shoulder height, breathe lateral ribs'],
      setupDuration: const Duration(seconds: 30),
      workDuration: const Duration(minutes: 2),
    );
    final rhomboidsSmash = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Rhomboids Smash',
      modality: ExerciseModality.timed,
      prescription: '30s setup, 2m on',
      cues: ['Lean into ball, glide along medial scapula'],
      setupDuration: const Duration(seconds: 30),
      workDuration: const Duration(minutes: 2),
    );
    final upperSideChestSmash = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Upper Side Chest Smash',
      modality: ExerciseModality.timed,
      prescription: '30s setup, 2m on',
      cues: ['Support head, open ribs as you roll'],
      setupDuration: const Duration(seconds: 30),
      workDuration: const Duration(minutes: 2),
    );
    final bandFonzy = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Band Fonzy',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      cues: ['Thumbs back, scapula glides down'],
    );
    final scapularPunches = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Scapular Punches',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      cues: ['Reach long, protract smoothly'],
    );
    final lowBandRow = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Low Band Row',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      cues: ['Elbows sweep low, ribs stacked'],
    );
    final internalRotatorEccentrics = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Internal Rotator Eccentrics',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      cues: ['Control return, elbow pinned'],
    );
    final externalRotatorEccentrics = WorkoutExercise(
      id: _uuid.v4(),
      name: 'External Rotator Eccentrics',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      cues: ['Slow lowering, forearm parallel'],
    );

    final mobilityCircuit = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Powerset Mobility Circuit',
      type: WorkoutBlockType.mobility,
      targetDuration: const Duration(minutes: 20),
      exercises: [
        sideLowerNeckSmash,
        doorwayPecStretch,
        rhomboidsSmash,
        upperSideChestSmash,
      ],
      description: 'Tissue prep for cervical decompression.',
      rounds: 2,
    );

    final strengthCircuit = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Powerset Strength Circuit',
      type: WorkoutBlockType.strength,
      targetDuration: const Duration(minutes: 10),
      exercises: [
        bandFonzy,
        scapularPunches,
        lowBandRow,
        internalRotatorEccentrics,
        externalRotatorEccentrics,
      ],
      description: 'Scapular control and rotator cuff endurance.',
      rounds: 2,
    );

    return WorkoutTemplate(
      id: _uuid.v4(),
      name: 'C7 Radiculopathy PT Routine',
      goal: 'Rehabilitation, mobility, scapular stability',
      blocks: [mobilityCircuit, strengthCircuit],
      notes: 'Two-round tissue prep + scapular stability progression.',
    );
  }

  WorkoutTemplate _buildMobilityStrengthTemplate() {
    final treadmillWarmup = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Treadmill Warm-up',
      modality: ExerciseModality.timed,
      prescription: '4 minutes',
      targetSets: 1,
      cues: [
        '2.5–3.0 mph',
        'Loose arms',
        'Shoulders down',
        'Normal breathing',
        'No posture forcing',
      ],
    );

    final openBooks = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Open Books',
      modality: ExerciseModality.reps,
      prescription: '6 per side',
      targetSets: 1,
      cues: ['Gentle rotation', 'Follow hand with eyes', 'Keep knees stacked'],
    );

    final catCow = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Cat-Cow',
      modality: ExerciseModality.reps,
      prescription: '10 slow reps',
      targetSets: 1,
      cues: ['Gentle movements', 'Breathe with motion', 'Segment the spine'],
    );

    final sternumFloat = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Sternum Float',
      modality: ExerciseModality.breath,
      prescription: '3 × 5 breaths',
      targetSets: 3,
      cues: ['1 cm lift', 'Shoulders DOWN', 'Gentle elevation only'],
    );

    final wallSlides = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Wall Slides',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      targetSets: 1,
      cues: [
        'Elbows and wrists on wall',
        'Slide up smoothly',
        'Keep shoulders relaxed',
      ],
    );

    final scapularRetractions = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Scapular Retractions',
      modality: ExerciseModality.reps,
      prescription: '10 reps',
      targetSets: 1,
      cues: ['30% effort', 'Gentle squeeze', 'No neck tension'],
    );

    final serratusWallPushup = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Serratus Wall Push-up',
      modality: ExerciseModality.reps,
      prescription: '8 reps',
      targetSets: 1,
      cues: [
        'Protract shoulder blades',
        'Push through palms',
        'Keep elbows straight',
      ],
    );

    final gobletSquat = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Goblet Squat',
      modality: ExerciseModality.reps,
      prescription: '8–12 reps',
      targetSets: 3,
      equipment: '16 kg KB or 20 lb DB',
      restDuration: const Duration(seconds: 60),
      cues: [
        'Chest soft',
        'Elbows inside knees',
        'Torso vertical',
        'No pinching shoulder blades',
      ],
    );

    final stepUps = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Step-Ups',
      modality: ExerciseModality.reps,
      prescription: '8–10 per leg',
      targetSets: 3,
      equipment: 'Bodyweight or light DBs',
      restDuration: const Duration(seconds: 45),
      cues: ['Slow lowering', 'Drive through heel', 'Arms hang loose'],
    );

    final gluteBridge = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Glute Bridge',
      modality: ExerciseModality.reps,
      prescription: '10–12 reps',
      targetSets: 3,
      cues: [
        'Squeeze glutes at top',
        'Ribs down',
        'No neck pushing into floor',
      ],
    );

    final deadBug = WorkoutExercise(
      id: _uuid.v4(),
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
    );

    final hollowBodyHold = WorkoutExercise(
      id: _uuid.v4(),
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
    );

    final stirThePot = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Stir-the-Pot',
      modality: ExerciseModality.hold,
      prescription: '10–20 sec each direction',
      targetSets: 2,
      equipment: 'Stability ball',
      cues: [
        'Tiny circles',
        'Torso rigid',
        "Don't let shoulders shrug",
        'Neck neutral, looking slightly down',
      ],
    );

    final lowRow = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Low Row',
      modality: ExerciseModality.reps,
      prescription: '10–12 reps',
      targetSets: 3,
      equipment: 'Band or cable (light)',
      cues: [
        'Keep elbows tucked',
        'No shoulder retraction pinch',
        'Think "elbows slide back"',
        'Stop immediately if triceps tingles',
      ],
    );

    final facePull = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Face Pull',
      modality: ExerciseModality.reps,
      prescription: '12 reps',
      targetSets: 2,
      equipment: 'Band (NOT cable)',
      cues: [
        'Elbows high',
        'Pull toward forehead',
        'Light resistance only',
        'Feel mid-back, NOT traps',
      ],
    );

    final easyBike = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Easy Bike or Treadmill Walk',
      modality: ExerciseModality.timed,
      prescription: '8 minutes',
      targetSets: 1,
      cues: [
        'Relaxed gait',
        'Arms loose',
        'Shallow incline optional',
        'Avoid posture forcing',
      ],
    );

    final foamRollerExtensions = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Foam Roller Thoracic Extensions',
      modality: ExerciseModality.reps,
      prescription: '6 reps',
      targetSets: 2,
      cues: ['Gentle extensions', 'Avoid the neck entirely'],
    );

    final shoulderDrop = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Shoulder Drop + Long Exhale',
      modality: ExerciseModality.breath,
      prescription: '1 minute',
      targetSets: 1,
      cues: ['Inhale 4 sec → exhale 6 sec', 'Let the rib cage gently settle'],
    );

    final hipFlexorStretch = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Hip Flexor Stretch',
      modality: ExerciseModality.hold,
      prescription: '30 sec per side',
      targetSets: 1,
      cues: ['Gentle posterior tilt', 'No arching low back'],
    );

    final mobilityBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Mobility & Activation',
      type: WorkoutBlockType.warmup,
      targetDuration: const Duration(minutes: 10),
      exercises: [
        treadmillWarmup,
        openBooks,
        catCow,
        sternumFloat,
        wallSlides,
        scapularRetractions,
        serratusWallPushup,
      ],
      description: '0–10 min',
    );

    final lowerBodyBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Lower Body Strength',
      type: WorkoutBlockType.strength,
      targetDuration: const Duration(minutes: 15),
      exercises: [gobletSquat, stepUps, gluteBridge],
      description: '10–25 min',
    );

    final coreBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Core & Lower-Cross Fix',
      type: WorkoutBlockType.core,
      targetDuration: const Duration(minutes: 10),
      exercises: [deadBug, hollowBodyHold, stirThePot],
      description: '25–35 min',
    );

    final pullBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Pull / Scapular Strength',
      type: WorkoutBlockType.strength,
      targetDuration: const Duration(minutes: 10),
      exercises: [lowRow, facePull],
      description: '35–45 min',
    );

    final conditioningBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Conditioning Flush',
      type: WorkoutBlockType.conditioning,
      targetDuration: const Duration(minutes: 10),
      exercises: [easyBike],
      description: '45–55 min',
    );

    final cooldownBlock = WorkoutBlock(
      id: _uuid.v4(),
      title: 'Cool-down',
      type: WorkoutBlockType.cooldown,
      targetDuration: const Duration(minutes: 5),
      exercises: [foamRollerExtensions, shoulderDrop, hipFlexorStretch],
      description: '55–60 min',
    );

    return WorkoutTemplate(
      id: _uuid.v4(),
      name: 'Mobility & Strength Foundation',
      goal: 'Nerve-safe strength, mobility, and scapular stability',
      blocks: [
        mobilityBlock,
        lowerBodyBlock,
        coreBlock,
        pullBlock,
        conditioningBlock,
        cooldownBlock,
      ],
      notes:
          '60-minute session designed for thoracic mobility and lower-cross pattern correction with detailed form cues.',
    );
  }

  WorkoutTemplate _mapTemplate(WorkoutTemplateRow data) {
    final blocksJson = jsonDecode(data.blocksJson) as List<dynamic>;
    final blocks = blocksJson
        .map(
          (block) =>
              WorkoutBlock.fromJson(Map<String, dynamic>.from(block as Map)),
        )
        .toList();
    return WorkoutTemplate(
      id: data.id,
      name: data.name,
      goal: data.goal,
      blocks: blocks,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      notes: data.notes,
    );
  }
}

@riverpod
TemplateRepository templateRepository(Ref ref) {
  final db = ref.watch(localDatabaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return TemplateRepository(db, syncService);
}
