import 'dart:convert';

import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/local_database.dart';

Session sessionFromRow(SessionRow row) {
  final blocks = (jsonDecode(row.blocksJson) as List)
      .map((b) => SessionBlock.fromJson(Map<String, dynamic>.from(b as Map)))
      .toList();
  final breathSegments = (jsonDecode(row.breathSegmentsJson) as List)
      .map((b) => BreathSegment.fromJson(Map<String, dynamic>.from(b as Map)))
      .toList();
  return Session(
    id: row.id,
    templateId: row.templateId,
    startedAt: row.startedAt,
    completedAt: row.completedAt,
    duration: row.durationSeconds != null
        ? Duration(seconds: row.durationSeconds!)
        : null,
    notes: row.notes,
    feeling: row.feeling,
    blocks: blocks,
    breathSegments: breathSegments,
    isPaused: row.isPaused,
    pausedAt: row.pausedAt,
    totalPausedDuration: Duration(seconds: row.totalPausedDurationSeconds),
    updatedAt: row.updatedAt,
  );
}

WorkoutTemplate templateFromRow(WorkoutTemplateRow row) {
  final blocks = (jsonDecode(row.blocksJson) as List)
      .map((b) => WorkoutBlock.fromJson(Map<String, dynamic>.from(b as Map)))
      .toList();
  return WorkoutTemplate(
    id: row.id,
    name: row.name,
    goal: row.goal,
    blocks: blocks,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    notes: row.notes,
  );
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

String formatDurationTimer(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes.remainder(60);
  final seconds = safeDuration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

