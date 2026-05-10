import 'package:flutter/cupertino.dart';
import 'package:workouts/models/fitness_goal.dart';

class GoalCategoryStyle {
  const GoalCategoryStyle(this.category);

  final GoalCategory category;

  String get label => category.name
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .toLowerCase();

  Color get color => switch (category) {
    GoalCategory.strength => CupertinoColors.systemRed,
    GoalCategory.power => CupertinoColors.systemOrange,
    GoalCategory.endurance => CupertinoColors.systemYellow,
    GoalCategory.mobility => CupertinoColors.systemCyan,
    GoalCategory.balance => CupertinoColors.systemTeal,
    GoalCategory.coordination => CupertinoColors.systemPurple,
    GoalCategory.quickness => CupertinoColors.systemBrown,
    GoalCategory.physique => CupertinoColors.systemBlue,
    GoalCategory.posture => CupertinoColors.systemIndigo,
    GoalCategory.rehabilitation => CupertinoColors.systemGreen,
    GoalCategory.longevity => CupertinoColors.systemMint,
    GoalCategory.skill => CupertinoColors.systemGrey,
  };
}
