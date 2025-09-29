import 'package:freezed_annotation/freezed_annotation.dart';

part 'heart_rate_sample.freezed.dart';
part 'heart_rate_sample.g.dart';

@freezed
class HeartRateSample with _$HeartRateSample {
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
}
