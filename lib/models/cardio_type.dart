import 'package:ethan_utils/ethan_utils.dart';

enum CardioType {
  outdoorRun,
  indoorRun,
  outdoorWalk,
  indoorWalk,
  elliptical,
  stairClimbing,
  rowing;

  String get displayName => name.titleCase;

  bool get hasRoute => this == outdoorRun || this == outdoorWalk;

  bool get hasDistance => switch (this) {
    outdoorRun || indoorRun || outdoorWalk || indoorWalk || elliptical => true,
    stairClimbing || rowing => false,
  };

  String get dbKey => name;

  static CardioType fromDbKey(String key) => values.firstWhere(
    (cardioType) => cardioType.name == key,
    orElse: () => outdoorRun,
  );
}
