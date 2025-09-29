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

@DriftDatabase(tables: [WorkoutTemplatesTable, SessionsTable])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add pause-related columns to existing sessions
          await m.addColumn(sessionsTable, sessionsTable.isPaused);
          await m.addColumn(sessionsTable, sessionsTable.pausedAt);
          await m.addColumn(
            sessionsTable,
            sessionsTable.totalPausedDurationSeconds,
          );
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
