import 'package:flutter/material.dart';
import 'package:workouts/models/fitness_goal.dart';

class const GoalCategoryStyle(final GoalCategory category) {
  String get label => category.name
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .toLowerCase();

  Color get color => switch (category) {
    GoalCategory.strength => const Color(0xFFFF453A),
    GoalCategory.power => const Color(0xFFFF9F0A),
    GoalCategory.endurance => const Color(0xFFFFD60A),
    GoalCategory.mobility => const Color(0xFF64D2FF),
    GoalCategory.balance => const Color(0xFF40CBE0),
    GoalCategory.coordination => const Color(0xFFBF5AF2),
    GoalCategory.quickness => const Color(0xFFAC8E68),
    GoalCategory.physique => const Color(0xFF0A84FF),
    GoalCategory.posture => const Color(0xFF5E5CE6),
    GoalCategory.rehabilitation => const Color(0xFF30D158),
    GoalCategory.longevity => const Color(0xFF63E6E2),
    GoalCategory.skill => const Color(0xFF8E8E93),
  };
}
