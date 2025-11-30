import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/repositories/template_repository.dart';
import 'package:workouts/services/sync/session_conflict_resolver.dart';

class SyncService {
  SyncService(
    this._db, {
    this.onDataChanged,
    PocketBase? pocketBase,
    Connectivity? connectivity,
    bool forceOnline = false,
  }) : _connectivity = connectivity ?? Connectivity(),
       _forceOnline = forceOnline {
    if (pocketBase != null) {
      _pb = pocketBase;
    } else {
      String url;
      try {
        url = dotenv.env['POCKETBASE_URL'] ?? 'http://localhost:8090';
      } catch (_) {
        url = 'http://localhost:8090';
      }
      _pb = PocketBase(url);
    }
  }

  final LocalDatabase _db;
  final void Function(String type)? onDataChanged;
  late final PocketBase _pb;
  final Connectivity _connectivity;
  final SessionConflictResolver _conflictResolver = SessionConflictResolver();
  bool _isSubscribed = false;
  final bool _forceOnline; // For testing

  bool get isSubscribed => _isSubscribed;

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  Future<bool> isOnline() async {
    if (_forceOnline) return true;
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // In tests, connectivity might not be available
      return true; // Assume online for tests
    }
  }

  Future<void> syncAll() async {
    if (!await isOnline()) return;
    await processQueue();
    await syncTemplates();
    await syncSessions();
  }

  Future<void> syncTemplates() async {
    if (!await isOnline()) return;
    await _pushTemplates();
    await _pullTemplates();
  }

  Future<void> syncSessions() async {
    if (!await isOnline()) return;
    await _pushSessions();
    await _pullSessions();
  }

  Future<void> pushTemplate(WorkoutTemplateRow row) async {
    if (!await isOnline()) {
      await _db.addToSyncQueue('push_template', row.id);
      return;
    }

    try {
      if (row.remoteId != null) {
        await _pb
            .collection('templates')
            .update(
              row.remoteId!,
              body: {
                'name': row.name,
                'goal': row.goal,
                'blocks_json': row.blocksJson,
                'notes': row.notes,
                'created_at': row.createdAt.toIso8601String(),
                'updated_at': row.updatedAt?.toIso8601String(),
              },
            );
      } else {
        final record = await _pb
            .collection('templates')
            .create(
              body: {
                'name': row.name,
                'goal': row.goal,
                'blocks_json': row.blocksJson,
                'notes': row.notes,
                'created_at': row.createdAt.toIso8601String(),
                'updated_at': row.updatedAt?.toIso8601String(),
              },
            );
        await _db.setTemplateRemoteId(row.id, record.id);
      }
    } catch (e) {
      await _db.addToSyncQueue('push_template', row.id);
    }
  }

  Future<void> pushSession(SessionRow row) async {
    if (!await isOnline()) {
      await _db.addToSyncQueue('push_session', row.id);
      return;
    }

    final template = await _db.readTemplateById(row.templateId);
    if (template?.remoteId == null) {
      await _db.addToSyncQueue('push_session', row.id);
      return;
    }

    try {
      if (row.remoteId != null) {
        await _pb
            .collection('sessions')
            .update(
              row.remoteId!,
              body: {
                'template_id': template!.remoteId,
                'started_at': row.startedAt.toIso8601String(),
                'completed_at': row.completedAt?.toIso8601String(),
                'duration_seconds': row.durationSeconds,
                'notes': row.notes,
                'feeling': row.feeling,
                'blocks_json': row.blocksJson,
                'breath_segments_json': row.breathSegmentsJson,
                'is_paused': row.isPaused,
                'paused_at': row.pausedAt?.toIso8601String(),
                'total_paused_duration_seconds': row.totalPausedDurationSeconds,
                'updated_at': row.updatedAt.toIso8601String(),
              },
            );
      } else {
        final record = await _pb
            .collection('sessions')
            .create(
              body: {
                'template_id': template!.remoteId,
                'started_at': row.startedAt.toIso8601String(),
                'completed_at': row.completedAt?.toIso8601String(),
                'duration_seconds': row.durationSeconds,
                'notes': row.notes,
                'feeling': row.feeling,
                'blocks_json': row.blocksJson,
                'breath_segments_json': row.breathSegmentsJson,
                'is_paused': row.isPaused,
                'paused_at': row.pausedAt?.toIso8601String(),
                'total_paused_duration_seconds': row.totalPausedDurationSeconds,
                'updated_at': row.updatedAt.toIso8601String(),
              },
            );
        await _db.setSessionRemoteId(row.id, record.id);
      }
    } catch (e) {
      await _db.addToSyncQueue('push_session', row.id);
    }
  }

  Future<void> subscribe() async {
    if (_isSubscribed) return;
    _isSubscribed = true;

    _pb.collection('templates').subscribe('*', _handleTemplateEvent);
    _pb.collection('sessions').subscribe('*', _handleSessionEvent);
  }

  Future<void> unsubscribe() async {
    if (!_isSubscribed) return;
    _isSubscribed = false;

    _pb.collection('templates').unsubscribe('*');
    _pb.collection('sessions').unsubscribe('*');
  }

  Future<void> _handleTemplateEvent(RecordSubscriptionEvent event) async {
    if (event.action == 'delete') {
      final deletedId = event.record?.id;
      if (deletedId != null) {
        final localTemplate = await _db.readTemplates();
        final toDelete = localTemplate
            .where((r) => r.remoteId == deletedId)
            .firstOrNull;
        if (toDelete != null) {
          await _db.deleteTemplate(toDelete.id);
          onDataChanged?.call('templates');
        }
      }
      return;
    }

    final record = event.record!;
    final localRows = await _db.readTemplates();
    final existing = localRows
        .where((r) => r.remoteId == record.id)
        .firstOrNull;
    if (existing != null) return;

    final blocksString = _ensureString(record.data['blocks_json']);
    final companion = WorkoutTemplatesTableCompanion.insert(
      id: record.id,
      remoteId: Value(record.id),
      name: record.data['name'] as String,
      goal: record.data['goal'] as String,
      blocksJson: blocksString,
      notes: Value(record.data['notes'] as String?),
      createdAt:
          DateTime.tryParse(record.data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: Value(DateTime.tryParse(record.data['updated_at'] ?? '')),
      version: Value(TemplateRepository.currentTemplateVersion),
    );
    await _db.upsertTemplate(companion);
    onDataChanged?.call('templates');
  }

  Future<void> _handleSessionEvent(RecordSubscriptionEvent event) async {
    if (event.action == 'delete') {
      final deletedId = event.record?.id;
      if (deletedId != null) {
        final localSessions = await _db.readSessions();
        final toDelete = localSessions
            .where((r) => r.remoteId == deletedId)
            .firstOrNull;
        if (toDelete != null) {
          await _db.deleteSession(toDelete.id);
          onDataChanged?.call('sessions');
        }
      }
      return;
    }

    final record = event.record!;
    final localRows = await _db.readSessions();
    final existing = localRows
        .where((r) => r.remoteId == record.id)
        .firstOrNull;

    final remoteTemplateId = record.data['template_id'] as String;
    final template = await _db.readTemplateByRemoteId(remoteTemplateId);
    if (template == null) return;

    final blocksString = _ensureString(record.data['blocks_json']);
    final breathString = _ensureString(
      record.data['breath_segments_json'] ?? [],
    );

    if (existing != null) {
      final localSession = sessionFromRow(existing);
      final remoteSession = Session(
        id: record.id,
        templateId: template.id,
        startedAt: DateTime.parse(record.data['started_at'] as String),
        completedAt: DateTime.tryParse(record.data['completed_at'] ?? ''),
        duration: record.data['duration_seconds'] != null
            ? Duration(seconds: record.data['duration_seconds'] as int)
            : null,
        notes: record.data['notes'] as String?,
        feeling: record.data['feeling'] as String?,
        blocks: (jsonDecode(blocksString) as List<dynamic>)
            .map(
              (b) => SessionBlock.fromJson(Map<String, dynamic>.from(b as Map)),
            )
            .toList(),
        breathSegments: (jsonDecode(breathString) as List<dynamic>)
            .map(
              (b) =>
                  BreathSegment.fromJson(Map<String, dynamic>.from(b as Map)),
            )
            .toList(),
        isPaused: record.data['is_paused'] as bool? ?? false,
        pausedAt: DateTime.tryParse(record.data['paused_at'] ?? ''),
        totalPausedDuration: Duration(
          seconds: record.data['total_paused_duration_seconds'] as int? ?? 0,
        ),
        updatedAt: DateTime.tryParse(record.data['updated_at'] ?? ''),
      );

      final resolved = _conflictResolver.resolveConflict(
        localSession,
        remoteSession,
      );

      final resolvedBlocksJson = jsonEncode(
        resolved.blocks.map((b) => b.toJson()).toList(),
      );
      final resolvedBreathJson = jsonEncode(
        resolved.breathSegments.map((b) => b.toJson()).toList(),
      );

      final companion = SessionsTableCompanion.insert(
        id: resolved.id,
        remoteId: Value(record.id),
        templateId: resolved.templateId,
        startedAt: resolved.startedAt,
        completedAt: Value(resolved.completedAt),
        durationSeconds: Value(resolved.duration?.inSeconds),
        notes: Value(resolved.notes),
        feeling: Value(resolved.feeling),
        blocksJson: resolvedBlocksJson,
        breathSegmentsJson: resolvedBreathJson,
        isPaused: Value(resolved.isPaused),
        pausedAt: Value(resolved.pausedAt),
        totalPausedDurationSeconds: Value(
          resolved.totalPausedDuration.inSeconds,
        ),
        updatedAt: Value(resolved.updatedAt ?? DateTime.now()),
      );
      await _db.upsertSession(companion);
      onDataChanged?.call('sessions');
      return;
    }

    final companion = SessionsTableCompanion.insert(
      id: record.id,
      remoteId: Value(record.id),
      templateId: template.id,
      startedAt: DateTime.parse(record.data['started_at'] as String),
      completedAt: Value(DateTime.tryParse(record.data['completed_at'] ?? '')),
      durationSeconds: Value(record.data['duration_seconds'] as int?),
      notes: Value(record.data['notes'] as String?),
      feeling: Value(record.data['feeling'] as String?),
      blocksJson: blocksString,
      breathSegmentsJson: breathString,
      isPaused: Value(record.data['is_paused'] as bool? ?? false),
      pausedAt: Value(DateTime.tryParse(record.data['paused_at'] ?? '')),
      totalPausedDurationSeconds: Value(
        record.data['total_paused_duration_seconds'] as int? ?? 0,
      ),
    );
    await _db.upsertSession(companion);
    onDataChanged?.call('sessions');
  }

  Future<void> processQueue() async {
    if (!await isOnline()) return;

    final queueItems = await _db.readSyncQueue();
    for (final item in queueItems) {
      // Skip items that have failed too many times (max 3 retries)
      if (item.retryCount >= 3) continue;

      try {
        switch (item.operation) {
          case 'push_template':
            final template = await _db.readTemplateById(item.recordId);
            if (template != null) {
              await _pushSingleTemplate(template);
            }
          case 'push_session':
            final session = await _db.readSessionById(item.recordId);
            if (session != null) {
              await _pushSingleSession(session);
            }
          case 'delete_template':
            await _deleteTemplate(item.recordId);
          case 'delete_session':
            await _deleteSession(item.recordId);
        }
        // Success - remove from queue
        await _db.removeFromSyncQueue(item.id);
      } catch (e) {
        // Failure - increment retry count
        await _db.incrementQueueRetryCount(item.id);
      }
    }
  }

  Future<void> _pushSingleTemplate(WorkoutTemplateRow row) async {
    if (row.remoteId != null) {
      await _pb
          .collection('templates')
          .update(
            row.remoteId!,
            body: {
              'name': row.name,
              'goal': row.goal,
              'blocks_json': row.blocksJson,
              'notes': row.notes,
              'created_at': row.createdAt.toIso8601String(),
              'updated_at': row.updatedAt?.toIso8601String(),
            },
          );
    } else {
      final record = await _pb
          .collection('templates')
          .create(
            body: {
              'name': row.name,
              'goal': row.goal,
              'blocks_json': row.blocksJson,
              'notes': row.notes,
              'created_at': row.createdAt.toIso8601String(),
              'updated_at': row.updatedAt?.toIso8601String(),
            },
          );
      await _db.setTemplateRemoteId(row.id, record.id);
    }
  }

  Future<void> _pushSingleSession(SessionRow row) async {
    final template = await _db.readTemplateById(row.templateId);
    if (template?.remoteId == null) throw Exception('Template not synced');

    if (row.remoteId != null) {
      await _pb
          .collection('sessions')
          .update(
            row.remoteId!,
            body: {
              'template_id': template!.remoteId,
              'started_at': row.startedAt.toIso8601String(),
              'completed_at': row.completedAt?.toIso8601String(),
              'duration_seconds': row.durationSeconds,
              'notes': row.notes,
              'feeling': row.feeling,
              'blocks_json': row.blocksJson,
              'breath_segments_json': row.breathSegmentsJson,
              'is_paused': row.isPaused,
              'paused_at': row.pausedAt?.toIso8601String(),
              'total_paused_duration_seconds': row.totalPausedDurationSeconds,
              'updated_at': row.updatedAt.toIso8601String(),
            },
          );
    } else {
      final record = await _pb
          .collection('sessions')
          .create(
            body: {
              'template_id': template!.remoteId,
              'started_at': row.startedAt.toIso8601String(),
              'completed_at': row.completedAt?.toIso8601String(),
              'duration_seconds': row.durationSeconds,
              'notes': row.notes,
              'feeling': row.feeling,
              'blocks_json': row.blocksJson,
              'breath_segments_json': row.breathSegmentsJson,
              'is_paused': row.isPaused,
              'paused_at': row.pausedAt?.toIso8601String(),
              'total_paused_duration_seconds': row.totalPausedDurationSeconds,
              'updated_at': row.updatedAt.toIso8601String(),
            },
          );
      await _db.setSessionRemoteId(row.id, record.id);
    }
  }

  Future<void> _pushTemplates() async {
    final localRows = await _db.readTemplates();
    final toPush = localRows.where((r) => r.remoteId == null);

    for (final row in toPush) {
      final record = await _pb
          .collection('templates')
          .create(
            body: {
              'name': row.name,
              'goal': row.goal,
              'blocks_json': row.blocksJson,
              'notes': row.notes,
              'created_at': row.createdAt.toIso8601String(),
              'updated_at': row.updatedAt?.toIso8601String(),
            },
          );
      await _db.setTemplateRemoteId(row.id, record.id);
    }
  }

  Future<void> _pullTemplates() async {
    final remoteRecords = await _pb.collection('templates').getFullList();
    final remoteIds = remoteRecords.map((r) => r.id).toSet();
    final localRows = await _db.readTemplates();
    final localRemoteIds = localRows
        .map((r) => r.remoteId)
        .whereType<String>()
        .toSet();

    for (final record in remoteRecords) {
      if (localRemoteIds.contains(record.id)) continue;

      final blocksString = _ensureString(record.data['blocks_json']);

      final companion = WorkoutTemplatesTableCompanion.insert(
        id: record.id,
        remoteId: Value(record.id),
        name: record.data['name'] as String,
        goal: record.data['goal'] as String,
        blocksJson: blocksString,
        notes: Value(record.data['notes'] as String?),
        createdAt:
            DateTime.tryParse(record.data['created_at'] ?? '') ??
            DateTime.now(),
        updatedAt: Value(DateTime.tryParse(record.data['updated_at'] ?? '')),
        version: Value(TemplateRepository.currentTemplateVersion),
      );
      await _db.upsertTemplate(companion);
    }

    for (final localRow in localRows) {
      if (localRow.remoteId != null && !remoteIds.contains(localRow.remoteId)) {
        await _db.deleteTemplate(localRow.id);
      }
    }
  }

  Future<void> _pushSessions() async {
    final localRows = await _db.readSessions();
    final toPush = localRows.where((r) => r.remoteId == null);

    for (final row in toPush) {
      final template = await _db.readTemplateById(row.templateId);
      if (template?.remoteId == null) continue;

      final record = await _pb
          .collection('sessions')
          .create(
            body: {
              'template_id': template!.remoteId,
              'started_at': row.startedAt.toIso8601String(),
              'completed_at': row.completedAt?.toIso8601String(),
              'duration_seconds': row.durationSeconds,
              'notes': row.notes,
              'feeling': row.feeling,
              'blocks_json': row.blocksJson,
              'breath_segments_json': row.breathSegmentsJson,
              'is_paused': row.isPaused,
              'paused_at': row.pausedAt?.toIso8601String(),
              'total_paused_duration_seconds': row.totalPausedDurationSeconds,
              'updated_at': row.updatedAt.toIso8601String(),
            },
          );
      await _db.setSessionRemoteId(row.id, record.id);
    }
  }

  Future<void> _pullSessions() async {
    final remoteRecords = await _pb.collection('sessions').getFullList();
    final remoteIds = remoteRecords.map((r) => r.id).toSet();
    final localRows = await _db.readSessions();
    final localRemoteIds = localRows
        .map((r) => r.remoteId)
        .whereType<String>()
        .toSet();

    for (final record in remoteRecords) {
      if (localRemoteIds.contains(record.id)) continue;

      final remoteTemplateId = record.data['template_id'] as String;
      final template = await _db.readTemplateByRemoteId(remoteTemplateId);
      if (template == null) continue;

      final blocksString = _ensureString(record.data['blocks_json']);
      final breathString = _ensureString(
        record.data['breath_segments_json'] ?? [],
      );

      final companion = SessionsTableCompanion.insert(
        id: record.id,
        remoteId: Value(record.id),
        templateId: template.id,
        startedAt: DateTime.parse(record.data['started_at'] as String),
        completedAt: Value(
          DateTime.tryParse(record.data['completed_at'] ?? ''),
        ),
        durationSeconds: Value(record.data['duration_seconds'] as int?),
        notes: Value(record.data['notes'] as String?),
        feeling: Value(record.data['feeling'] as String?),
        blocksJson: blocksString,
        breathSegmentsJson: breathString,
        isPaused: Value(record.data['is_paused'] as bool? ?? false),
        pausedAt: Value(DateTime.tryParse(record.data['paused_at'] ?? '')),
        totalPausedDurationSeconds: Value(
          record.data['total_paused_duration_seconds'] as int? ?? 0,
        ),
      );
      await _db.upsertSession(companion);
    }

    for (final localRow in localRows) {
      if (localRow.remoteId != null && !remoteIds.contains(localRow.remoteId)) {
        await _db.deleteSession(localRow.id);
      }
    }
  }

  WorkoutTemplate templateFromRow(WorkoutTemplateRow row) {
    final blocksJson = jsonDecode(row.blocksJson) as List<dynamic>;
    final blocks = blocksJson
        .map((b) => WorkoutBlock.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
    return WorkoutTemplate(
      id: row.id,
      name: row.name,
      goal: row.goal,
      blocks: blocks,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      notes: row.notes,
    );
  }

  Future<void> _deleteTemplate(String remoteId) async {
    try {
      await _pb.collection('templates').delete(remoteId);
    } catch (e) {
      if (e.toString().contains('404')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteSessionRemote(String remoteId) async {
    if (!await isOnline()) {
      await _db.addToSyncQueue('delete_session', remoteId);
      return;
    }

    try {
      await _pb.collection('sessions').delete(remoteId);
    } catch (e) {
      if (e.toString().contains('404')) {
        return;
      }
      await _db.addToSyncQueue('delete_session', remoteId);
    }
  }

  Future<void> _deleteSession(String remoteId) async {
    try {
      await _pb.collection('sessions').delete(remoteId);
    } catch (e) {
      if (e.toString().contains('404')) {
        return;
      }
      rethrow;
    }
  }

  String _ensureString(dynamic value) =>
      value is String ? value : jsonEncode(value);

  Session sessionFromRow(SessionRow row) {
    final blocksJson = jsonDecode(row.blocksJson) as List<dynamic>;
    final blocks = blocksJson
        .map((b) => SessionBlock.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
    final breathJson = jsonDecode(row.breathSegmentsJson) as List<dynamic>;
    final breathSegments = breathJson
        .map((b) => BreathSegment.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
    return Session(
      id: row.id,
      templateId: row.templateId,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      duration: row.durationSeconds != null
          ? Duration(seconds: row.durationSeconds!)
          : null,
      notes: row.notes,
      feeling: row.feeling,
      blocks: blocks,
      breathSegments: breathSegments,
      isPaused: row.isPaused,
      pausedAt: row.pausedAt,
      totalPausedDuration: Duration(seconds: row.totalPausedDurationSeconds),
      updatedAt: row.updatedAt,
    );
  }
}
