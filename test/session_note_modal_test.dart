import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';
import 'package:workouts/screens/session_resume_screen.dart';
import 'package:workouts/services/repositories/session_notes_repository_powersync.dart';
import 'support/fake_health_kit_bridge.dart';

class FakeActiveSessionNotifier extends ActiveSessionNotifier {
  FakeActiveSessionNotifier(this.session);

  final Session session;

  @override
  Future<Session?> build() async => session;
}

class FakeSessionNotesRepository implements SessionNotesRepository {
  FakeSessionNotesRepository({required this.shouldFail});

  final bool shouldFail;
  static const errorLine =
      '[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] '
      'Unhandled Exception: SqliteException(1): while preparing statement, '
      'cannot UPSERT a view, SQL logic error (code 1)';

  @override
  Stream<List<SessionNote>> watchNotesForSession(String sessionId) =>
      const Stream.empty();

  @override
  Future<List<SessionNote>> fetchNotesForSession(String sessionId) async => [];

  @override
  Future<void> saveNote(SessionNote note) async {
    if (shouldFail) {
      throw Exception(errorLine);
    }
  }

  @override
  Future<void> deleteNote(String id) async {}
}

void main() {
  testWidgets('dismisses Add Note modal after save', (tester) async {
    final exercise = WorkoutExercise(
      id: 'exercise-1',
      name: 'Kettlebell Swing',
      modality: ExerciseModality.reps,
      prescription: '3 x 10',
    );
    final block = SessionBlock(
      id: 'block-1',
      sessionId: 'session-1',
      type: WorkoutBlockType.strength,
      blockIndex: 0,
      exercises: [exercise],
      logs: const [],
      targetDuration: const Duration(minutes: 5),
    );
    final session = Session(
      id: 'session-1',
      templateId: 'template-1',
      startedAt: DateTime(2026, 1, 18, 10),
      blocks: [block],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionProvider.overrideWith(
            () => FakeActiveSessionNotifier(session),
          ),
          sessionNotesRepositoryPowerSyncProvider.overrideWith(
            (ref) => FakeSessionNotesRepository(shouldFail: false),
          ),
          watchConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          healthKitBridgeProvider.overrideWithValue(FakeHealthKitBridge()),
        ],
        child: const CupertinoApp(
          home: SessionResumeScreen(sessionId: 'session-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CupertinoButton, 'Note'));
    await tester.pumpAndSettle();

    expect(find.text('Add Note'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'starting up');
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add Note'), findsNothing);
  });

  testWidgets('keeps Add Note modal open on save error', (tester) async {
    final exercise = WorkoutExercise(
      id: 'exercise-1',
      name: 'Kettlebell Swing',
      modality: ExerciseModality.reps,
      prescription: '3 x 10',
    );
    final block = SessionBlock(
      id: 'block-1',
      sessionId: 'session-1',
      type: WorkoutBlockType.strength,
      blockIndex: 0,
      exercises: [exercise],
      logs: const [],
      targetDuration: const Duration(minutes: 5),
    );
    final session = Session(
      id: 'session-1',
      templateId: 'template-1',
      startedAt: DateTime(2026, 1, 18, 10),
      blocks: [block],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionProvider.overrideWith(
            () => FakeActiveSessionNotifier(session),
          ),
          sessionNotesRepositoryPowerSyncProvider.overrideWith(
            (ref) => FakeSessionNotesRepository(shouldFail: true),
          ),
          watchConnectionStatusProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          healthKitBridgeProvider.overrideWithValue(FakeHealthKitBridge()),
        ],
        child: const CupertinoApp(
          home: SessionResumeScreen(sessionId: 'session-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField), 'starting up');
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Add Note'), findsOneWidget);
    expect(find.text(FakeSessionNotesRepository.errorLine), findsOneWidget);
  });
}
