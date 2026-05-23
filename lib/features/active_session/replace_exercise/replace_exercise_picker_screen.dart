import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/exercise_replacement_suggestion.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

/// Modal selector used during a session to swap an exercise. Surfaces an AI
/// "Suggest similar exercises" affordance above a modality-filtered library
/// list. Returns the chosen [WorkoutExercise] via `Navigator.pop`. The caller
/// cannot tell whether the result came from the library or was an AI-proposed
/// new movement — that detail belongs to the picker.
class ReplaceExercisePickerScreen extends ConsumerWidget {
  const ReplaceExercisePickerScreen({
    super.key,
    required this.originalExercise,
    required this.excludeIds,
  });

  final WorkoutExercise originalExercise;
  final Set<String> excludeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: _navigationBar(context),
      child: exercisesAsync.when(
        data: (exercises) => _ReplacePickerBody(
          originalExercise: originalExercise,
          excludeIds: excludeIds,
          libraryExercises: exercises,
        ),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ),
      ),
    );
  }

  CupertinoNavigationBar _navigationBar(BuildContext context) {
    return CupertinoNavigationBar(
      backgroundColor: AppColors.backgroundDepth1,
      border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
      middle: Text(
        'Replace ${originalExercise.name}',
        style: AppTypography.title,
        overflow: TextOverflow.ellipsis,
      ),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(CupertinoIcons.xmark, color: AppColors.textColor2),
      ),
    );
  }
}

class _ReplacePickerBody extends ConsumerStatefulWidget {
  const _ReplacePickerBody({
    required this.originalExercise,
    required this.excludeIds,
    required this.libraryExercises,
  });

  final WorkoutExercise originalExercise;
  final Set<String> excludeIds;
  final List<WorkoutExercise> libraryExercises;

  @override
  ConsumerState<_ReplacePickerBody> createState() => _ReplacePickerBodyState();
}

class _ReplacePickerBodyState extends ConsumerState<_ReplacePickerBody> {
  ExerciseModality? _selectedModality;
  List<ExerciseReplacementSuggestion>? _suggestions;
  bool _isLoadingSuggestions = false;
  Object? _suggestionsError;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _filterChips(),
          Expanded(child: _scrollableBody()),
        ],
      ),
    );
  }

  Widget _scrollableBody() {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ConnectionGatedWidget(child: _aiSuggestionsSection()),
        ..._libraryListItems(),
      ],
    );
  }

  Widget _aiSuggestionsSection() {
    if (_isLoadingSuggestions) return _suggestionsLoading();
    if (_suggestionsError != null) {
      return _suggestionsErrorBanner(_suggestionsError!);
    }
    final suggestions = _suggestions;
    if (suggestions == null) return _suggestPromptButton();
    if (suggestions.isEmpty) return _suggestionsEmptyBanner();
    return _suggestionsList(suggestions);
  }

  Widget _suggestPromptButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loadSuggestions,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentSecondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.accentSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.sparkles,
                size: 16,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Suggest similar exercises',
                style: AppTypography.body.copyWith(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionsLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.accentSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Finding alternatives…',
                style: AppTypography.body.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionsErrorBanner(Object error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'Suggestions failed: $error',
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _loadSuggestions,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsEmptyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Text(
          'No AI suggestions found. Pick from the library below.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ),
    );
  }

  Widget _suggestionsList(List<ExerciseReplacementSuggestion> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('AI SUGGESTIONS'),
        ...suggestions.map(_suggestionRow),
      ],
    );
  }

  Widget _suggestionRow(ExerciseReplacementSuggestion suggestion) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDepth1)),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onPressed: () => Navigator.of(context).pop(suggestion.exercise),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.sparkles,
                size: 16,
                color: AppColors.accentSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _suggestionDetails(suggestion)),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              CupertinoIcons.add_circled,
              color: AppColors.accentPrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionDetails(ExerciseReplacementSuggestion suggestion) {
    final exercise = suggestion.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.textColor1,
                ),
              ),
            ),
            if (!suggestion.isFromLibrary) _newBadge(),
          ],
        ),
        if (suggestion.reason.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            suggestion.reason,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        _exerciseBadges(exercise),
      ],
    );
  }

  Widget _newBadge() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.accentPrimary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      'NEW',
      style: AppTypography.caption.copyWith(
        color: AppColors.accentPrimary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );

  List<Widget> _libraryListItems() {
    final groups = _groupedFilteredLibrary();
    if (groups.isEmpty) {
      return [
        _sectionHeader('LIBRARY'),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              'No exercises available',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ),
        ),
      ];
    }

    final modalities = groups.keys.toList().sortedOn(
      (modality) => modality.name,
    );

    return [
      _sectionHeader('LIBRARY'),
      for (final modality in modalities)
        _modalitySection(modality, groups[modality]!),
    ];
  }

  Widget _filterChips() {
    final modalities = _availableLibraryModalities().toList().sortedOn(
      (modality) => modality.name,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _filterChip(null, 'All'),
          ...modalities.map(
            (modality) => _filterChip(modality, modality.name.toUpperCase()),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ExerciseModality? modality, String label) {
    final isSelected = _selectedModality == modality;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _selectedModality = modality),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? AppColors.textColor1 : AppColors.textColor3,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalitySection(
    ExerciseModality modality,
    List<WorkoutExercise> exercises,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            modality.name.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...exercises.map(_libraryRow),
      ],
    );
  }

  Widget _libraryRow(WorkoutExercise exercise) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDepth1)),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onPressed: () => Navigator.of(context).pop(exercise),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _exerciseBadges(exercise),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.add_circled,
              color: AppColors.accentPrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseBadges(WorkoutExercise exercise) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _modalityBadge(exercise.modality),
        if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
          _equipmentBadge(exercise.equipment!),
      ],
    );
  }

  Widget _modalityBadge(ExerciseModality modality) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        modality.name,
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor3,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _equipmentBadge(String equipment) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.cube,
            size: 12,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            equipment,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor4,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  List<WorkoutExercise> _filteredLibrary() {
    final available = widget.libraryExercises.whereL(
      (exercise) => !widget.excludeIds.contains(exercise.id),
    );
    if (_selectedModality == null) return available;
    return available.whereL(
      (exercise) => exercise.modality == _selectedModality,
    );
  }

  Set<ExerciseModality> _availableLibraryModalities() {
    return widget.libraryExercises
        .where((exercise) => !widget.excludeIds.contains(exercise.id))
        .map((exercise) => exercise.modality)
        .toSet();
  }

  Map<ExerciseModality, List<WorkoutExercise>> _groupedFilteredLibrary() {
    final grouped = <ExerciseModality, List<WorkoutExercise>>{};
    for (final exercise in _filteredLibrary()) {
      grouped.putIfAbsent(exercise.modality, () => []).add(exercise);
    }
    return grouped;
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });

    final llmService = ref.read(llmServiceProvider);
    final activeGoals =
        ref.read(activeGoalsStreamProvider).value ?? const [];

    try {
      final suggestions = await llmService.suggestExerciseReplacements(
        originalExercise: widget.originalExercise,
        activeGoals: activeGoals,
        libraryExercises: widget.libraryExercises,
        excludeIds: widget.excludeIds,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = error;
        _isLoadingSuggestions = false;
      });
    }
  }
}
