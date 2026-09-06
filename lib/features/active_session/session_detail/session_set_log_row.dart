import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/utils/weight_display.dart';

class const SessionSetLogRow({
  required final SessionSetLog log,
  required final WorkoutExercise exercise,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: EColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Text(
              'Set ${log.setIndex + 1}: ${_details().join(' · ')}',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _details() {
    final plannedSet = _plannedSet;
    final details = <String>[];

    if (plannedSet != null) details.add(plannedSet.type.name);
    if (log.weight != null) {
      details.add(log.weight!.formatFor(exercise));
    }
    if (log.reps != null) details.add('${log.reps} reps');
    if (log.duration != null) details.add(_durationLabel(log.duration!));
    if (log.unitRemaining != null) {
      details.add('${log.unitRemaining} left in tank');
    }
    if (plannedSet != null && !_matchesPlan(plannedSet)) {
      details.add('planned ${_plannedSetLabel(plannedSet)}');
    }

    return details;
  }

  PlannedSet? get _plannedSet {
    if (log.setIndex >= exercise.plannedSets.length) return null;
    return exercise.plannedSets[log.setIndex];
  }

  bool _matchesPlan(PlannedSet plannedSet) {
    return log.reps == plannedSet.reps &&
        log.weight == plannedSet.weight &&
        log.duration == plannedSet.duration;
  }

  String _plannedSetLabel(PlannedSet plannedSet) {
    final labelParts = <String>[];
    if (plannedSet.reps != null) labelParts.add('${plannedSet.reps} reps');
    if (plannedSet.weight != null) {
      labelParts.add(plannedSet.weight!.formatFor(exercise));
    }
    if (plannedSet.duration != null) {
      labelParts.add(_durationLabel(plannedSet.duration!));
    }
    return labelParts.isEmpty ? 'set' : labelParts.join(' @ ');
  }

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
