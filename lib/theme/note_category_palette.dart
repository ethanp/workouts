import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/background_note.dart';

extension NoteCategoryColor on NoteCategory {
  Color get color => switch (this) {
    NoteCategory.injuryHistory => EColors.danger,
    NoteCategory.avoid => EColors.warning,
    NoteCategory.medical => EColors.danger,
    NoteCategory.preference => EColors.warning,
    NoteCategory.equipment => EColors.accent,
    NoteCategory.constraint => EColors.warning,
    NoteCategory.philosophy => EColors.success,
  };
}
