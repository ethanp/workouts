import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/mappers.dart' as mappers;
import 'package:workouts/services/repositories/template_repository.dart';
import 'package:workouts/services/sync/sync_service.dart';

part 'session_repository.g.dart';

const _uuid = Uuid();

class SessionRepository {
  SessionRepository(this._db, this._templateRepository, this._syncService);

  final LocalDatabase _db;
  final TemplateRepository _templateRepository;
  final SyncService _syncService;

  Future<Session> startSession(String templateId) async {
    final templates = await _templateRepository.fetchTemplates();
    final template = templates.firstWhere((item) => item.id == templateId);
    final now = DateTime.now();
    final sessionBlocks = <SessionBlock>[];
    var blockIndex = 0;

    for (final block in template.blocks) {
      final totalRounds = block.rounds <= 0 ? 1 : block.rounds;
      final hasMultipleRounds = totalRounds > 1;

      for (var round = 0; round < totalRounds; round++) {
        sessionBlocks.add(
          SessionBlock(
            id: _uuid.v4(),
            sessionId: 'pending',
            type: block.type,
            blockIndex: blockIndex,
            exercises: block.exercises,
            logs: const [],
            targetDuration: block.targetDuration,
            roundIndex: hasMultipleRounds ? round + 1 : null,
            totalRounds: hasMultipleRounds ? totalRounds : null,
          ),
        );
        blockIndex++;
      }
    }

    final session = Session(
      id: _uuid.v4(),
      templateId: template.id,
      startedAt: now,
      blocks: sessionBlocks,
      breathSegments: const [],
    );

    await _persistSession(session);
    return session;
  }

