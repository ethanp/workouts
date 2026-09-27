import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:http/http.dart' as http;
import 'package:workouts/models/cardio_route_point.dart';

const _log = ELogger('StoredWorkoutRoute');
const _pageSize = 500;

/// One workout's GPS points in Postgres, read on demand.
///
/// Not a PowerSync bucket. A full-history sync of these rows is what used to
/// rebuild the bucket and get the app killed.
class StoredWorkoutRoute(final String _postgrestUrl) {
  Future<bool> replace(
    String workoutId,
    List<CardioRoutePoint> routePoints,
  ) async {
    if (_postgrestUrl.isEmpty || routePoints.length < 2) return false;
    try {
      for (var start = 0; start < routePoints.length; start += _pageSize) {
        final end = start + _pageSize > routePoints.length
            ? routePoints.length
            : start + _pageSize;
        final response = await http.post(
          Uri.parse(
            '$_postgrestUrl/cardio_route_points?on_conflict=workout_id,point_index',
          ),
          headers: const {
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode([
            for (final routePoint in routePoints.sublist(start, end))
              _row(routePoint),
          ]),
        );
        if (response.statusCode >= 400) {
          _log.warn(
            'Could not store route for $workoutId: '
            '${response.statusCode} ${response.body}',
          );
          return false;
        }
      }
      final leftover = await http.delete(
        Uri.parse(
          '$_postgrestUrl/cardio_route_points'
          '?workout_id=eq.${Uri.encodeComponent(workoutId)}'
          '&point_index=gte.${routePoints.length}',
        ),
      );
      if (leftover.statusCode >= 400) {
        _log.warn(
          'Could not trim stored route for $workoutId: '
          '${leftover.statusCode} ${leftover.body}',
        );
        return false;
      }
      return true;
    } catch (error) {
      _log.warn('Could not store route for $workoutId: $error');
      return false;
    }
  }

  Future<Set<String>> idsWithAFirstPoint() async {
    if (_postgrestUrl.isEmpty) return const {};
    try {
      final response = await http.get(
        Uri.parse(
          '$_postgrestUrl/cardio_route_points'
          '?select=workout_id&point_index=eq.0&limit=5000',
        ),
      );
      if (response.statusCode >= 400) {
        _log.warn(
          'Could not list stored routes: '
          '${response.statusCode} ${response.body}',
        );
        return const {};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const {};
      return {
        for (final row in decoded)
          if (row is Map && row['workout_id'] is String)
            row['workout_id'] as String,
      };
    } catch (error) {
      _log.warn('Could not list stored routes: $error');
      return const {};
    }
  }

  Future<List<CardioRoutePoint>> pointsFor(String workoutId) async {
    if (_postgrestUrl.isEmpty) return const [];
    try {
      final response = await http.get(
        Uri.parse(
          '$_postgrestUrl/cardio_route_points'
          '?workout_id=eq.${Uri.encodeComponent(workoutId)}'
          '&select=id,workout_id,point_index,lat,lng,altitude_meters,timestamp'
          '&order=point_index.asc'
          '&limit=2000',
        ),
      );
      if (response.statusCode >= 400) {
        _log.warn(
          'Could not load route for $workoutId: '
          '${response.statusCode} ${response.body}',
        );
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return [
        for (final row in decoded)
          if (row is Map)
            CardioRoutePoint.fromRow(Map<String, dynamic>.from(row)),
      ];
    } catch (error) {
      _log.warn('Could not load route for $workoutId: $error');
      return const [];
    }
  }

  Map<String, Object?> _row(CardioRoutePoint routePoint) => {
    'id': routePoint.id,
    'workout_id': routePoint.workoutId,
    'point_index': routePoint.pointIndex,
    'lat': routePoint.latitude,
    'lng': routePoint.longitude,
    'altitude_meters': routePoint.altitudeMeters,
    'timestamp': routePoint.recordedAt?.toUtc().toIso8601String(),
  };
}
