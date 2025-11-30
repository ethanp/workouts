import 'package:workouts/models/session.dart';

class SessionConflictResolver {
  Session resolveConflict(Session local, Session remote) {
    final localUpdatedAt = local.updatedAt ?? local.startedAt;
    final remoteUpdatedAt = remote.updatedAt ?? remote.startedAt;

    // Session completion is a definitive action - always accept it
    final completedAt = remote.completedAt ?? local.completedAt;
    final duration = remote.duration ?? local.duration;

    // If remote is older but has completion data we don't have, still merge
    final remoteHasNewCompletion = remote.completedAt != null && local.completedAt == null;

    if (!remoteHasNewCompletion &&
        (remoteUpdatedAt.isBefore(localUpdatedAt) ||
         remoteUpdatedAt.isAtSameMomentAs(localUpdatedAt))) {
      return local;
    }

    final mergedBlocks = mergeBlocks(local.blocks, remote.blocks);
    final mergedBreathSegments =
        mergeBreathSegments(local.breathSegments, remote.breathSegments);
    final pauseState = resolvePauseState(local, remote);

    return local.copyWith(
      blocks: mergedBlocks,
      breathSegments: mergedBreathSegments,
      isPaused: pauseState.isPaused,
      pausedAt: pauseState.pausedAt,
      totalPausedDuration: pauseState.totalPausedDuration,
      completedAt: completedAt,
      duration: duration,
      notes: remote.notes ?? local.notes,
      feeling: remote.feeling ?? local.feeling,
      updatedAt: DateTime.now(),
    );
  }

  List<SessionSetLog> mergeLogs(
    List<SessionSetLog> localLogs,
    List<SessionSetLog> remoteLogs,
  ) {
    final logMap = <String, SessionSetLog>{};

    for (final log in localLogs) {
      logMap[log.id] = log;
    }

    for (final log in remoteLogs) {
      logMap[log.id] = log;
    }

    final grouped = <String, List<SessionSetLog>>{};
    for (final log in logMap.values) {
      final key = '${log.sessionBlockId}_${log.exerciseId}';
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final merged = <SessionSetLog>[];
    for (final group in grouped.values) {
      group.sort((a, b) => a.setIndex.compareTo(b.setIndex));
      for (var i = 0; i < group.length; i++) {
        merged.add(group[i].copyWith(setIndex: i));
      }
    }

    return merged;
  }

  _PauseState resolvePauseState(Session local, Session remote) {
    final localPausedAt = local.pausedAt;
    final remotePausedAt = remote.pausedAt;

    if (local.isPaused && remote.isPaused) {
      final latestPausedAt = localPausedAt != null && remotePausedAt != null
          ? (localPausedAt.isAfter(remotePausedAt) ? localPausedAt : remotePausedAt)
          : (localPausedAt ?? remotePausedAt);
      final totalPaused = local.totalPausedDuration + remote.totalPausedDuration;
      return _PauseState(
        isPaused: true,
        pausedAt: latestPausedAt,
        totalPausedDuration: totalPaused,
      );
    }

    if (local.isPaused && !remote.isPaused) {
      if (remotePausedAt == null || localPausedAt == null) {
        return _PauseState(
          isPaused: local.isPaused,
          pausedAt: localPausedAt,
          totalPausedDuration: local.totalPausedDuration,
        );
      }
      if (remotePausedAt.isAfter(localPausedAt)) {
        final pauseDuration = remotePausedAt.difference(localPausedAt);
        return _PauseState(
          isPaused: false,
          pausedAt: null,
          totalPausedDuration: local.totalPausedDuration + pauseDuration,
        );
      }
      return _PauseState(
        isPaused: true,
        pausedAt: localPausedAt,
        totalPausedDuration: local.totalPausedDuration,
      );
    }

    if (!local.isPaused && remote.isPaused) {
      if (localPausedAt == null || remotePausedAt == null) {
        return _PauseState(
          isPaused: remote.isPaused,
          pausedAt: remotePausedAt,
          totalPausedDuration: remote.totalPausedDuration,
        );
      }
      if (localPausedAt.isAfter(remotePausedAt)) {
        final pauseDuration = localPausedAt.difference(remotePausedAt);
        return _PauseState(
          isPaused: false,
          pausedAt: null,
          totalPausedDuration: remote.totalPausedDuration + pauseDuration,
        );
      }
      return _PauseState(
        isPaused: true,
        pausedAt: remotePausedAt,
        totalPausedDuration: remote.totalPausedDuration,
      );
    }

    return _PauseState(
      isPaused: false,
      pausedAt: null,
      totalPausedDuration: local.totalPausedDuration + remote.totalPausedDuration,
    );
  }

  List<SessionBlock> mergeBlocks(
    List<SessionBlock> localBlocks,
    List<SessionBlock> remoteBlocks,
  ) {
    final blockMap = <String, SessionBlock>{};

    for (final block in localBlocks) {
      blockMap[block.id] = block;
    }

    for (final block in remoteBlocks) {
      if (blockMap.containsKey(block.id)) {
        final localBlock = blockMap[block.id]!;
        final mergedLogs = mergeLogs(localBlock.logs, block.logs);
        blockMap[block.id] = localBlock.copyWith(logs: mergedLogs);
      } else {
        blockMap[block.id] = block;
      }
    }

    return blockMap.values.toList()
      ..sort((a, b) => a.blockIndex.compareTo(b.blockIndex));
  }

  List<BreathSegment> mergeBreathSegments(
    List<BreathSegment> localSegments,
    List<BreathSegment> remoteSegments,
  ) {
    final segmentMap = <String, BreathSegment>{};

    for (final segment in localSegments) {
      segmentMap[segment.id] = segment;
    }

    for (final segment in remoteSegments) {
      segmentMap[segment.id] = segment;
    }

    return segmentMap.values.toList();
  }
}

class _PauseState {
  _PauseState({
    required this.isPaused,
    required this.pausedAt,
    required this.totalPausedDuration,
  });

  final bool isPaused;
  final DateTime? pausedAt;
  final Duration totalPausedDuration;
}

