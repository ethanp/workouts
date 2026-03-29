import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_location.freezed.dart';
part 'training_location.g.dart';

@freezed
abstract class TrainingLocation with _$TrainingLocation {
  const factory TrainingLocation({
    required String id,
    required String name,
    @Default('') String equipment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TrainingLocation;

  factory TrainingLocation.fromJson(Map<String, dynamic> json) =>
      _$TrainingLocationFromJson(json);

  factory TrainingLocation.fromRow(Map<String, dynamic> locationRow) {
    return TrainingLocation(
      id: locationRow['id'] as String,
      name: locationRow['name'] as String,
      equipment: (locationRow['equipment'] as String?) ?? '',
      createdAt: _asDateTime(locationRow['created_at']),
      updatedAt: _asDateTime(locationRow['updated_at']),
    );
  }
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
