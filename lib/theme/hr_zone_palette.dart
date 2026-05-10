import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

class HrZonePalette {
  const HrZonePalette._();

  static const zone1 = Color(0xFF5BB5EA);
  static const zone2 = Color(0xFF36BF7E);
  static const zone3 = Color(0xFFECC048);
  static const zone4 = Color(0xFFE87838);
  static const zone5 = Color(0xFFDC4858);

  static const zoneColors = [zone1, zone2, zone3, zone4, zone5];
  static const zoneShortNames = [
    'Recovery',
    'Aerobic',
    'Tempo',
    'Threshold',
    'VO₂max',
  ];
  static final zoneNames = zoneShortNames.mapLWithIndex(
    (shortName, zoneIndex) => 'Z${zoneIndex + 1} $shortName',
  );
}
