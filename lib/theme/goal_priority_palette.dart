import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const GoalPriorityPalette._() {
  static const priority1 = EColors.warning;
  static const priority2 = EColors.accent;
  static const priority3 = EColors.success;

  static Color colorFor(int priority) => switch (priority) {
    1 => priority1,
    2 => priority2,
    3 => priority3,
    _ => EColors.textMuted,
  };
}
