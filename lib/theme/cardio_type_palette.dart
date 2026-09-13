import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_type.dart';

extension CardioTypeColor on CardioType {
  Color get color => switch (this) {
    CardioType.outdoorRun => EColors.accent,
    CardioType.indoorRun => EColors.warning,
    CardioType.outdoorWalk => const Color(0xFF5E5CE6),
    CardioType.indoorWalk => const Color(0xFFBF5AF2),
    CardioType.elliptical => const Color(0xFFFF9F0A),
    CardioType.stairClimbing => EColors.success,
    CardioType.rowing => const Color(0xFF64D2FF),
  };
}
