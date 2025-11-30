import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/repositories/session_repository.dart';
import 'package:workouts/services/repositories/template_repository.dart';
import 'package:workouts/services/sync/sync_service.dart';

import '../../support/fake_pocketbase_client.dart';
import '../sync/session_test_helpers.dart';

/// Integration tests for real-time synchronization across multiple "devices"
/// 
/// These tests verify that changes made on one device are properly synced
/// to other devices in real-time. Each "device" is represented by a separate
/// SyncService instance with its own database.
/// 
/// These tests use TDD approach: write tests for real scenarios, then fix
/// the implementation to make them pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Real-time Sync Across Devices', () {
    late FakePocketBaseClient fakePb;
    late LocalDatabase device1Db;
    late LocalDatabase device2Db;
    late SyncService device1Sync;
    late SyncService device2Sync;
    late SessionRepository device1Repo;
    late TemplateRepository device1TemplateRepo;

    setUp(() {
      fakePb = FakePocketBaseClient('http://localhost:8090');
      // Use in-memory databases for tests
      device1Db = LocalDatabase(executor: NativeDatabase.memory());
      device2Db = LocalDatabase(executor: NativeDatabase.memory());
      
      // Create sync services with the fake PocketBase client
      // Force online mode for tests (skip connectivity checks)
      device1Sync = SyncService(device1Db, pocketBase: fakePb, forceOnline: true);
      device2Sync = SyncService(device2Db, pocketBase: fakePb, forceOnline: true);
      
      // Create repositories
      device1TemplateRepo = TemplateRepository(device1Db, device1Sync);
      device1Repo = SessionRepository(device1Db, device1TemplateRepo, device1Sync);
    });

    tearDown(() async {
      await device1Db.close();
      await device2Db.close();
      fakePb.clear();
    });

    test('device 1 creates session, device 2 receives it in real-time', () async {
      // Setup: Both devices subscribe to real-time updates
      await device1Sync.subscribe();
      await device2Sync.subscribe();
      await Future.delayed(const Duration(milliseconds: 100));

      // Create a template first (required for sessions)
      final template = WorkoutTemplate(
        id: 'template1',
        name: 'Test Template',
        goal: 'Test Goal',
        blocks: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await device1Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      
      // Add template to fake PB so it can be referenced
      fakePb.addRecord('templates', {
        'id': 'template1',
        'name': 'Test Template',
        'goal': 'Test Goal',
        'blocks_json': '[]',
        'created_at': (template.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (template.updatedAt ?? DateTime.now()).toIso8601String(),
      });
      
      // Device2 also needs the template (subscription handler checks for it)
      await device2Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );

      // Device 1 creates a session locally
      final session = SessionBuilder()
          .withId('session1')
          .withTemplateId(template.id)
          .withStartedAt(DateTime.now())
          .build();
      
      // Save session to device1's database
      await device1Db.upsertSession(
        SessionsTableCompanion.insert(
          id: session.id,
          templateId: session.templateId,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );

      // Device 1 pushes the session (simulates what happens when syncing)
      final sessionRow = await device1Db.readSessionById(session.id);
      expect(sessionRow, isNotNull);
      await device1Sync.pushSession(sessionRow!);

      // Wait for the push to complete and event to propagate
      await fakePb.waitForCallbacks();

      // Read the session again to get the updated remoteId
      final updatedSessionRow = await device1Db.readSessionById(session.id);
      expect(updatedSessionRow?.remoteId, isNotNull, reason: 'Session should have remoteId after push');

      // Verify device2 received the session via subscription
      // The subscription handler should have created it in device2Db
      // Check by looking for sessions with the remoteId that was assigned
      final allDevice2Sessions = await device2Db.readSessions();
      final device2ReceivedSession = allDevice2Sessions.firstWhere(
        (s) => s.remoteId == updatedSessionRow!.remoteId,
        orElse: () => throw Exception('Session not found on device 2'),
      );
      
      expect(device2ReceivedSession, isA<SessionRow>(), reason: 'Device 2 should have received the session');
      expect(device2ReceivedSession.templateId, equals(template.id));
      // Compare at second precision (ISO8601 serialization loses microseconds)
      expect(
        device2ReceivedSession.startedAt.millisecondsSinceEpoch ~/ 1000,
        equals(session.startedAt.millisecondsSinceEpoch ~/ 1000),
      );
    });

    test('device 1 updates session notes, device 2 receives update', () async {
      // Track if device2's sync service processes the event
      var device2EventCount = 0;
      device2Sync = SyncService(
        device2Db, 
        pocketBase: fakePb, 
        forceOnline: true,
        onDataChanged: (type) => device2EventCount++,
      );
      
      // Setup subscriptions
      await device1Sync.subscribe();
      await device2Sync.subscribe();
      await Future.delayed(const Duration(milliseconds: 100));

      // Create template
      final template = WorkoutTemplate(
        id: 'template1',
        name: 'Test Template',
        goal: 'Test Goal',
        blocks: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await device1Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      await device2Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      fakePb.addRecord('templates', {
        'id': 'template1',
        'name': 'Test Template',
        'goal': 'Test Goal',
        'blocks_json': '[]',
        'created_at': (template.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (template.updatedAt ?? DateTime.now()).toIso8601String(),
      });

      // Create initial session on both devices (simulating they both had it)
      final session = SessionBuilder()
          .withId('session1')
          .withTemplateId(template.id)
          .withStartedAt(DateTime.now())
          .build();
      
      // Save to device1 with remoteId
      await device1Db.upsertSession(
        SessionsTableCompanion.insert(
          id: session.id,
          remoteId: const Value('remote_session1'),
          templateId: session.templateId,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );
      
      // Save to device2 with same remoteId
      await device2Db.upsertSession(
        SessionsTableCompanion.insert(
          id: 'device2_session1',
          remoteId: const Value('remote_session1'),
          templateId: template.id,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );

      // Add to fake PB
      fakePb.addRecord('sessions', {
        'id': 'remote_session1',
        'template_id': 'template1',
        'started_at': session.startedAt.toIso8601String(),
        'blocks_json': '[]',
        'breath_segments_json': '[]',
        'is_paused': false,
        'updated_at': (session.updatedAt ?? DateTime.now()).toIso8601String(),
      });

      // Wait to ensure timestamps differ by at least 1 second
      // (SQLite/Drift stores DateTime with second precision, sub-second is lost)
      await Future.delayed(const Duration(seconds: 1));

      // Device 1 updates the session with notes
      await device1Db.upsertSession(
        SessionsTableCompanion.insert(
          id: session.id,
          remoteId: const Value('remote_session1'),
          templateId: session.templateId,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          notes: const Value('Updated notes from device 1'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      
      // Verify notes were saved locally
      final updatedRow = await device1Db.readSessionById(session.id);
      expect(updatedRow?.notes, equals('Updated notes from device 1'), 
          reason: 'Session should have notes after update');

      // Manually push
      await device1Sync.pushSession(updatedRow!);
      
      // Wait for async handlers to complete (they run in separate microtasks)
      await fakePb.waitForCallbacks();
      await Future.delayed(const Duration(milliseconds: 500));

      // Debug: Check if device1's session was pushed correctly
      final device1Row = await device1Db.readSessionById(session.id);
      expect(device1Row?.remoteId, equals('remote_session1'), 
          reason: 'Device 1 session should have correct remoteId');
      expect(device1Row?.notes, equals('Updated notes from device 1'),
          reason: 'Device 1 should have notes in database');
      
      // Check what's in FakePB
      final pbRecords = fakePb.getRecords('sessions');
      expect(pbRecords.length, greaterThan(0), reason: 'FakePB should have session records');
      final pbSession = pbRecords.firstWhere((r) => r.id == 'remote_session1');
      expect(pbSession.data['notes'], equals('Updated notes from device 1'),
          reason: 'FakePB should have notes in session record');
      
      // Verify device2's sync service processed the event
      expect(device2EventCount, greaterThan(0), 
          reason: 'Device 2 sync service should have processed the update event');
      
      // Verify device2 received the update
      final allDevice2Sessions = await device2Db.readSessions();
      final device2Session = allDevice2Sessions.firstWhere(
        (s) => s.remoteId == 'remote_session1',
        orElse: () => throw Exception('Session not found on device 2'),
      );
      
      expect(device2Session.notes, equals('Updated notes from device 1'),
          reason: 'Device 2 should have received the updated notes');
    });

    test('device 1 deletes session, device 2 receives delete event', () async {
      // Setup subscriptions
      await device1Sync.subscribe();
      await device2Sync.subscribe();
      await Future.delayed(const Duration(milliseconds: 100));

      // Create template
      final template = WorkoutTemplate(
        id: 'template1',
        name: 'Test Template',
        goal: 'Test Goal',
        blocks: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await device1Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      await device2Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      fakePb.addRecord('templates', {
        'id': 'template1',
        'name': 'Test Template',
        'goal': 'Test Goal',
        'blocks_json': '[]',
        'created_at': (template.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (template.updatedAt ?? DateTime.now()).toIso8601String(),
      });

      // Create session on both devices
      final session = SessionBuilder()
          .withId('session1')
          .withTemplateId(template.id)
          .withStartedAt(DateTime.now())
          .build();
      
      await device1Db.upsertSession(
        SessionsTableCompanion.insert(
          id: session.id,
          remoteId: const Value('remote_session1'),
          templateId: session.templateId,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );
      
      await device2Db.upsertSession(
        SessionsTableCompanion.insert(
          id: 'device2_session1',
          remoteId: const Value('remote_session1'),
          templateId: template.id,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );

      fakePb.addRecord('sessions', {
        'id': 'remote_session1',
        'template_id': 'template1',
        'started_at': session.startedAt.toIso8601String(),
        'blocks_json': '[]',
        'breath_segments_json': '[]',
        'is_paused': false,
        'updated_at': (session.updatedAt ?? DateTime.now()).toIso8601String(),
      });

      // Device 1 deletes the session
      await device1Repo.discardSession(session.id);
      
      // Process the delete from sync queue
      await device1Sync.processQueue();

      // Wait for sync
      await fakePb.waitForCallbacks();

      // Verify device2 received the delete event
      final allDevice2Sessions = await device2Db.readSessions();
      final device2Session = allDevice2Sessions.where((s) => s.remoteId == 'remote_session1').firstOrNull;
      expect(device2Session, isNull, reason: 'Device 2 should have deleted the session');
    });

    test('device 2 deletes session, device 1 receives delete immediately (real-time)', () async {
      // Scenario:
      // 1. Session exists on both devices and in PocketBase
      // 2. Device 2 deletes the session (swipe to delete in history)
      // 3. Device 1 should receive the delete in real-time (no manual sync needed)
      
      // Setup subscriptions
      await device1Sync.subscribe();
      await device2Sync.subscribe();
      await Future.delayed(const Duration(milliseconds: 100));

      // Create template on both devices
      final template = WorkoutTemplate(
        id: 'template1',
        name: 'Test Template',
        goal: 'Test Goal',
        blocks: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await device1Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      await device2Db.upsertTemplate(
        WorkoutTemplatesTableCompanion.insert(
          id: template.id,
          remoteId: const Value('template1'),
          name: template.name,
          goal: template.goal,
          blocksJson: '[]',
          createdAt: template.createdAt ?? DateTime.now(),
          updatedAt: Value(template.updatedAt ?? DateTime.now()),
        ),
      );
      fakePb.addRecord('templates', {
        'id': 'template1',
        'name': 'Test Template',
        'goal': 'Test Goal',
        'blocks_json': '[]',
      });

      // Session exists on both devices and in PocketBase
      final session = SessionBuilder()
          .withId('session1')
          .withTemplateId(template.id)
          .withStartedAt(DateTime.now())
          .build();
      
      await device1Db.upsertSession(
        SessionsTableCompanion.insert(
          id: 'device1_session1',
          remoteId: const Value('remote_session1'),
          templateId: session.templateId,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );
      
      await device2Db.upsertSession(
        SessionsTableCompanion.insert(
          id: 'device2_session1',
          remoteId: const Value('remote_session1'),
          templateId: template.id,
          startedAt: session.startedAt,
          blocksJson: '[]',
          breathSegmentsJson: '[]',
          isPaused: const Value(false),
          updatedAt: Value(session.updatedAt ?? DateTime.now()),
        ),
      );

      fakePb.addRecord('sessions', {
        'id': 'remote_session1',
        'template_id': 'template1',
        'started_at': session.startedAt.toIso8601String(),
        'blocks_json': '[]',
        'breath_segments_json': '[]',
        'is_paused': false,
      });

      // Create device2's repository for the delete operation
      final device2TemplateRepo = TemplateRepository(device2Db, device2Sync);
      final device2Repo = SessionRepository(device2Db, device2TemplateRepo, device2Sync);

      // Device 2 deletes the session (like swiping to delete in history)
      await device2Repo.discardSession('device2_session1');
      
      // Wait for real-time sync (delete is pushed immediately, no manual sync needed)
      await fakePb.waitForCallbacks();
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify device1 received the delete event in real-time
      final device1Sessions = await device1Db.readSessions();
      final device1Session = device1Sessions.where((s) => s.remoteId == 'remote_session1').firstOrNull;
      expect(device1Session, isNull, 
          reason: 'Device 1 should have received the delete in real-time (without manual sync)');
    });
  });
}
