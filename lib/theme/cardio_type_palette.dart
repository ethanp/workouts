import 'package:flutter/cupertino.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/theme/app_theme.dart';

class CardioTypePalette {
  const CardioTypePalette._();

  static Color colorFor(CardioType cardioType) => switch (cardioType) {
    CardioType.outdoorRun => AppColors.accentPrimary,
    CardioType.indoorRun => AppColors.accentSecondary,
    CardioType.indoorWalk => const Color(0xFFBF5AF2),
    CardioType.elliptical => const Color(0xFFFF9F0A),
    CardioType.stairClimbing => AppColors.success,
    CardioType.rowing => const Color(0xFF64D2FF),
  };
}
