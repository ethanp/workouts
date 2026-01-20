import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_influence.freezed.dart';
part 'training_influence.g.dart';

@freezed
abstract class TrainingInfluence with _$TrainingInfluence {
  const factory TrainingInfluence({
    required String id,
    required String name,
    required String description,
    required List<String> principles,
    @Default(false) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TrainingInfluence;

  factory TrainingInfluence.fromJson(Map<String, dynamic> json) =>
      _$TrainingInfluenceFromJson(json);
}

/// Pre-loaded training influences to seed the database.
const seedInfluences = [
  TrainingInfluence(
    id: 'pavel-tsatsouline',
    name: 'Pavel Tsatsouline',
    description: 'Founder of StrongFirst, known for bringing kettlebells to the West',
    principles: [
      'Submaximal training - train heavy but leave reps in the tank',
      'Tension techniques - crush the handle, brace the core',
      'Hardstyle kettlebell - powerful, explosive movements',
      'Grease the groove - frequent practice at submaximal intensity',
      'Power to the people - deadlift and press focus',
    ],
  ),
  TrainingInfluence(
    id: 'mark-wildman',
    name: 'Mark Wildman',
    description: 'Wildman Athletica, expert in clubs, maces, and kettlebells',
    principles: [
      'Club and mace integration - rotational strength and mobility',
      'Skill-first approach - master technique before adding load',
      'Tetris programming - fit training blocks together efficiently',
      'Nerd Math - systematic progression with measurable volume',
      'Movement quality over quantity',
    ],
  ),
  TrainingInfluence(
    id: 'kelly-starrett',
    name: 'Kelly Starrett',
    description: 'The Ready State, mobility and movement specialist',
    principles: [
      'Mobility-first - address movement restrictions before loading',
      'Positional priority - get into good positions before moving',
      'Daily maintenance - 10-15 min mobility work every day',
      'Upstream/downstream - pain often comes from adjacent areas',
      'Breathe, brace, move - proper sequencing',
    ],
  ),
  TrainingInfluence(
    id: 'starting-strength',
    name: 'Starting Strength',
    description: 'Mark Rippetoe\'s barbell training methodology',
    principles: [
      'Linear progression - add weight every session',
      'Compound lifts focus - squat, deadlift, press, bench, row',
      'Simple and effective - minimal exercise selection',
      'Strength is the foundation for all athletic qualities',
      'Full range of motion with proper mechanics',
    ],
  ),
  TrainingInfluence(
    id: 'dan-john',
    name: 'Dan John',
    description: 'Legendary strength coach and author',
    principles: [
      'Easy strength - lift heavy but not hard, frequently',
      'Minimalism - do the least to get the most',
      'Fundamental human movements - push, pull, hinge, squat, carry',
      'Park bench vs bus bench workouts - balance intensity',
      'Show up and do the work consistently',
    ],
  ),
];
