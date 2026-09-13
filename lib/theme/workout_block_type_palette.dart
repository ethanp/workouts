import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/workout_block.dart';

extension WorkoutBlockTypeColor on WorkoutBlockType {
  Color get color => switch (this) {
    WorkoutBlockType.warmup => EColors.warning,
    WorkoutBlockType.animalFlow => EColors.warning,
    WorkoutBlockType.strength => EColors.danger,
    WorkoutBlockType.mobility => EColors.success,
    WorkoutBlockType.core => EColors.accent,
    WorkoutBlockType.conditioning => EColors.warning,
    WorkoutBlockType.cooldown => EColors.textTertiary,
  };
}
