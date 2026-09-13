import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/exercise_replacement_suggestion.dart';

import 'replace_exercise_badges.dart';

class const ReplaceExerciseSuggestions({
  required final List<ExerciseReplacementSuggestion>? suggestions,
  required final bool isLoading,
  required final Object? error,
  required final VoidCallback onLoadSuggestions,
  required final ValueChanged<ExerciseReplacementSuggestion> onSuggestionSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ReplaceExerciseSuggestionsLoading();
    final suggestionsError = error;
    if (suggestionsError != null) {
      return ReplaceExerciseSuggestionsError(
        error: suggestionsError,
        onRetry: onLoadSuggestions,
      );
    }
    final loadedSuggestions = suggestions;
    if (loadedSuggestions == null) {
      return ReplaceExerciseSuggestPrompt(onActivated: onLoadSuggestions);
    }
    if (loadedSuggestions.isEmpty) {
      return const ReplaceExerciseSuggestionsEmpty();
    }
    return ReplaceExerciseSuggestionsList(
      suggestions: loadedSuggestions,
      onSuggestionSelected: onSuggestionSelected,
    );
  }
}

class const ReplaceExerciseSuggestPrompt({
  required final VoidCallback onActivated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: InkWell(
        onTap: onActivated,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: ELayout.spaceMd,
            horizontal: ELayout.spaceLg,
          ),
          decoration: BoxDecoration(
            color: EColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(ELayout.radiusMd),
            border: Border.all(color: EColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: EColors.warning),
              const SizedBox(width: ELayout.spaceSm),
              Text(
                'Suggest similar exercises',
                style: EText.body.medium.copyWith(
                  color: EColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const ReplaceExerciseSuggestionsLoading() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: ELayout.spaceMd,
          horizontal: ELayout.spaceLg,
        ),
        decoration: BoxDecoration(
          color: EColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(
              child: Text(
                'Finding alternatives…',
                style: EText.body.medium.copyWith(color: EColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const ReplaceExerciseSuggestionsError({
  required final Object error,
  required final VoidCallback onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ELayout.spaceMd),
            decoration: BoxDecoration(
              color: EColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ELayout.radiusMd),
            ),
            child: Text(
              'Suggestions failed: $error',
              style: EText.caption.copyWith(color: EColors.danger),
            ),
          ),
          const SizedBox(height: ELayout.spaceSm),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class const ReplaceExerciseSuggestionsEmpty() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(ELayout.spaceMd),
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.border),
        ),
        child: Text(
          'No AI suggestions found. Pick from the library below.',
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
      ),
    );
  }
}

class const ReplaceExerciseSuggestionsList({
  required final List<ExerciseReplacementSuggestion> suggestions,
  required final ValueChanged<ExerciseReplacementSuggestion>
  onSuggestionSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReplaceExerciseSectionHeader(label: 'AI SUGGESTIONS'),
        ...suggestions.map(
          (suggestion) => ReplaceExerciseSuggestionRow(
            suggestion: suggestion,
            onSelected: () => onSuggestionSelected(suggestion),
          ),
        ),
      ],
    );
  }
}

class const ReplaceExerciseSuggestionRow({
  required final ExerciseReplacementSuggestion suggestion,
  required final VoidCallback onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EColors.border)),
      ),
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceLg,
            vertical: ELayout.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: EColors.warning,
                ),
              ),
              const SizedBox(width: ELayout.spaceMd),
              Expanded(child: ReplaceExerciseSuggestionDetails(suggestion: suggestion)),
              const SizedBox(width: ELayout.spaceSm),
              const Icon(
                Icons.add_circle_outline,
                color: EColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const ReplaceExerciseSuggestionDetails({
  required final ExerciseReplacementSuggestion suggestion,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final exercise = suggestion.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: EText.body.medium.copyWith(color: EColors.textPrimary),
              ),
            ),
            if (!suggestion.isFromLibrary) const ReplaceExerciseNewBadge(),
          ],
        ),
        if (suggestion.reason.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            suggestion.reason,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
        const SizedBox(height: ELayout.spaceXs),
        ReplaceExerciseBadges(exercise: exercise),
      ],
    );
  }
}
