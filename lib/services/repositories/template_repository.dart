import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/local_database.dart';

part 'template_repository.g.dart';

const _uuid = Uuid();

class TemplateRepository {
  TemplateRepository(this._db);

  final LocalDatabase _db;

  static const int currentTemplateVersion = 2;

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    final localRows = await _db.readTemplates();
    if (localRows.isEmpty) {
      final defaultTemplate = _buildDefaultTemplate();
      await saveTemplate(defaultTemplate);
      return [defaultTemplate];
    }

    // Check if any templates are outdated and need regeneration
    final needsUpdate = localRows.any(
      (row) => row.version < currentTemplateVersion,
    );
    if (needsUpdate) {
      // Clear outdated templates and regenerate
      await _db.delete(_db.workoutTemplatesTable).go();
      final defaultTemplate = _buildDefaultTemplate();
      await saveTemplate(defaultTemplate);
      return [defaultTemplate];
    }

    return localRows.map(_mapTemplate).toList();
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    final companion = WorkoutTemplatesTableCompanion.insert(
      id: template.id,
      name: template.name,
      goal: template.goal,
      blocksJson: jsonEncode(
        template.blocks.map((block) => block.toJson()).toList(),
      ),
      notes: Value(template.notes),
      createdAt: template.createdAt ?? DateTime.now(),
      updatedAt: Value(template.updatedAt ?? DateTime.now()),
      version: Value(currentTemplateVersion),
    );
    await _db.upsertTemplate(companion);
  }

  WorkoutTemplate _buildDefaultTemplate() {
    final halos = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Halos',
      modality: ExerciseModality.reps,
      prescription: '6 per direction',
      targetSets: 2, // Left + right direction
      equipment: 'Club',
      cue: 'Smooth arc, open shoulders',
    );
    final hipFlexorStretch = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Half-kneeling Hip Flexor Stretch',
      modality: ExerciseModality.hold,
      prescription: '30s per side',
      targetSets: 2, // Left + right side
      equipment: 'Club overhead',
      cue: 'Posterior tilt, reach tall',
    );
    final catCow = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Cat-Cow to Thread Needle',
      modality: ExerciseModality.mobility,
      prescription: '5 per side',
      targetSets: 2, // Left + right side
      cue: 'Segment spine, reach long',
    );
    final beastCrawl = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Beast Crawl',
      modality: ExerciseModality.timed,
      prescription: '3 × 20-30s',
      targetSets: 3,
      cue: 'Knees hover, contralateral steps',
    );
    final crabReach = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Crab Reach',
      modality: ExerciseModality.reps,
      prescription: '3 × 5 per side',
      targetSets: 3,
      cue: 'Drive hips, open chest',
    );
    final kbRdl = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Kettlebell Romanian Deadlift',
      modality: ExerciseModality.reps,
      prescription: '3 × 8',
      targetSets: 3,
      equipment: 'Kettlebell',
      cue: 'Lat pack, hinge tall',
    );
    final clubShield = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Front Shield Cast',
      modality: ExerciseModality.reps,
      prescription: '3 × 6 per side',
      targetSets: 3,
      cue: 'Brace ribs, smooth arc',
    );
    final halfKneelingPress = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Half-kneeling Kettlebell Press',
      modality: ExerciseModality.reps,
      prescription: '3 × 6 per side',
      targetSets: 3,
      cue: 'Glute lock, tall press',
    );
    final suitcaseCarry = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Kettlebell Suitcase Carry',
      modality: ExerciseModality.timed,
      prescription: '3 × 40s per side',
      targetSets: 3,
      cue: 'Ribs stacked, smooth walk',
    );
    final gobletDeepLunge = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Goblet Deep Lunge Hold',
      modality: ExerciseModality.hold,
      prescription: '2 × 30s per side',
      targetSets: 2,
      cue: 'Knee tracks, hips square',
    );
    final clubSideBend = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Club Side Bend (Tall Kneel)',
      modality: ExerciseModality.reps,
      prescription: '2 × 6 per side',
      targetSets: 2,
      cue: 'Long spine, oblique squeeze',
    );
    final thoracicRotation = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Standing Thoracic Rotation with Club',
      modality: ExerciseModality.reps,
      prescription: '8 per side',
      targetSets: 2, // Left + right side
      cue: 'Hip lock, rotate through T-spine',
    );
    final supineBreathing = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Supine 90/90 Breathing',
      modality: ExerciseModality.breath,
      prescription: '2 × 5 breaths',
      targetSets: 2,
      cue: 'Nasal inhale, long exhale',
    );
    final childsPose = WorkoutExercise(
      id: _uuid.v4(),
      name: "Child's Pose with Side Reach",
      modality: ExerciseModality.mobility,
      prescription: '45s per side',
      targetSets: 2, // Left + right side
      cue: 'Reach long, breathe lateral ribs',
    );
    final boxBreathing = WorkoutExercise(
      id: _uuid.v4(),
      name: 'Box Breathing 4-4-4-4',
      modality: ExerciseModality.breath,
      prescription: '2 minutes',
      targetSets: 1, // Single continuous session
      cue: 'Equal phases, relaxed jaw',
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
  return TemplateRepository(db);
}
