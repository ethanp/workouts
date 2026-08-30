import 'package:ethan_utils/ethan_utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/weight.dart';

class const DurationSecondsConverter() extends JsonConverter<Duration, int> {
  @override
  Duration fromJson(int json) => Duration(seconds: json);

  @override
  int toJson(Duration object) => object.inSeconds;
}

class const NullableDurationSecondsConverter()
    extends JsonConverter<Duration?, int?> {
  @override
  Duration? fromJson(int? json) =>
      json.map((durationSeconds) => Duration(seconds: durationSeconds));

  @override
  int? toJson(Duration? object) => object?.inSeconds;
}

class const NullableWeightKilogramsConverter()
    extends JsonConverter<Weight?, num?> {
  @override
  Weight? fromJson(num? json) =>
      json.map((weightKg) => Weight.kilograms(weightKg.toDouble()));

  @override
  num? toJson(Weight? object) => object?.kilograms;
}
