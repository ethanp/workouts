import 'package:powersync/powersync.dart';
import 'package:workouts/models/workout_block.dart';

class TemplateBlockStore {
  TemplateBlockStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> insertBlock(
    String templateId,
    String blockId,
    int blockIndex,
    WorkoutBlock block,
  ) async {
    await _powerSync.execute(
      '''
      INSERT INTO workout_blocks (
        id, template_id, block_index, type, title,
        target_duration_seconds, description, rounds
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        blockId,
        templateId,
        blockIndex,
        block.type.name,
        block.title,
        block.targetDuration.inSeconds,
        block.description,
        block.rounds,
      ],
    );
  }
}
