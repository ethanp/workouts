import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// A fake PocketBase server for testing real-time synchronization.
/// 
/// Supports:
/// - CRUD operations on collections
/// - Real-time subscriptions via Server-Sent Events (SSE)
/// - Multiple clients connecting simultaneously
/// - Simulating network delays and failures
class FakePocketBaseServer {
  FakePocketBaseServer({this.port = 8090});

  final int port;
  HttpServer? _server;
  final Map<String, Map<String, Map<String, dynamic>>> _collections = {};
  final Map<String, List<StreamController<String>>> _sseControllers = {};
  int _recordIdCounter = 1;

  /// Start the fake server
  Future<void> start() async {
    final router = Router();

    // Health check
    router.get('/api/health', (Request request) {
      return Response.ok(jsonEncode({'code': 200, 'message': 'OK'}));
    });

    // Get full list of records
    router.get('/api/collections/<collection>/records', (Request request, String collection) async {
      final records = _collections[collection]?.values.toList() ?? [];
      return Response.ok(
        jsonEncode({
          'page': 1,
          'perPage': 100,
          'totalItems': records.length,
          'totalPages': 1,
          'items': records,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // Get single record
    router.get('/api/collections/<collection>/records/<id>', (Request request, String collection, String id) {
      final record = _collections[collection]?[id];
      if (record == null) {
        return Response.notFound(jsonEncode({'code': 404, 'message': 'Not found'}));
      }
      return Response.ok(jsonEncode(record), headers: {'Content-Type': 'application/json'});
    });

    // Create record
    router.post('/api/collections/<collection>/records', (Request request, String collection) async {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final id = 'rec${_recordIdCounter++}';
      final now = DateTime.now().toIso8601String();
      
      final record = {
        'id': id,
        'collectionId': collection,
        'collectionName': collection,
        'created': now,
        'updated': now,
        ...data,
      };

      _collections.putIfAbsent(collection, () => {})[id] = record;
      _broadcastEvent(collection, 'create', record);
      
      return Response.ok(jsonEncode(record), headers: {'Content-Type': 'application/json'});
    });

    // Update record
    router.patch('/api/collections/<collection>/records/<id>', (Request request, String collection, String id) async {
      final existing = _collections[collection]?[id];
      if (existing == null) {
        return Response.notFound(jsonEncode({'code': 404, 'message': 'Not found'}));
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final updated = {
        ...existing,
        ...data,
        'updated': DateTime.now().toIso8601String(),
      };

      _collections[collection]![id] = updated;
      _broadcastEvent(collection, 'update', updated);
      
      return Response.ok(jsonEncode(updated), headers: {'Content-Type': 'application/json'});
    });

    // Delete record
    router.delete('/api/collections/<collection>/records/<id>', (Request request, String collection, String id) {
      final existing = _collections[collection]?[id];
      if (existing == null) {
        return Response.notFound(jsonEncode({'code': 404, 'message': 'Not found'}));
      }

      _collections[collection]!.remove(id);
      _broadcastEvent(collection, 'delete', existing);
      
      return Response(204);
    });

    // Real-time subscription endpoint (SSE)
    router.get('/api/realtime', (Request request) {
      final collection = request.url.queryParameters['collection'];
      if (collection == null) {
        return Response.badRequest(body: 'collection parameter required');
      }

      final controller = StreamController<String>.broadcast();
      _sseControllers.putIfAbsent(collection, () => []).add(controller);

      // Send initial connection message
      controller.add('data: ${jsonEncode({"type": "connect"})}\n\n');

      // Clean up on close
      request.hijack((HttpRequest hijacked) {
        hijacked.response.done.then((_) {
          _sseControllers[collection]?.remove(controller);
          controller.close();
        });
      });

      return Response.ok(
        controller.stream.map((data) => '$data\n\n'),
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      );
    });

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
  }

  /// Stop the fake server
  Future<void> stop() async {
    await _server?.close(force: true);
    for (final controllers in _sseControllers.values) {
      for (final controller in controllers) {
        await controller.close();
      }
    }
    _sseControllers.clear();
    _collections.clear();
  }

  /// Get the base URL of the server
  String get baseUrl => 'http://localhost:$port';

  /// Manually trigger an event (useful for testing)
  void triggerEvent(String collection, String action, Map<String, dynamic> record) {
    _broadcastEvent(collection, action, record);
  }

  /// Add a record directly (useful for test setup)
  void addRecord(String collection, Map<String, dynamic> record) {
    final id = record['id'] as String? ?? 'rec${_recordIdCounter++}';
    _collections.putIfAbsent(collection, () => {})[id] = {
      'id': id,
      'collectionId': collection,
      'collectionName': collection,
      'created': DateTime.now().toIso8601String(),
      'updated': DateTime.now().toIso8601String(),
      ...record,
    };
  }

  /// Get all records in a collection
  List<Map<String, dynamic>> getRecords(String collection) {
    return _collections[collection]?.values.toList() ?? [];
  }

  /// Clear all data
  void clear() {
    _collections.clear();
  }

  void _broadcastEvent(String collection, String action, Map<String, dynamic> record) {
    final controllers = _sseControllers[collection];
    if (controllers == null) return;

    final event = {
      'action': action,
      'record': record,
    };

    final message = 'data: ${jsonEncode(event)}\n\n';
    for (final controller in controllers) {
      controller.add(message);
    }
  }
}

