import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/warmup_sets.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/seed_templates.dart' as seeds;
import 'package:workouts/services/repositories/templates/llm_template_converter.dart'
    as llm;
import 'package:workouts/services/repositories/templates/template_block_store.dart';
import 'package:workouts/services/repositories/templates/template_exercise_store.dart';
import 'package:workouts/services/repositories/templates/template_hydrator.dart';

part 'template_repository_powersync.g.dart';

const _log = ELogger('TemplateRepo');
const _uuid = Uuid();

class TemplateRepositoryPowerSync {
  TemplateRepositoryPowerSync(this._powerSync) {
    _hydrator = TemplateHydrator(_powerSync);
    _blockStore = TemplateBlockStore(_powerSync);
    _exerciseStore = TemplateExerciseStore(_powerSync);
  }

  final PowerSyncDatabase _powerSync;
  late final TemplateHydrator _hydrator;
  late final TemplateBlockStore _blockStore;
  late final TemplateExerciseStore _exerciseStore;
  Future<List<WorkoutTemplate>>? _seedRefresh;

  Future<List<String>> fetchExerciseNames() => _hydrator.fetchExerciseNames();

  Future<List<WorkoutExercise>> fetchExercises() => _hydrator.fetchExercises();

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    await _exerciseStore.cleanOrphanedBlockExercises();

