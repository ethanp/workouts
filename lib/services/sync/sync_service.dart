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
import 'package:workouts/services/mappers.dart' as mappers;
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
    _pb = pocketBase ?? PocketBase(_defaultUrl);
  }

  static String get _defaultUrl {
    try {
      return dotenv.env['POCKETBASE_URL'] ?? 'http://localhost:8090';
    } catch (_) {
      return 'http://localhost:8090';
    }
  }

  final LocalDatabase _db;
  final void Function(String type)? onDataChanged;
  late final PocketBase _pb;
  final Connectivity _connectivity;
  final SessionConflictResolver _conflictResolver = SessionConflictResolver();
  bool _isSubscribed = false;
  final bool _forceOnline;

  bool get isSubscribed => _isSubscribed;

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  Future<bool> isOnline() async {
    if (_forceOnline) return true;
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sync orchestration
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // Push single records
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> pushTemplate(WorkoutTemplateRow row) async {
    if (!await isOnline()) {
      await _db.addToSyncQueue('push_template', row.id);
      return;
    }
    try {
      await _upsertTemplateRemote(row);
    } catch (_) {
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
      await _upsertSessionRemote(row, template!.remoteId!);
    } catch (_) {
      await _db.addToSyncQueue('push_session', row.id);
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
      if (!e.toString().contains('404')) {
        await _db.addToSyncQueue('delete_session', remoteId);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Subscriptions
  // ─────────────────────────────────────────────────────────────────────────

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
    final record = event.record;
    if (record == null) return;

    if (event.action == 'delete') {
      final local = (await _db.readTemplates())
          .where((r) => r.remoteId == record.id)
          .firstOrNull;
      if (local != null) {
        await _db.deleteTemplate(local.id);
        onDataChanged?.call('templates');
      }
      return;
    }

    final exists = (await _db.readTemplates()).any(
      (r) => r.remoteId == record.id,
    );
    if (exists) return;

    await _db.upsertTemplate(_templateCompanionFromRecord(record));
    onDataChanged?.call('templates');
  }

  Future<void> _handleSessionEvent(RecordSubscriptionEvent event) async {
    final record = event.record;
    if (record == null) return;

    if (event.action == 'delete') {
      final local = (await _db.readSessions())
          .where((r) => r.remoteId == record.id)
          .firstOrNull;
      if (local != null) {
        await _db.deleteSession(local.id);
        onDataChanged?.call('sessions');
      }
      return;
    }

    final remoteTemplateId = record.data['template_id'] as String;
    final template = await _db.readTemplateByRemoteId(remoteTemplateId);
    if (template == null) return;

    final existing = (await _db.readSessions())
        .where((r) => r.remoteId == record.id)
        .firstOrNull;

    if (existing != null) {
      final resolved = _conflictResolver.resolveConflict(
        mappers.sessionFromRow(existing),
        _sessionFromRecord(record, template.id),
      );
      await _db.upsertSession(_sessionCompanionFromModel(resolved, record.id));
    } else {
      await _db.upsertSession(_sessionCompanionFromRecord(record, template.id));
    }
    onDataChanged?.call('sessions');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Queue processing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> processQueue() async {
    if (!await isOnline()) return;

    for (final item in await _db.readSyncQueue()) {
      if (item.retryCount >= 3) continue;

      try {
        switch (item.operation) {
          case 'push_template':
            final t = await _db.readTemplateById(item.recordId);
            if (t != null) await _upsertTemplateRemote(t);
          case 'push_session':
            final s = await _db.readSessionById(item.recordId);
            if (s != null) {
              final t = await _db.readTemplateById(s.templateId);
              if (t?.remoteId != null)
                await _upsertSessionRemote(s, t!.remoteId!);
            }
          case 'delete_template':
            await _deleteRemote('templates', item.recordId);
          case 'delete_session':
            await _deleteRemote('sessions', item.recordId);
        }
        await _db.removeFromSyncQueue(item.id);
      } catch (_) {
        await _db.incrementQueueRetryCount(item.id);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bulk push/pull
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pushTemplates() async {
    for (final row in (await _db.readTemplates()).where(
      (r) => r.remoteId == null,
    )) {
      await _upsertTemplateRemote(row);
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
      if (!localRemoteIds.contains(record.id)) {
        await _db.upsertTemplate(_templateCompanionFromRecord(record));
      }
    }

    for (final row in localRows) {
      if (row.remoteId != null && !remoteIds.contains(row.remoteId)) {
        await _db.deleteTemplate(row.id);
      }
    }
  }

  Future<void> _pushSessions() async {
    for (final row in (await _db.readSessions()).where(
      (r) => r.remoteId == null,
    )) {
      final template = await _db.readTemplateById(row.templateId);
      if (template?.remoteId != null) {
        await _upsertSessionRemote(row, template!.remoteId!);
      }
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

      final template = await _db.readTemplateByRemoteId(
        record.data['template_id'] as String,
      );
      if (template != null) {
        await _db.upsertSession(
          _sessionCompanionFromRecord(record, template.id),
        );
      }
    }

    for (final row in localRows) {
      if (row.remoteId != null && !remoteIds.contains(row.remoteId)) {
        await _db.deleteSession(row.id);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Remote CRUD helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _upsertTemplateRemote(WorkoutTemplateRow row) async {
    final body = _templateBody(row);
    if (row.remoteId != null) {
      await _pb.collection('templates').update(row.remoteId!, body: body);
    } else {
      final record = await _pb.collection('templates').create(body: body);
      await _db.setTemplateRemoteId(row.id, record.id);
    }
  }

  Future<void> _upsertSessionRemote(
    SessionRow row,
    String remoteTemplateId,
  ) async {
    final body = _sessionBody(row, remoteTemplateId);
    if (row.remoteId != null) {
      await _pb.collection('sessions').update(row.remoteId!, body: body);
    } else {
      final record = await _pb.collection('sessions').create(body: body);
      await _db.setSessionRemoteId(row.id, record.id);
    }
  }

  Future<void> _deleteRemote(String collection, String remoteId) async {
    try {
      await _pb.collection(collection).delete(remoteId);
    } catch (e) {
      if (!e.toString().contains('404')) rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body builders (Row → API body)
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _templateBody(WorkoutTemplateRow row) => {
    'name': row.name,
    'goal': row.goal,
    'blocks_json': row.blocksJson,
    'notes': row.notes,
    'created_at': row.createdAt.toIso8601String(),
    'updated_at': row.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _sessionBody(SessionRow row, String remoteTemplateId) =>
      {
        'template_id': remoteTemplateId,
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
      };

  // ─────────────────────────────────────────────────────────────────────────
  // Companion builders (Record → Drift companion)
  // ─────────────────────────────────────────────────────────────────────────

  WorkoutTemplatesTableCompanion _templateCompanionFromRecord(
    RecordModel record,
  ) {
    return WorkoutTemplatesTableCompanion.insert(
      id: record.id,
      remoteId: Value(record.id),
      name: record.data['name'] as String,
      goal: record.data['goal'] as String,
      blocksJson: _ensureString(record.data['blocks_json']),
      notes: Value(record.data['notes'] as String?),
      createdAt:
          DateTime.tryParse(record.data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: Value(DateTime.tryParse(record.data['updated_at'] ?? '')),
      version: Value(TemplateRepository.currentTemplateVersion),
    );
  }

  SessionsTableCompanion _sessionCompanionFromRecord(
    RecordModel record,
    String templateId,
  ) {
    return SessionsTableCompanion.insert(
      id: record.id,
      remoteId: Value(record.id),
      templateId: templateId,
      startedAt: DateTime.parse(record.data['started_at'] as String),
      completedAt: Value(DateTime.tryParse(record.data['completed_at'] ?? '')),
      durationSeconds: Value(record.data['duration_seconds'] as int?),
      notes: Value(record.data['notes'] as String?),
      feeling: Value(record.data['feeling'] as String?),
      blocksJson: _ensureString(record.data['blocks_json']),
      breathSegmentsJson: _ensureString(
        record.data['breath_segments_json'] ?? [],
      ),
      isPaused: Value(record.data['is_paused'] as bool? ?? false),
      pausedAt: Value(DateTime.tryParse(record.data['paused_at'] ?? '')),
      totalPausedDurationSeconds: Value(
        record.data['total_paused_duration_seconds'] as int? ?? 0,
      ),
    );
  }

  SessionsTableCompanion _sessionCompanionFromModel(
    Session s,
    String remoteId,
  ) {
    return SessionsTableCompanion.insert(
      id: s.id,
      remoteId: Value(remoteId),
      templateId: s.templateId,
      startedAt: s.startedAt,
      completedAt: Value(s.completedAt),
      durationSeconds: Value(s.duration?.inSeconds),
      notes: Value(s.notes),
      feeling: Value(s.feeling),
      blocksJson: jsonEncode(s.blocks.map((b) => b.toJson()).toList()),
      breathSegmentsJson: jsonEncode(
        s.breathSegments.map((b) => b.toJson()).toList(),
      ),
      isPaused: Value(s.isPaused),
      pausedAt: Value(s.pausedAt),
      totalPausedDurationSeconds: Value(s.totalPausedDuration.inSeconds),
      updatedAt: Value(s.updatedAt ?? DateTime.now()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Model builders (Record/Row → Domain model)
  // ─────────────────────────────────────────────────────────────────────────

  Session _sessionFromRecord(RecordModel record, String templateId) {
    final blocksStr = _ensureString(record.data['blocks_json']);
    final breathStr = _ensureString(record.data['breath_segments_json'] ?? []);
    return Session(
      id: record.id,
      templateId: templateId,
      startedAt: DateTime.parse(record.data['started_at'] as String),
      completedAt: DateTime.tryParse(record.data['completed_at'] ?? ''),
      duration: record.data['duration_seconds'] != null
          ? Duration(seconds: record.data['duration_seconds'] as int)
          : null,
      notes: record.data['notes'] as String?,
      feeling: record.data['feeling'] as String?,
      blocks: (jsonDecode(blocksStr) as List)
          .map(
            (b) => SessionBlock.fromJson(Map<String, dynamic>.from(b as Map)),
          )
          .toList(),
      breathSegments: (jsonDecode(breathStr) as List)
          .map(
            (b) => BreathSegment.fromJson(Map<String, dynamic>.from(b as Map)),
          )
          .toList(),
      isPaused: record.data['is_paused'] as bool? ?? false,
      pausedAt: DateTime.tryParse(record.data['paused_at'] ?? ''),
      totalPausedDuration: Duration(
        seconds: record.data['total_paused_duration_seconds'] as int? ?? 0,
      ),
      updatedAt: DateTime.tryParse(record.data['updated_at'] ?? ''),
    );
  }

  String _ensureString(dynamic value) =>
      value is String ? value : jsonEncode(value);
}
