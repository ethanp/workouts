import 'package:ethan_utils/ethan_utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/weight.dart';

class DurationSecondsConverter extends JsonConverter<Duration, int> {
  const DurationSecondsConverter();

  @override
  Duration fromJson(int json) => Duration(seconds: json);

  @override
  int toJson(Duration object) => object.inSeconds;
}

class NullableDurationSecondsConverter extends JsonConverter<Duration?, int?> {
  const NullableDurationSecondsConverter();

  @override
  Duration? fromJson(int? json) =>
      json.map((durationSeconds) => Duration(seconds: durationSeconds));

  @override
  int? toJson(Duration? object) => object?.inSeconds;
}

class NullableWeightKilogramsConverter extends JsonConverter<Weight?, num?> {
  const NullableWeightKilogramsConverter();

  @override
  Weight? fromJson(num? json) =>
      json.map((weightKg) => Weight.kilograms(weightKg.toDouble()));

  @override
  num? toJson(Weight? object) => object?.kilograms;
}
