/// Time spent in each of 5 heart rate zones, stored in seconds.
///
/// This is the single value type for HR zone data throughout the app.
/// Stored at second-granularity (the finest available); minute-based
/// accessors are derived for display.
class HrZoneTime {
  const HrZoneTime({
    this.zone1 = 0,
    this.zone2 = 0,
    this.zone3 = 0,
    this.zone4 = 0,
    this.zone5 = 0,
  });

  static const zero = HrZoneTime();

  /// Constructs from a SQL row using column prefix, e.g. `total_zone1_seconds`.
  factory HrZoneTime.fromRow(
    Map<String, dynamic> row, {
    String prefix = 'total_zone',
    String suffix = '_seconds',
  }) => HrZoneTime(
    zone1: (row['${prefix}1$suffix'] as int?) ?? 0,
    zone2: (row['${prefix}2$suffix'] as int?) ?? 0,
    zone3: (row['${prefix}3$suffix'] as int?) ?? 0,
    zone4: (row['${prefix}4$suffix'] as int?) ?? 0,
    zone5: (row['${prefix}5$suffix'] as int?) ?? 0,
  );

  final int zone1;
  final int zone2;
  final int zone3;
  final int zone4;
  final int zone5;

  int get gteZone2 => zone2 + zone3 + zone4 + zone5;
  int get total => zone1 + zone2 + zone3 + zone4 + zone5;

  int get zone1Minutes => zone1 ~/ 60;
  int get zone2Minutes => zone2 ~/ 60;
  int get zone3Minutes => zone3 ~/ 60;
  int get zone4Minutes => zone4 ~/ 60;
  int get zone5Minutes => zone5 ~/ 60;
  int get gteZone2Minutes => gteZone2 ~/ 60;
  int get totalMinutes => total ~/ 60;

  int operator [](int zoneIndex) => switch (zoneIndex) {
    0 => zone1,
    1 => zone2,
    2 => zone3,
    3 => zone4,
    4 => zone5,
    _ => 0,
  };

  HrZoneTime operator +(HrZoneTime other) => HrZoneTime(
    zone1: zone1 + other.zone1,
    zone2: zone2 + other.zone2,
    zone3: zone3 + other.zone3,
    zone4: zone4 + other.zone4,
    zone5: zone5 + other.zone5,
  );
}
