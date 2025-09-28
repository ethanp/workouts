import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/repositories/template_repository.dart';

part 'session_repository.g.dart';

const _uuid = Uuid();

class SessionRepository {
  SessionRepository(this._db, this._templateRepository);

  final LocalDatabase _db;
  final TemplateRepository _templateRepository;

  Future<Session> startSession(String templateId) async {
    final templates = await _templateRepository.fetchTemplates();
    final template = templates.firstWhere((item) => item.id == templateId);
    final now = DateTime.now();
    final sessionBlocks = <SessionBlock>[];

    for (var i = 0; i < template.blocks.length; i++) {
      final block = template.blocks[i];
      sessionBlocks.add(
        SessionBlock(
          id: _uuid.v4(),
          sessionId: 'pending',
          type: block.type,
          blockIndex: i,
          exercises: block.exercises,
          logs: const [],
          targetDuration: block.targetDuration,
        ),
      );
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

  Future<List<Session>> history() async {
    final rows = await _db.readSessions();
    final sessions = rows.map(_mapSession).toList();

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
    return row == null ? null : _mapSession(row);
  }

  Future<void> updateSession(Session session) async {
    await _persistSession(session);
  }

  Future<void> _persistSession(Session session) async {
    final blocksJson = session.blocks.map((block) => block.toJson()).toList();
    final breathJson = session.breathSegments
        .map((item) => item.toJson())
        .toList();
    await _db.upsertSession(
      SessionsTableCompanion.insert(
        id: session.id,
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
  }

  Session _mapSession(SessionRow data) {
    final blocksDynamic = jsonDecode(data.blocksJson) as List<dynamic>;
    final breathDynamic = jsonDecode(data.breathSegmentsJson) as List<dynamic>;

    final blocks = blocksDynamic
        .map(
          (raw) => SessionBlock.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList();
    final breath = breathDynamic
        .map(
          (raw) =>
              BreathSegment.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList();

    return Session(
      id: data.id,
      templateId: data.templateId,
      startedAt: data.startedAt,
      completedAt: data.completedAt,
      duration: data.durationSeconds != null
          ? Duration(seconds: data.durationSeconds!)
          : null,
      notes: data.notes,
      feeling: data.feeling,
      blocks: blocks,
      breathSegments: breath,
      isPaused: data.isPaused,
      pausedAt: data.pausedAt,
      totalPausedDuration: Duration(seconds: data.totalPausedDurationSeconds),
      updatedAt: data.updatedAt,
    );
  }
}

@riverpod
SessionRepository sessionRepository(Ref ref) {
  final db = ref.watch(localDatabaseProvider);
  final templates = ref.watch(templateRepositoryProvider);
  return SessionRepository(db, templates);
}
