import 'package:ethan_utils/ethan_utils.dart';

enum CardioType {
  outdoorRun,
  indoorRun,
  indoorWalk,
  elliptical,
  stairClimbing,
  rowing;

  String get displayName => name.titleCase;

  bool get hasRoute => this == outdoorRun;

  bool get hasDistance => switch (this) {
    outdoorRun || indoorRun || indoorWalk || elliptical => true,
    stairClimbing || rowing => false,
  };

  String get dbKey => name;

  static CardioType fromDbKey(String key) => values.firstWhere(
    (cardioType) => cardioType.name == key,
    orElse: () => outdoorRun,
  );
}
