import 'package:workouts/models/timestamped_heart_rate.dart';

enum HrZone {
  zone1(lowerBpm: 93, upperBpm: 114),
  zone2(lowerBpm: 115, upperBpm: 145),
  zone3(lowerBpm: 146, upperBpm: 162),
  zone4(lowerBpm: 163, upperBpm: 175),
  zone5(lowerBpm: 176, upperBpm: 185);

  const HrZone({required this.lowerBpm, required this.upperBpm});

  final int lowerBpm;
  final int upperBpm;

  static HrZone? forBpm(int bpm) {
    for (final zone in values.reversed) {
      if (bpm >= zone.lowerBpm) return zone;
    }
    return null;
  }
}

/// Time spent in each of 5 heart rate zones, stored in seconds.
///
/// This is the single value type for HR zone data throughout the app.
/// Stored at second-granularity (the finest available); minute-based
/// accessors are derived for display.
class const HrZoneTime({
  final int zone1 = 0,
  final int zone2 = 0,
  final int zone3 = 0,
  final int zone4 = 0,
  final int zone5 = 0,
}) {
  static const zero = HrZoneTime();

  /// Buckets continuous heart-rate samples into the 5-zone model.
  ///
  /// Each sample is the start of an interval that continues until the next
  /// sample (capped at [maxGapSeconds] to handle dropouts).
  factory fromSamples(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) return HrZoneTime.zero;

    final zoneTotals = List.filled(HrZone.values.length, 0);
    for (var sampleIndex = 0; sampleIndex < samples.length - 1; sampleIndex++) {
      final gapSeconds = samples[sampleIndex + 1].timestamp
          .difference(samples[sampleIndex].timestamp)
          .inSeconds
          .clamp(0, maxGapSeconds);
      if (gapSeconds <= 0) continue;
      final zone = HrZone.forBpm(samples[sampleIndex].bpm);
      if (zone != null) zoneTotals[zone.index] += gapSeconds;
    }

    return HrZoneTime(
      zone1: zoneTotals[0],
      zone2: zoneTotals[1],
      zone3: zoneTotals[2],
      zone4: zoneTotals[3],
      zone5: zoneTotals[4],
    );
  }

  /// Constructs from a SQL row using column prefix, e.g. `total_zone1_seconds`.
  factory fromRow(
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

  List<int> get asList => [zone1, zone2, zone3, zone4, zone5];

  Map<String, Object?> toRow() => {
    'zone1_seconds': zone1,
    'zone2_seconds': zone2,
    'zone3_seconds': zone3,
    'zone4_seconds': zone4,
    'zone5_seconds': zone5,
  };

  int get gteZone2 => zone2 + zone3 + zone4 + zone5;
  int get easyAerobicSeconds => zone1 + zone2;
  int get hardAerobicSeconds => zone4 + zone5;
  int get total => zone1 + zone2 + zone3 + zone4 + zone5;

  int get dominantZoneIndex {
    var dominantZoneIndex = 0;
    for (var zoneIndex = 1; zoneIndex < 5; zoneIndex++) {
      if (this[zoneIndex] > this[dominantZoneIndex]) {
        dominantZoneIndex = zoneIndex;
      }
    }
    return dominantZoneIndex;
  }

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

  @override
  bool operator ==(Object other) =>
      other is HrZoneTime &&
      other.zone1 == zone1 &&
      other.zone2 == zone2 &&
      other.zone3 == zone3 &&
      other.zone4 == zone4 &&
      other.zone5 == zone5;

  @override
  int get hashCode => Object.hash(zone1, zone2, zone3, zone4, zone5);
}
