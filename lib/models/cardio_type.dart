import 'package:ethan_utils/ethan_utils.dart';

enum CardioType {
  outdoorRun,
  indoorRun,
  elliptical,
  stairClimbing,
  rowing;

  String get displayName => name.titleCase;

  bool get hasRoute => this == outdoorRun;

  bool get hasDistance =>
      this == outdoorRun || this == indoorRun || this == elliptical;

  String get dbKey => name;

  static CardioType fromDbKey(String key) =>
      values.firstWhere((t) => t.name == key, orElse: () => outdoorRun);
}
