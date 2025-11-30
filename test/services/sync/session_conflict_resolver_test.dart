import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/services/sync/session_conflict_resolver.dart';

import 'session_test_helpers.dart';

void main() {
  group('Session Conflict Resolution', () {
    late SessionConflictResolver resolver;

    setUp(() {
      resolver = SessionConflictResolver();
    });

    group('Log Merging', () {
      test('merges unique logs from both versions', () {
        final localLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 10,
          ),
          createTestLog(
            id: 'log2',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 1,
            reps: 12,
          ),
        ];

        final remoteLogs = [
          createTestLog(
            id: 'log3',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 8,
          ),
        ];

        final merged = resolver.mergeLogs(localLogs, remoteLogs);

        expect(merged.length, 3);
        expect(merged.map((l) => l.id).toSet(), {'log1', 'log2', 'log3'});
      });

      test('deduplicates logs by ID', () {
        final localLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 10,
          ),
        ];

        final remoteLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 12,
          ),
        ];

        final merged = resolver.mergeLogs(localLogs, remoteLogs);

        expect(merged.length, 1);
        expect(merged.first.id, 'log1');
        expect(merged.first.reps, 12);
      });

      test('reindexes setIndex sequentially', () {
        final localLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 10,
          ),
          createTestLog(
            id: 'log2',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 2,
            reps: 12,
          ),
        ];

        final remoteLogs = [
          createTestLog(
            id: 'log3',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 1,
            reps: 11,
          ),
        ];

        final merged = resolver.mergeLogs(localLogs, remoteLogs);

        expect(merged.length, 3);
        expect(merged[0].setIndex, 0);
        expect(merged[1].setIndex, 1);
        expect(merged[2].setIndex, 2);
      });

      test('handles empty logs', () {
        final merged = resolver.mergeLogs([], []);
        expect(merged, isEmpty);
      });

      test('handles all logs with same ID gracefully', () {
        final localLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 10,
          ),
        ];

        final remoteLogs = [
          createTestLog(
            id: 'log1',
            sessionBlockId: 'block1',
            exerciseId: 'ex1',
            setIndex: 0,
            reps: 12,
          ),
        ];

        final merged = resolver.mergeLogs(localLogs, remoteLogs);
        expect(merged.length, 1);
        expect(merged.first.reps, 12);
      });
    });

    group('Pause State Resolution', () {
      test('sums totalPausedDuration when both paused', () {
        final local = SessionBuilder()
            .pausedAt(DateTime(2024, 1, 1, 10, 0))
            .withTotalPausedDuration(Duration(minutes: 5))
            .build()
            .copyWith(isPaused: true);

        final remote = SessionBuilder()
            .pausedAt(DateTime(2024, 1, 1, 10, 5))
            .withTotalPausedDuration(Duration(minutes: 3))
            .build()
            .copyWith(isPaused: true);

        final state = resolver.resolvePauseState(local, remote);

        expect(state.isPaused, true);
        expect(state.totalPausedDuration.inMinutes, 8);
      });

      test('uses later action for pause/resume conflict', () {
        final local = SessionBuilder()
            .pausedAt(DateTime(2024, 1, 1, 10, 0))
            .withTotalPausedDuration(Duration(minutes: 5))
            .build()
            .copyWith(isPaused: true);

        final remote = SessionBuilder()
            .pausedAt(DateTime(2024, 1, 1, 10, 10))
            .withTotalPausedDuration(Duration(minutes: 3))
            .build()
            .copyWith(isPaused: false);

        final state = resolver.resolvePauseState(local, remote);

        expect(state.isPaused, false);
        expect(state.pausedAt, isNull);
        expect(state.totalPausedDuration.inMinutes, greaterThan(5));
      });

      test('handles both resumed correctly', () {
        final local = SessionBuilder()
            .withTotalPausedDuration(Duration(minutes: 5))
            .build()
            .copyWith(isPaused: false);

        final remote = SessionBuilder()
            .withTotalPausedDuration(Duration(minutes: 3))
            .build()
            .copyWith(isPaused: false);

        final state = resolver.resolvePauseState(local, remote);

        expect(state.isPaused, false);
        expect(state.totalPausedDuration.inMinutes, 8);
      });
    });

    group('Conflict Resolution', () {
      test('local newer keeps local', () {
        final local = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 10))
            .withNotes('Local notes')
            .build();

        final remote = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 0))
            .withNotes('Remote notes')
            .build();

        final resolved = resolver.resolveConflict(local, remote);

        expect(resolved.notes, 'Local notes');
      });

      test('merges all fields correctly', () {
        final local = SessionBuilder()
            .withId('session1')
            .withTemplateId('template1')
            .withStartedAt(DateTime(2024, 1, 1, 10, 0))
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 0))
            .withNotes('Local notes')
            .withFeeling('Good')
            .withBlocks([
              createTestBlock(
                id: 'block1',
                sessionId: 'session1',
                logs: [
                  createTestLog(
                    id: 'log1',
                    sessionBlockId: 'block1',
                    exerciseId: 'ex1',
                    setIndex: 0,
                    reps: 10,
                  ),
                ],
              ),
            ])
            .build();

        final remote = SessionBuilder()
            .withId('session1')
            .withTemplateId('template1')
            .withStartedAt(DateTime(2024, 1, 1, 10, 0))
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 5))
            .withNotes('Remote notes')
            .withFeeling('Great')
            .withBlocks([
              createTestBlock(
                id: 'block1',
                sessionId: 'session1',
                logs: [
                  createTestLog(
                    id: 'log2',
                    sessionBlockId: 'block1',
                    exerciseId: 'ex1',
                    setIndex: 0,
                    reps: 12,
                  ),
                ],
              ),
            ])
            .build();

        final resolved = resolver.resolveConflict(local, remote);

        expect(resolved.id, 'session1');
        expect(resolved.templateId, 'template1');
        expect(resolved.startedAt, DateTime(2024, 1, 1, 10, 0));
        expect(resolved.notes, 'Remote notes');
        expect(resolved.feeling, 'Great');
        expect(resolved.blocks.first.logs.length, 2);
      });

      test('preserves immutable fields', () {
        final local = SessionBuilder()
            .withId('session1')
            .withTemplateId('template1')
            .withStartedAt(DateTime(2024, 1, 1, 10, 0))
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 0))
            .build();

        final remote = SessionBuilder()
            .withId('session2')
            .withTemplateId('template2')
            .withStartedAt(DateTime(2024, 1, 1, 11, 0))
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 5))
            .build();

        final resolved = resolver.resolveConflict(local, remote);

        expect(resolved.id, 'session1');
        expect(resolved.templateId, 'template1');
        expect(resolved.startedAt, DateTime(2024, 1, 1, 10, 0));
      });

      test('remote completion auto-completes', () {
        final local = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 0))
            .build();

        final remote = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 5))
            .completed()
            .build();

        final resolved = resolver.resolveConflict(local, remote);

        expect(resolved.completedAt, isNotNull);
        expect(resolved.duration, isNotNull);
      });

      test('handles null fields', () {
        final local = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 0))
            .build();

        final remote = SessionBuilder()
            .withUpdatedAt(DateTime(2024, 1, 1, 10, 5))
            .withNotes(null)
            .withFeeling(null)
            .build();

        final resolved = resolver.resolveConflict(local, remote);

        expect(resolved.notes, isNull);
        expect(resolved.feeling, isNull);
      });
    });

    group('Block Merging', () {
      test('merges blocks with same ID', () {
        final localBlocks = [
          createTestBlock(
            id: 'block1',
            sessionId: 'session1',
            logs: [
              createTestLog(
                id: 'log1',
                sessionBlockId: 'block1',
                exerciseId: 'ex1',
                setIndex: 0,
                reps: 10,
              ),
            ],
          ),
        ];

        final remoteBlocks = [
          createTestBlock(
            id: 'block1',
            sessionId: 'session1',
            logs: [
              createTestLog(
                id: 'log2',
                sessionBlockId: 'block1',
                exerciseId: 'ex1',
                setIndex: 0,
                reps: 12,
              ),
            ],
          ),
        ];

        final merged = resolver.mergeBlocks(localBlocks, remoteBlocks);

        expect(merged.length, 1);
        expect(merged.first.logs.length, 2);
      });

      test('adds new blocks from remote', () {
        final localBlocks = [
          createTestBlock(id: 'block1', sessionId: 'session1'),
        ];

        final remoteBlocks = [
          createTestBlock(id: 'block1', sessionId: 'session1'),
          createTestBlock(id: 'block2', sessionId: 'session1'),
        ];

        final merged = resolver.mergeBlocks(localBlocks, remoteBlocks);

        expect(merged.length, 2);
      });
    });

    group('Breath Segments Merging', () {
      test('merges breath segments', () {
        final local = [
          createTestBreathSegment(id: 'seg1', sessionId: 'session1'),
        ];

        final remote = [
          createTestBreathSegment(id: 'seg2', sessionId: 'session1'),
        ];

        final merged = resolver.mergeBreathSegments(local, remote);

        expect(merged.length, 2);
      });

      test('deduplicates breath segments by ID', () {
        final local = [
          createTestBreathSegment(
            id: 'seg1',
            sessionId: 'session1',
            pattern: '4-4-4-4',
          ),
        ];

        final remote = [
          createTestBreathSegment(
            id: 'seg1',
            sessionId: 'session1',
            pattern: '5-5-5-5',
          ),
        ];

        final merged = resolver.mergeBreathSegments(local, remote);

        expect(merged.length, 1);
        expect(merged.first.pattern, '5-5-5-5');
      });
    });
  });
}

