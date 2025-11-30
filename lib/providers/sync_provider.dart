import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/sync/sync_service.dart';

part 'sync_provider.g.dart';

enum SyncState { idle, syncing, error, listening }

final _syncEventsController = StreamController<String>.broadcast();

@riverpod
Stream<String> syncEvents(Ref ref) {
  return _syncEventsController.stream;
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final db = ref.watch(localDatabaseProvider);
  return SyncService(
    db,
    onDataChanged: (type) {
      _syncEventsController.add(type);
    },
  );
}

@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  SyncState build() {
    _setupConnectivityMonitoring();
    return SyncState.idle;
  }

  void setupConnectivityMonitoring({bool skipInTests = false}) {
    if (skipInTests) return;
    final syncService = ref.read(syncServiceProvider);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = syncService.connectivityStream.listen(
      (results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline && (state == SyncState.idle || state == SyncState.error)) {
          startListening();
        }
      },
    );
    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });
  }

  void _setupConnectivityMonitoring() {
    setupConnectivityMonitoring();
  }

  Future<void> sync() async {
    final syncService = ref.read(syncServiceProvider);
    final wasListening = syncService.isSubscribed;
    
    state = SyncState.syncing;
    try {
      await syncService.syncAll();
      state = wasListening ? SyncState.listening : SyncState.idle;
    } catch (_) {
      state = SyncState.error;
    }
  }

  Future<void> startListening() async {
    final syncService = ref.read(syncServiceProvider);
    
    if (syncService.isSubscribed) {
      state = SyncState.listening;
      return;
    }

    if (!await syncService.isOnline()) {
      state = SyncState.idle;
      return;
    }

    state = SyncState.syncing;
    try {
      await syncService.syncAll();
      await syncService.subscribe();
      state = SyncState.listening;
    } catch (_) {
      state = SyncState.error;
    }
  }

  Future<void> stopListening() async {
    await ref.read(syncServiceProvider).unsubscribe();
    if (state == SyncState.listening) {
      state = SyncState.idle;
    }
  }

  Future<bool> isOnline() => ref.read(syncServiceProvider).isOnline();
}
