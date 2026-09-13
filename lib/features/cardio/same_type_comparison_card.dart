import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_session_verdict.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

import 'cardio_detail_card.dart';

class const SameTypeComparisonCard({
  required final SameTypeWorkoutComparison comparison,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CardioDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent ${comparison.thisWorkout.activityType.displayName}',
            style: EText.section,
          ),
          const SizedBox(height: ELayout.spaceSm),
          for (final peer in comparison.peers) _peerRow(peer),
        ],
      ),
    );
  }

  Widget _peerRow(CardioWorkout peer) {
    final isThisWorkout = peer.id == comparison.thisWorkout.id;
    final primaryWork = CardioSessionVerdict.fromWorkout(peer).primaryWork;
    final workCaption = primaryWork.headline.isEmpty
        ? '—'
        : primaryWork.headline;
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
      child: Text(
        '${peer.startedAt.dayKey}  ·  '
        '${peer.duration.formattedHm}  ·  '
        '${_avgHr(peer)}  ·  '
        '$workCaption  ·  '
        '${peer.zoneTime.gteZone2Minutes}m Z2–5'
        '${_metsSuffix(peer)}',
        style: EText.caption.copyWith(
          color: isThisWorkout ? EColors.textPrimary : EColors.textTertiary,
          fontWeight: isThisWorkout ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  String _avgHr(CardioWorkout peer) {
    final averageHeartRateBpm = peer.averageHeartRateBpm;
    if (averageHeartRateBpm == null) return '— bpm';
    return '${averageHeartRateBpm.round()} bpm';
  }

  String _metsSuffix(CardioWorkout peer) {
    final metsCaption = peer.metsCaption;
    if (metsCaption == null) return '';
    return '  ·  $metsCaption';
  }
}