    final templateRows = await _powerSync.getAll(
      'SELECT * FROM workout_templates ORDER BY created_at DESC',
    );
    if (templateRows.isEmpty) return _runSeedRefresh(_reseedTemplates);
    if (await _needsSeedReset()) {
      _log.log('Seed templates are stale; resetting workout data.');
      return _runSeedRefresh(reseedTemplates);
    }
    final templates = await _hydrator.hydrateTemplates(templateRows);
    return templates;
  }

  Stream<List<WorkoutTemplate>> watchTemplates() {
    return _powerSync
        .watch('SELECT * FROM workout_templates ORDER BY created_at DESC')
        .asyncMap((templateRows) async {
          if (templateRows.isEmpty) return _runSeedRefresh(_reseedTemplates);
          if (await _needsSeedReset()) {
            _log.log('Seed templates are stale; resetting workout data.');
            return _runSeedRefresh(reseedTemplates);
          }
          final templates = await _hydrator.hydrateTemplates(templateRows);
          _log.log('${templates.length} workout template(s) in DB');
          return templates;
        });
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    final now = DateTime.now().toIso8601String();

    await _powerSync.upsert('workout_templates', {
      'id': template.id,
      'name': template.name,
      'goal': template.goal,
      'notes': template.notes ?? '',
      'created_at': template.createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    });

    await _powerSync.execute(
      'DELETE FROM workout_blocks WHERE template_id = ?',
      [template.id],
    );

    for (
      var blockIndex = 0;
      blockIndex < template.blocks.length;
      blockIndex++
    ) {
      final block = template.blocks[blockIndex];
      final blockId = block.id.isEmpty ? _uuid.v4() : block.id;
      await _blockStore.insertBlock(template.id, blockId, blockIndex, block);
      await _exerciseStore.insertBlockExercises(blockId, block.exercises, now);
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    _log.log('deleteTemplate: $templateId');
    await _powerSync.execute('DELETE FROM workout_templates WHERE id = ?', [
      templateId,
    ]);
  }

  Future<WorkoutTemplate> createFromLlmOption(LlmWorkoutOption option) async {
    final template = llm.templateFromLlmOption(option);
    await saveTemplate(template);
    return template;
  }

  Future<List<WorkoutTemplate>> reseedTemplates() async {
    _log.log(
      'reseedTemplates: wiping workout sessions, templates, and exercises',
    );
    await _powerSync.writeTransaction((transaction) async {
      await transaction.execute('DELETE FROM session_set_logs');
      await transaction.execute('DELETE FROM session_notes');
      await transaction.execute('DELETE FROM heart_rate_samples');
      await transaction.execute('DELETE FROM session_computed_metrics');
      await transaction.execute('DELETE FROM session_block_exercises');
      await transaction.execute('DELETE FROM session_blocks');
      await transaction.execute('DELETE FROM sessions');
      await transaction.execute('DELETE FROM workout_block_exercises');
      await transaction.execute('DELETE FROM workout_blocks');
      await transaction.execute('DELETE FROM workout_templates');
      await transaction.execute('DELETE FROM exercises');
    });
    return _reseedTemplates();
  }

  Future<void> updateExerciseBenefits(
    String exerciseId,
    List<ExerciseBenefit> benefits,
  ) => _exerciseStore.updateExerciseBenefits(exerciseId, benefits);

  Future<void> addWarmupSet({
    required String templateId,
    required String blockId,
    required WorkoutExercise exercise,
  }) => _applyWarmupChange(
    templateId: templateId,
    blockId: blockId,
    exercise: exercise,
    mutate: (warmupSets) => warmupSets.withOneAdded(),
  );

  Future<void> removeWarmupSet({
    required String templateId,
    required String blockId,
    required WorkoutExercise exercise,
  }) => _applyWarmupChange(
    templateId: templateId,
    blockId: blockId,
    exercise: exercise,
    mutate: (warmupSets) => warmupSets.withOneRemoved(),
  );

  Future<void> _applyWarmupChange({
    required String templateId,
    required String blockId,
    required WorkoutExercise exercise,
    required List<PlannedSet> Function(WarmupSets) mutate,
  }) {
    final warmupSets = WarmupSets(
      plannedSets: exercise.plannedSets,
      exercise: exercise,
      loggedSetCount: 0,
    );
    return _exerciseStore.updatePlannedSets(
      templateId: templateId,
      blockId: blockId,
      exerciseId: exercise.id,
      plannedSets: mutate(warmupSets),
    );
  }

  Future<List<WorkoutTemplate>> _reseedTemplates() async {
    final templates = seeds.buildSeedTemplates();
    for (final template in templates) {
      await saveTemplate(template);
    }
    return templates;
  }

  Future<List<WorkoutTemplate>> _runSeedRefresh(
    Future<List<WorkoutTemplate>> Function() refresh,
  ) {
    final seedRefresh = _seedRefresh;
    if (seedRefresh != null) {
      return seedRefresh;
    }

    final nextSeedRefresh = refresh();
    _seedRefresh = nextSeedRefresh;
    return nextSeedRefresh.whenComplete(() {
      if (identical(_seedRefresh, nextSeedRefresh)) {
        _seedRefresh = null;
      }
    });
  }

  Future<bool> _needsSeedReset() async {
    final staleSeedTemplateRows = await _powerSync.getAll('''
      SELECT id
      FROM workout_templates
      WHERE id LIKE 'seed-template-%'
        AND id NOT IN (${_seedTemplatePlaceholders()})
      LIMIT 1
      ''', seeds.currentSeedTemplateIds.toList());
    if (staleSeedTemplateRows.isNotEmpty) return true;

    final staleSeedRows = await _powerSync.getAll('''
      SELECT wbe.id
      FROM workout_block_exercises wbe
      INNER JOIN workout_blocks wb ON wb.id = wbe.block_id
      INNER JOIN workout_templates wt ON wt.id = wb.template_id
      WHERE wt.id LIKE 'seed-template-%'
        AND (
          wbe.planned_sets IS NULL
          OR wbe.planned_sets = ''
          OR wbe.planned_sets = '[]'
          OR wbe.planned_sets NOT LIKE '%weightKg%'
        )
      LIMIT 1
    ''');
    return staleSeedRows.isNotEmpty;
  }

  String _seedTemplatePlaceholders() {
    return List.filled(seeds.currentSeedTemplateIds.length, '?').join(', ');
  }
}

@riverpod
TemplateRepositoryPowerSync templateRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return TemplateRepositoryPowerSync(powerSyncDatabase);
}
