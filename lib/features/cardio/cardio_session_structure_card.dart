import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/cardio_session_structure.dart';
import 'package:workouts/models/cardio_workout_event.dart';

import 'cardio_detail_card.dart';

class const CardioSessionStructureCard({
  required final AsyncValue<List<CardioWorkoutEvent>> workoutEventsAsync,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return workoutEventsAsync.when(
      data: (workoutEvents) {
        final structure = CardioSessionStructure.fromEvents(workoutEvents);
        if (structure.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: ELayout.spaceMd),
          child: CardioDetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session', style: EText.section),
                const SizedBox(height: ELayout.spaceSm),
                for (final caption in structure.captions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
                    child: Text(
                      caption,
                      style: EText.caption.copyWith(
                        color: EColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
