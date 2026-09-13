import 'package:ethan_utils/ethan_utils.dart';

enum CardioType({required this.primaryWork}) {
  outdoorRun(primaryWork: CardioPrimaryWork.distanceAndPace),
  indoorRun(primaryWork: CardioPrimaryWork.distanceAndPace),
  outdoorWalk(primaryWork: CardioPrimaryWork.distanceAndPace),
  indoorWalk(primaryWork: CardioPrimaryWork.distanceAndPace),
  elliptical(primaryWork: CardioPrimaryWork.machineDistanceAndMets),
  stairClimbing(primaryWork: CardioPrimaryWork.flightsAndSteps),
  rowing(primaryWork: CardioPrimaryWork.machineDistanceAndMets);

  final CardioPrimaryWork primaryWork;

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

enum CardioPrimaryWork() {
  distanceAndPace,
  machineDistanceAndMets,
  flightsAndSteps;
}
