import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_database.g.dart';

@DataClassName('WorkoutTemplateRow')
class WorkoutTemplatesTable extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get goal => text()();
  TextColumn get blocksJson => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DataClassName('SessionRow')
class SessionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get templateId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get feeling => text().nullable()();
  TextColumn get blocksJson => text()();
  TextColumn get breathSegmentsJson => text()();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  IntColumn get totalPausedDurationSeconds =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DataClassName('SyncQueueRow')
class SyncQueueTable extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()(); // 'push_template', 'push_session'
  TextColumn get recordId => text()(); // Local record ID
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(tables: [WorkoutTemplatesTable, SessionsTable, SyncQueueTable])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async => m.createAll(),
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(sessionsTable, sessionsTable.isPaused);
          await m.addColumn(sessionsTable, sessionsTable.pausedAt);
          await m.addColumn(
            sessionsTable,
            sessionsTable.totalPausedDurationSeconds,
          );
        }
        if (from < 3) {
          await m.addColumn(
            workoutTemplatesTable,
            workoutTemplatesTable.remoteId,
          );
          await m.addColumn(sessionsTable, sessionsTable.remoteId);
        }
        if (from < 4) {
          await m.createTable(syncQueueTable);
        }
      },
    );
  }

  Future<void> upsertTemplate(WorkoutTemplatesTableCompanion companion) async {
    await into(workoutTemplatesTable).insertOnConflictUpdate(companion);
  }

  Future<List<WorkoutTemplateRow>> readTemplates() async {
    return select(workoutTemplatesTable).get();
  }

  Future<List<SessionRow>> readSessions() async {
    return (select(
      sessionsTable,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)])).get();
  }

  Future<SessionRow?> readSessionById(String id) async {
    return (select(
      sessionsTable,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertSession(SessionsTableCompanion companion) async {
    await into(sessionsTable).insertOnConflictUpdate(companion);
  }

  Future<void> deleteSession(String id) async {
    await (delete(sessionsTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> deleteTemplate(String id) async {
    await (delete(workoutTemplatesTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setTemplateRemoteId(String localId, String remoteId) async {
    await (update(workoutTemplatesTable)..where((t) => t.id.equals(localId)))
        .write(WorkoutTemplatesTableCompanion(remoteId: Value(remoteId)));
  }

  Future<void> setSessionRemoteId(String localId, String remoteId) async {
    await (update(sessionsTable)..where((t) => t.id.equals(localId))).write(
      SessionsTableCompanion(remoteId: Value(remoteId)),
    );
  }

  Future<WorkoutTemplateRow?> readTemplateById(String id) async {
    return (select(
      workoutTemplatesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<WorkoutTemplateRow?> readTemplateByRemoteId(String remoteId) async {
    return (select(
      workoutTemplatesTable,
    )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
  }

  Future<void> addToSyncQueue(String operation, String recordId) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await into(syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: id,
        operation: operation,
        recordId: recordId,
      ),
    );
  }

  Future<List<SyncQueueRow>> readSyncQueue() async {
    return (select(
      syncQueueTable,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
  }

  Future<void> removeFromSyncQueue(String queueId) async {
    await (delete(syncQueueTable)..where((t) => t.id.equals(queueId))).go();
  }

  Future<void> incrementQueueRetryCount(String queueId) async {
    final row = await (select(
      syncQueueTable,
    )..where((t) => t.id.equals(queueId))).getSingle();
    await (update(syncQueueTable)..where((t) => t.id.equals(queueId))).write(
      SyncQueueTableCompanion(retryCount: Value(row.retryCount + 1)),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'workouts.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@Riverpod(keepAlive: true)
LocalDatabase localDatabase(Ref ref) {
  return LocalDatabase();
}