  Future<void> logSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
    required SessionSetLog log,
  }) async {
    final updatedBlocks = session.blocks.map((item) {
      if (item.id == block.id) {
        final logs = [...item.logs, log];
        return item.copyWith(logs: logs);
      }
      return item;
    }).toList();

    final updatedSession = session.copyWith(
      blocks: updatedBlocks,
      updatedAt: DateTime.now(),
    );
    await _persistSession(updatedSession);
  }

  Future<void> unlogSet({
    required Session session,
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    var logRemoved = false;
    final updatedBlocks = session.blocks.map((item) {
      if (item.id != block.id) {
        return item;
      }

      final removalIndex = item.logs.lastIndexWhere(
        (log) => log.exerciseId == exercise.id,
      );
      if (removalIndex == -1) {
        return item;
      }

      logRemoved = true;
      final trimmedLogs = [...item.logs]..removeAt(removalIndex);
      final normalizedLogs = [
        for (var i = 0; i < trimmedLogs.length; i++)
          trimmedLogs[i].copyWith(setIndex: i),
      ];

      return item.copyWith(logs: normalizedLogs);
    }).toList();

    if (!logRemoved) {
      return;
    }

    final updatedSession = session.copyWith(
      blocks: updatedBlocks,
      updatedAt: DateTime.now(),
    );
    await _persistSession(updatedSession);
  }

  Future<void> completeSession(
    Session session, {
    String? notes,
    String? feeling,
  }) async {
    final now = DateTime.now();
    var totalDuration =
        now.difference(session.startedAt) - session.totalPausedDuration;

    // If currently paused, add the current pause duration
    if (session.isPaused && session.pausedAt != null) {
      totalDuration -= now.difference(session.pausedAt!);
    }

    final completedSession = session.copyWith(
      completedAt: now,
      duration: totalDuration,
      notes: notes,
      feeling: feeling,
      isPaused: false,
      pausedAt: null,
      updatedAt: now,
    );
    await _persistSession(completedSession);
  }

  Future<void> discardSession(String id) async {
    final session = await _db.readSessionById(id);
    await _db.deleteSession(id);
    if (session?.remoteId != null) {
      unawaited(_syncService.deleteSessionRemote(session!.remoteId!));
    }
  }

  Future<void> discardAllInProgressSessions() async {
    final sessions = await history();
    final inProgressSessions = sessions
        .where((s) => s.completedAt == null)
        .toList();
    for (final session in inProgressSessions) {
      final row = await _db.readSessionById(session.id);
      await _db.deleteSession(session.id);
      if (row?.remoteId != null) {
        unawaited(_syncService.deleteSessionRemote(row!.remoteId!));
      }
    }
  }

  Future<List<Session>> history() async {
    final rows = await _db.readSessions();
    final sessions = rows.map(mappers.sessionFromRow).toList();

    // Sort with in-progress sessions first, then by most recent
    sessions.sort((a, b) {
      // In-progress sessions (no completedAt) come first
      if (a.completedAt == null && b.completedAt != null) return -1;
      if (a.completedAt != null && b.completedAt == null) return 1;

      // Within same status, sort by most recent first
      if (a.completedAt == null && b.completedAt == null) {
        return b.startedAt.compareTo(a.startedAt);
      } else {
        return b.completedAt!.compareTo(a.completedAt!);
      }
    });

    return sessions;
  }

  Future<Session?> fetchSessionById(String id) async {
    final row = await _db.readSessionById(id);
    return row == null ? null : mappers.sessionFromRow(row);
  }

  Future<void> updateSession(Session session) async {
    await _persistSession(session);
  }

  Future<Session> addExercise(
    Session session,
    String blockId,
    WorkoutExercise exercise,
  ) async {
    final targetBlock = session.blocks.firstWhere((b) => b.id == blockId);
    final siblingIds = _findSiblingBlockIds(session, targetBlock);

    final updatedBlocks = session.blocks.map((block) {
      if (!siblingIds.contains(block.id)) return block;
      return block.copyWith(exercises: [...block.exercises, exercise]);
    }).toList();

    final updatedSession = session.copyWith(
      blocks: updatedBlocks,
      updatedAt: DateTime.now(),
    );
    await _persistSession(updatedSession);
    return updatedSession;
  }

  Future<Session> removeExercise(
    Session session,
    String blockId,
    String exerciseId,
  ) async {
    final targetBlock = session.blocks.firstWhere((b) => b.id == blockId);
    final siblingIds = _findSiblingBlockIds(session, targetBlock);

    final updatedBlocks = session.blocks.map((block) {
      if (!siblingIds.contains(block.id)) return block;
      return block.copyWith(
        exercises: block.exercises.where((e) => e.id != exerciseId).toList(),
        logs: block.logs.where((l) => l.exerciseId != exerciseId).toList(),
      );
    }).toList();

    final updatedSession = session.copyWith(
      blocks: updatedBlocks,
      updatedAt: DateTime.now(),
    );
    await _persistSession(updatedSession);
    return updatedSession;
  }

  Set<String> _findSiblingBlockIds(Session session, SessionBlock target) {
    if (target.totalRounds == null) return {target.id};
    return session.blocks
        .where(
          (b) => b.type == target.type && b.totalRounds == target.totalRounds,
        )
        .map((b) => b.id)
        .toSet();
  }

  Future<void> _persistSession(Session session) async {
    final blocksJson = session.blocks.map((block) => block.toJson()).toList();
    final breathJson = session.breathSegments
        .map((item) => item.toJson())
        .toList();

    // Preserve existing remoteId if the session already exists
    final existing = await _db.readSessionById(session.id);
    final remoteId = existing?.remoteId;

    await _db.upsertSession(
      SessionsTableCompanion.insert(
        id: session.id,
        remoteId: Value(remoteId),
        templateId: session.templateId,
        startedAt: session.startedAt,
        completedAt: Value(session.completedAt),
        durationSeconds: Value(session.duration?.inSeconds),
        notes: Value(session.notes),
        feeling: Value(session.feeling),
        blocksJson: jsonEncode(blocksJson),
        breathSegmentsJson: jsonEncode(breathJson),
        isPaused: Value(session.isPaused),
        pausedAt: Value(session.pausedAt),
        totalPausedDurationSeconds: Value(
          session.totalPausedDuration.inSeconds,
        ),
        updatedAt: Value(session.updatedAt ?? DateTime.now()),
      ),
    );

    final row = await _db.readSessionById(session.id);
    if (row != null) {
      unawaited(_syncService.pushSession(row));
    }
  }
}

@riverpod
SessionRepository sessionRepository(Ref ref) {
  final db = ref.watch(localDatabaseProvider);
  final templates = ref.watch(templateRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return SessionRepository(db, templates, syncService);
}
