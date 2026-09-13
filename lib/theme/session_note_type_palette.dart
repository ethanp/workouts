import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/session_note.dart';

extension SessionNoteTypeColor on SessionNoteType {
  Color get color => switch (this) {
    SessionNoteType.observation => EColors.textSecondary,
    SessionNoteType.modification => EColors.accent,
    SessionNoteType.painSignal => EColors.warning,
    SessionNoteType.breakthrough => EColors.success,
  };
}
