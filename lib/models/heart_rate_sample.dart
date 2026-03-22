import 'package:freezed_annotation/freezed_annotation.dart';

part 'heart_rate_sample.freezed.dart';
part 'heart_rate_sample.g.dart';

@freezed
abstract class HeartRateSample with _$HeartRateSample {
  const factory HeartRateSample({
    required String id,
    required String sessionId,
    required DateTime timestamp,
    required int bpm,
    double? energyKcal,
    required String source,
  }) = _HeartRateSample;

  factory HeartRateSample.fromJson(Map<String, dynamic> json) =>
      _$HeartRateSampleFromJson(json);

  factory HeartRateSample.fromRow(Map<String, dynamic> sampleRow) {
    return HeartRateSample(
      id: sampleRow['id'] as String,
      sessionId: sampleRow['session_id'] as String,
      timestamp: DateTime.parse(sampleRow['timestamp'] as String),
      bpm: sampleRow['bpm'] as int,
      energyKcal: (sampleRow['energy_kcal'] as num?)?.toDouble(),
      source: sampleRow['source'] as String,
    );
  }
}
