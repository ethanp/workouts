import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:http/http.dart' as http;

const _log = ELogger('ServerCardioWorkouts');

/// The cardio workouts Postgres actually holds, read from PostgREST rather
/// than the local PowerSync copy.
class ServerCardioWorkouts(final String _postgrestUrl) {
  /// Null when the server can't be read, so an outage is never mistaken for
  /// a server with no workouts.
  Future<Set<String>?> idsIfReachable() async {
    if (_postgrestUrl.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$_postgrestUrl/cardio_workouts?select=id&limit=100000'),
      );
      if (response.statusCode >= 400) {
        _log.warn(
          'Could not list server workouts: '
          '${response.statusCode} ${response.body}',
        );
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;
      return {
        for (final workoutRow in decoded)
          if (workoutRow is Map && workoutRow['id'] is String)
            workoutRow['id'] as String,
      };
    } catch (error) {
      _log.warn('Could not list server workouts: $error');
      return null;
    }
  }
}
