import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/powersync_database_provider.dart';
import 'package:workouts/services/powersync_mappers.dart' as mappers;

part 'template_repository_powersync.g.dart';

const _uuid = Uuid();

class TemplateRepositoryPowerSync {
  TemplateRepositoryPowerSync(this._db);

  final PowerSyncDatabase _db;

  static const int currentTemplateVersion = 5;

  /// Fetch all workout templates with blocks and exercises.
  Future<List<WorkoutTemplate>> fetchTemplates() async {
    // Fetch templates
    final templateRows = await _db.getAll(
      'SELECT * FROM workout_templates ORDER BY created_at DESC',
    );

    if (templateRows.isEmpty) {
      return _reseedTemplates();
    }

    final templates = <WorkoutTemplate>[];

    for (final templateRow in templateRows) {
      final templateId = templateRow['id'] as String;

      // Fetch blocks for this template
      final blockRows = await _db.getAll(
        '''
        SELECT * FROM workout_blocks
        WHERE template_id = ?
        ORDER BY block_index
        ''',
        [templateId],
      );

      final blocks = <WorkoutBlock>[];

      for (final blockRow in blockRows) {
        final blockId = blockRow['id'] as String;

        // Fetch exercises for this block
        final exerciseRows = await _db.getAll(
          '''
          SELECT 
            e.id as e_id,
            e.name as e_name,
            e.modality as e_modality,
            e.equipment as e_equipment,
            e.cues as e_cues,
            wbe.prescription as wbe_prescription,
            wbe.setup_duration_seconds as wbe_setup_duration_seconds,
            wbe.work_duration_seconds as wbe_work_duration_seconds,
            wbe.rest_duration_seconds as wbe_rest_duration_seconds
          FROM workout_block_exercises wbe
          INNER JOIN exercises e ON e.id = wbe.exercise_id
          WHERE wbe.block_id = ?
          ORDER BY wbe.exercise_index
          ''',
          [blockId],
        );

        final exercises = exerciseRows
            .map((row) => mappers.workoutExerciseFromJoinRow(row))
            .toList();

        blocks.add(mappers.workoutBlockFromRow(blockRow, exercises));
      }

      templates.add(mappers.workoutTemplateFromRow(templateRow, blocks));
    }

    return templates;
  }

  /// Watch templates (reactive stream).
  Stream<List<WorkoutTemplate>> watchTemplates() {
    return _db
        .watch('SELECT * FROM workout_templates ORDER BY created_at DESC')
        .asyncMap((templateRows) async {
          final templates = <WorkoutTemplate>[];

          for (final templateRow in templateRows) {
            final templateId = templateRow['id'] as String;

            final blockRows = await _db.getAll(
              '''
          SELECT * FROM workout_blocks
          WHERE template_id = ?
          ORDER BY block_index
          ''',
              [templateId],
            );

            final blocks = <WorkoutBlock>[];

            for (final blockRow in blockRows) {
              final blockId = blockRow['id'] as String;

              final exerciseRows = await _db.getAll(
                '''
            SELECT 
              e.id as e_id,
              e.name as e_name,
              e.modality as e_modality,
              e.equipment as e_equipment,
              e.cues as e_cues,
              wbe.prescription as wbe_prescription,
              wbe.setup_duration_seconds as wbe_setup_duration_seconds,
              wbe.work_duration_seconds as wbe_work_duration_seconds,
              wbe.rest_duration_seconds as wbe_rest_duration_seconds
            FROM workout_block_exercises wbe
            INNER JOIN exercises e ON e.id = wbe.exercise_id
            WHERE wbe.block_id = ?
            ORDER BY wbe.exercise_index
            ''',
                [blockId],
              );

              final exercises = exerciseRows
                  .map((row) => mappers.workoutExerciseFromJoinRow(row))
                  .toList();

              blocks.add(mappers.workoutBlockFromRow(blockRow, exercises));
            }

            templates.add(mappers.workoutTemplateFromRow(templateRow, blocks));
          }

          return templates;
        });
  }

  /// Save a workout template (creates or updates).
  Future<void> saveTemplate(WorkoutTemplate template) async {
    final now = DateTime.now().toIso8601String();

    // Upsert template (PowerSync views require INSERT OR REPLACE)
    await _db.execute(
      '''
      INSERT OR REPLACE INTO workout_templates (id, name, goal, notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        template.id,
        template.name,
        template.goal,
        template.notes ?? '',
        template.createdAt?.toIso8601String() ?? now,
        now, // Always update updated_at on save
      ],
    );

    // Delete existing blocks (cascade will delete exercises)
    await _db.execute('DELETE FROM workout_blocks WHERE template_id = ?', [
      template.id,
    ]);

    // Insert blocks and exercises
    for (
      var blockIndex = 0;
      blockIndex < template.blocks.length;
      blockIndex++
    ) {
      final block = template.blocks[blockIndex];
      final blockId = block.id.isEmpty ? _uuid.v4() : block.id;

      await _db.execute(
        '''
        INSERT INTO workout_blocks (
          id, template_id, block_index, type, title,
          target_duration_seconds, description, rounds
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          blockId,
          template.id,
          blockIndex,
          block.type.name,
          block.title,
          block.targetDuration.inSeconds,
          block.description,
          block.rounds,
        ],
      );

      // Insert exercises for this block
      for (
        var exerciseIndex = 0;
        exerciseIndex < block.exercises.length;
        exerciseIndex++
      ) {
        final exercise = block.exercises[exerciseIndex];

        // Ensure exercise exists
        await _db.execute(
          '''
          INSERT OR REPLACE INTO exercises (id, name, modality, equipment, cues, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            exercise.id,
            exercise.name,
            exercise.modality.name,
            exercise.equipment ?? '',
            jsonEncode(exercise.cues),
            now,
            now,
          ],
        );

        // Insert junction table entry
        await _db.execute(
          '''
          INSERT INTO workout_block_exercises (
            id, block_id, exercise_id, exercise_index, prescription,
            setup_duration_seconds, work_duration_seconds, rest_duration_seconds
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            _uuid.v4(),
            blockId,
            exercise.id,
            exerciseIndex,
            exercise.prescription,
            exercise.setupDuration?.inSeconds,
            exercise.workDuration?.inSeconds,
            exercise.restDuration?.inSeconds,
          ],
        );
      }
    }
  }

  /// Delete a template.
  Future<void> deleteTemplate(String templateId) async {
    // Cascade delete will handle blocks and exercises
    await _db.execute('DELETE FROM workout_templates WHERE id = ?', [
      templateId,
    ]);
  }

  /// Seed templates on first run.
  Future<List<WorkoutTemplate>> _reseedTemplates() async {
    final templates = _buildSeedTemplates();
    for (final template in templates) {
      await saveTemplate(template);
    }
    return templates;
  }

  /// Public method to clear and reseed all templates.
  Future<void> reseedTemplates() async {
    await _db.execute('DELETE FROM workout_block_exercises');
    await _db.execute('DELETE FROM workout_blocks');
    await _db.execute('DELETE FROM workout_templates');
    await _reseedTemplates();
  }

  List<WorkoutTemplate> _buildSeedTemplates() {
    return [
      _buildDefaultTemplate(),
      _buildPTRoutineTemplate(),
      _buildMobilityStrengthTemplate(),
    ];
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
}

@riverpod
TemplateRepositoryPowerSync templateRepositoryPowerSync(Ref ref) {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return TemplateRepositoryPowerSync(db);
}
