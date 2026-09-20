import 'package:ethan_utils/ethan_utils.dart';

enum CardioType({
  required this.primaryWork,
  required this.hasDistance,
  required this.hasRoute,
}) {
  outdoorRun(
    primaryWork: CardioPrimaryWork.distanceAndPace,
    hasDistance: true,
    hasRoute: true,
  ),
  indoorRun(
    primaryWork: CardioPrimaryWork.distanceAndPace,
    hasDistance: true,
    hasRoute: false,
  ),
  outdoorWalk(
    primaryWork: CardioPrimaryWork.distanceAndPace,
    hasDistance: true,
    hasRoute: true,
  ),
  indoorWalk(
    primaryWork: CardioPrimaryWork.distanceAndPace,
    hasDistance: true,
    hasRoute: false,
  ),
  indoorCycle(
    primaryWork: CardioPrimaryWork.machineDistanceAndMets,
    hasDistance: true,
    hasRoute: false,
  ),
  outdoorCycle(
    primaryWork: CardioPrimaryWork.distanceAndPace,
    hasDistance: true,
    hasRoute: true,
  ),
  elliptical(
    primaryWork: CardioPrimaryWork.machineDistanceAndMets,
    hasDistance: true,
    hasRoute: false,
  ),
  stairClimbing(
    primaryWork: CardioPrimaryWork.flightsAndSteps,
    hasDistance: false,
    hasRoute: false,
  ),
  rowing(
    primaryWork: CardioPrimaryWork.machineDistanceAndMets,
    hasDistance: false,
    hasRoute: false,
  );

  final CardioPrimaryWork primaryWork;
  final bool hasDistance;
  final bool hasRoute;

  String get displayName => nameAsCapitalizedWords;

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
