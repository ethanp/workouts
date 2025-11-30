import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

/// A fake PocketBase client that simulates real-time subscriptions for testing.
///
/// This allows testing real-time sync behavior without requiring a real PocketBase server.
/// Events can be manually triggered to simulate remote changes.
class FakePocketBaseClient extends PocketBase {
  FakePocketBaseClient(super.baseUrl) : _collections = {}, _subscriptions = {};

  final Map<String, Map<String, RecordModel>> _collections;
  final Map<String, List<_Subscription>> _subscriptions;
  final List<Future<void>> _pendingCallbacks = [];
  int _recordIdCounter = 1;

  @override
  RecordService collection(String collectionIdOrName) {
    return _FakeRecordService(this, collectionIdOrName);
  }

  /// Manually trigger a real-time event (for testing)
  void triggerEvent(
    String collection,
    String action,
    Map<String, dynamic> data,
  ) {
    final subscriptions = _subscriptions[collection];
    if (subscriptions == null) return;

    // Use data directly - app uses updated_at (not PocketBase's internal updated field)
    final recordData = <String, dynamic>{
      'id': data['id'] ?? 'rec${_recordIdCounter++}',
      'collectionId': collection,
      'collectionName': collection,
      ...data,
    };
    final record = RecordModel(recordData);

    for (final subscription in subscriptions) {
      if (_matchesFilter(subscription.topic, record)) {
        final event = RecordSubscriptionEvent(action: action, record: record);
        // The callback is typed as void but is actually async (Future<void>)
        // We invoke it and add a delay to let async work complete
        final future = Future(() async {
          subscription.callback(event);
          // Allow async handlers to run by yielding multiple times
          await Future.delayed(Duration.zero);
          await Future.delayed(Duration.zero);
        });
        _pendingCallbacks.add(future);
      }
    }
  }

  /// Wait for all pending callback futures to complete (for testing)
  Future<void> waitForCallbacks() async {
    if (_pendingCallbacks.isEmpty) return;
    await Future.wait(_pendingCallbacks);
    _pendingCallbacks.clear();
  }

  /// Add a record directly (for test setup)
  void addRecord(String collection, Map<String, dynamic> data) {
    final id = data['id'] as String? ?? 'rec${_recordIdCounter++}';
    _collections.putIfAbsent(collection, () => {})[id] = RecordModel({
      'id': id,
      'collectionId': collection,
      'collectionName': collection,
      ...data,
    });
  }

  /// Get all records in a collection
  List<RecordModel> getRecords(String collection) {
    return _collections[collection]?.values.toList() ?? [];
  }

  /// Clear all data
  void clear() {
    _collections.clear();
    _subscriptions.clear();
    _pendingCallbacks.clear();
  }

  void _addSubscription(
    String collection,
    String topic,
    RecordSubscriptionFunc callback,
  ) {
    _subscriptions
        .putIfAbsent(collection, () => [])
        .add(_Subscription(topic, callback));
  }

  void _removeSubscription(String collection, String topic) {
    if (topic.isEmpty) {
      _subscriptions.remove(collection);
    } else {
      _subscriptions[collection]?.removeWhere((s) => s.topic == topic);
    }
  }

  bool _matchesFilter(String topic, RecordModel record) {
    // '*' matches everything
    if (topic == '*') return true;
    // Specific record ID matches
    if (topic == record.id) return true;
    return false;
  }
}

class _Subscription {
  _Subscription(this.topic, this.callback);
  final String topic;
  final RecordSubscriptionFunc callback;
}

class _FakeRecordService extends RecordService {
  _FakeRecordService(this._fakeClient, this._collectionIdOrName)
    : super(_fakeClient, _collectionIdOrName);

  final FakePocketBaseClient _fakeClient;
  final String _collectionIdOrName;

  String get collectionIdOrName => _collectionIdOrName;

  @override
  Future<RecordModel> create({
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    final id = 'rec${_fakeClient._recordIdCounter++}';

    final record = RecordModel({
      'id': id,
      'collectionId': collectionIdOrName,
      'collectionName': collectionIdOrName,
      ...body,
    });

    _fakeClient._collections.putIfAbsent(collectionIdOrName, () => {})[id] =
        record;
    // Trigger event with all data from body (includes updated_at from app)
    final eventData = {'id': id, ...body};
    _fakeClient.triggerEvent(collectionIdOrName, 'create', eventData);

    return record;
  }

  @override
  Future<RecordModel> update(
    String id, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    List<http.MultipartFile> files = const [],
    Map<String, String> headers = const {},
    String? expand,
    String? fields,
  }) async {
    final existing = _fakeClient._collections[collectionIdOrName]?[id];
    if (existing == null) {
      throw ClientException(
        url: Uri.parse(''),
        statusCode: 404,
        response: {'code': 404, 'message': 'Record not found', 'data': {}},
      );
    }

    // Merge data fields - body fields (including updated_at) override existing
    final mergedData = <String, dynamic>{...existing.data, ...body};
    mergedData['id'] = id;
    mergedData['collectionId'] = collectionIdOrName;
    mergedData['collectionName'] = collectionIdOrName;

    final updated = RecordModel(mergedData);

    _fakeClient._collections[collectionIdOrName]![id] = updated;
    // Trigger event with merged data (body includes updated_at from app)
    _fakeClient.triggerEvent(collectionIdOrName, 'update', mergedData);

    return updated;
  }

  @override
  Future<void> delete(
    String id, {
    Map<String, dynamic> body = const {},
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final existing = _fakeClient._collections[collectionIdOrName]?[id];
    if (existing == null) {
      throw ClientException(
        url: Uri.parse(''),
        statusCode: 404,
        response: {'code': 404, 'message': 'Record not found', 'data': {}},
      );
    }

    _fakeClient._collections[collectionIdOrName]!.remove(id);
    // Trigger event with the record's data map
    final eventData = {'id': id, ...existing.data};
    _fakeClient.triggerEvent(collectionIdOrName, 'delete', eventData);
  }

  @override
  Future<List<RecordModel>> getFullList({
    int batch = 500,
    String? expand,
    String? filter,
    String? sort,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    return _fakeClient.getRecords(collectionIdOrName);
  }

  @override
  Future<UnsubscribeFunc> subscribe(
    String topic,
    RecordSubscriptionFunc callback, {
    String? expand,
    String? filter,
    String? fields,
    Map<String, dynamic> query = const {},
    Map<String, String> headers = const {},
  }) async {
    _fakeClient._addSubscription(collectionIdOrName, topic, callback);
    return () async {
      _fakeClient._removeSubscription(collectionIdOrName, topic);
    };
  }

  @override
  Future<void> unsubscribe([String topic = '']) async {
    _fakeClient._removeSubscription(collectionIdOrName, topic);
  }
}
