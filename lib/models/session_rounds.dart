import 'package:workouts/models/session.dart';

/// Helpers for reasoning about exercise placement across the multi-round
/// structure of a session. A "round" here is a block; a multi-round
/// template materializes into N blocks of the same `type` and `totalRounds`,
/// and any add/remove/replace/reorder mutation applies to *every* round of
/// that group so the rounds stay in lock-step.
///
/// Lives separate from [Session]'s data definition so `models/session.dart`
/// stays a pure Freezed file. Both `features/active_session/` (UI, for
/// confirmation copy) and `services/repositories/session/` (the mutations
/// themselves) import this directly.
extension SessionRounds on Session {
  /// IDs of every round that moves in lock-step with [blockId] under a
  /// mutation: just `{blockId}` for a single-round block, otherwise every
  /// block sharing its `type` and `totalRounds` (including the target).
  Set<String> allRoundsOfBlock(String blockId) {
    final target = blockById(blockId);
    if (target.totalRounds == null) return {target.id};
    return blocks
        .where(
          (block) =>
              block.type == target.type &&
              block.totalRounds == target.totalRounds,
        )
        .map((block) => block.id)
        .toSet();
  }

  /// Total logged sets attributed to [exerciseId] across every round of
  /// [blockId]. Used by the replace-confirmation dialog to show "you'll
  /// discard N sets" before the user commits.
  int loggedSetCountAcrossRoundsOf({
    required String blockId,
    required String exerciseId,
  }) {
    final roundIds = allRoundsOfBlock(blockId);
    return blocks
        .where((block) => roundIds.contains(block.id))
        .expand((block) => block.logs)
        .where((log) => log.exerciseId == exerciseId)
        .length;
  }
}
