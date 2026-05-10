import 'package:flutter/cupertino.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalCategoryStyle {
  const GoalCategoryStyle(this.category);

  final GoalCategory category;

  String get label {
    return category.name
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .toLowerCase();
  }

  Color get color {
    return switch (category) {
      GoalCategory.strength => AppColors.error,
      GoalCategory.power => const Color(0xFFFF7A45),
      GoalCategory.endurance => AppColors.warning,
      GoalCategory.mobility => const Color(0xFF64D2FF),
      GoalCategory.balance => const Color(0xFF8FD14F),
      GoalCategory.coordination => const Color(0xFFBF8CFF),
      GoalCategory.quickness => const Color(0xFFE87838),
      GoalCategory.physique => AppColors.accentPrimary,
      GoalCategory.posture => const Color(0xFF6E8BFF),
      GoalCategory.rehabilitation => AppColors.success,
      GoalCategory.longevity => const Color(0xFF42D6A4),
      GoalCategory.skill => AppColors.textColor2,
    };
  }
}
