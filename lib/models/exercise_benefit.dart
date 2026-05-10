import 'dart:convert';

/// A named physiological benefit of an exercise, optionally linked to
/// one or more of the user's fitness goals by ID.
///
/// Benefits are stored as a JSON array on the `exercises` table and surfaced
/// on [WorkoutExercise.benefits] at read time. The goal links drive the
/// Training Balance Strip — a session dot appears in a goal's row iff the
/// session contains any exercise with a benefit referencing that goal.
class ExerciseBenefit {
  const ExerciseBenefit({required this.name, required this.goalIds});

  /// Human-readable benefit label, e.g. "spinal stability", "quad drive".
  final String name;

  /// IDs of [FitnessGoal] records this benefit serves.
  /// An empty list means the benefit is informational only (no goal link).
  final List<String> goalIds;

  factory ExerciseBenefit.fromJson(Map<String, dynamic> json) =>
      ExerciseBenefit(
        name: json['name'] as String,
        goalIds:
            (json['goalIds'] as List<dynamic>?)
                ?.map((goalId) => goalId as String)
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {'name': name, 'goalIds': goalIds};

  ExerciseBenefit copyWith({String? name, List<String>? goalIds}) =>
      ExerciseBenefit(
        name: name ?? this.name,
        goalIds: goalIds ?? this.goalIds,
      );

  /// Decode a JSON text column value to a list of benefits.
  /// Returns an empty list for null/empty/malformed input.
  static List<ExerciseBenefit> listFromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((item) => ExerciseBenefit.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Encode a list of benefits to a JSON string for DB storage.
  static String listToJsonString(List<ExerciseBenefit> benefits) =>
      jsonEncode(benefits.map((benefit) => benefit.toJson()).toList());
}
