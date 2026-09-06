import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/exercise_benefits_provider.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:ethan_sync/ethan_sync.dart' show isOfflineProvider;
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

/// Review sheet for AI-generated or manually edited exercise benefits.
///
/// The user sees proposed benefits with their goal links and can:
/// - Swipe to delete a benefit
/// - Tap a benefit to toggle goal links
/// - Add a benefit manually
/// - Tap "Apply" to persist or "Cancel" to discard
class const ExerciseBenefitsSheet({
  required final WorkoutExercise exercise,
  final bool autoGenerate = false,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<ExerciseBenefitsSheet> createState() =>
      _ExerciseBenefitsSheetState();
}

class _ExerciseBenefitsSheetState()
    extends ConsumerState<ExerciseBenefitsSheet> {
  late List<ExerciseBenefit> _editableBenefits;
  bool _isGenerating = false;
  bool _hasAutoTriggered = false;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _editableBenefits = List.of(widget.exercise.benefits);
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(activeGoalsStreamProvider);
    final activeGoals = goalsAsync.value ?? [];
    final saveState = ref.watch(exerciseBenefitsControllerProvider);
    final isSaving = saveState is AsyncLoading;
    final bool isOffline = ref.watch(isOfflineProvider);

    if (widget.autoGenerate &&
        !_hasAutoTriggered &&
        goalsAsync.hasValue &&
        !isOffline) {
      _hasAutoTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _generate(activeGoals),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _appHeader(activeGoals, isSaving, context),
      body: SafeArea(child: _body(activeGoals, isOffline)),
    );
  }

  EAppHeader _appHeader(
    List<FitnessGoal> activeGoals,
    bool isSaving,
    BuildContext context,
  ) {
    return EAppHeader(
      title: widget.exercise.name,
      automaticallyImplyLeading: false,
      leading: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => _persistBenefitEdits(context),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _body(List<FitnessGoal> activeGoals, bool isOffline) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(ELayout.spaceLg),
            children: [
              ConnectionGatedWidget(
                child: Column(
                  children: [
                    _generateButton(activeGoals),
                    if (_generationError != null) ...[
                      const SizedBox(height: ELayout.spaceSm),
                      Text(
                        _generationError!,
                        style: EText.caption.copyWith(
                          color: EColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: ELayout.spaceLg),
                  ],
                ),
              ),
              if (_editableBenefits.isEmpty)
                _emptyState(isOffline)
              else
                ..._editableBenefits.asMap().entries.map(
                  (entry) => _benefitTile(entry.value, entry.key, activeGoals),
                ),
              const SizedBox(height: ELayout.spaceMd),
              _addBenefitButton(activeGoals),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generateButton(List<FitnessGoal> activeGoals) {
    return InkWell(
      onTap: _isGenerating ? null : () => _generate(activeGoals),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: ELayout.spaceMd,
          horizontal: ELayout.spaceLg,
        ),
        decoration: BoxDecoration(
          color: EColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(
            color: EColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGenerating)
              const CircularProgressIndicator()
            else
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: EColors.warning,
              ),
            const SizedBox(width: ELayout.spaceSm),
            Text(
              _isGenerating ? 'Generating…' : 'Generate Benefits with AI',
              style: EText.body.medium.copyWith(
                color: EColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isOffline) {
    final String message = isOffline
        ? 'No benefits yet. Add manually.'
        : 'No benefits yet. Generate with AI or add manually.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ELayout.spaceXl),
      child: Center(
        child: Text(
          message,
          style: EText.caption.copyWith(color: EColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _benefitTile(
    ExerciseBenefit benefit,
    int benefitIndex,
    List<FitnessGoal> activeGoals,
  ) {
    return Dismissible(
      key: ValueKey('benefit-$benefitIndex-${benefit.name}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          setState(() => _editableBenefits.removeAt(benefitIndex)),
      background: _swipeDeleteBackground(),
      child: _benefitCard(benefit, benefitIndex, activeGoals),
    );
  }

  Widget _swipeDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
      ),
      child: const Icon(Icons.delete, color: EColors.danger, size: 20),
    );
  }

  Widget _benefitCard(
    ExerciseBenefit benefit,
    int benefitIndex,
    List<FitnessGoal> activeGoals,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceSm),
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            benefit.name,
            style: EText.body.medium.copyWith(color: EColors.textPrimary),
          ),
          if (activeGoals.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceSm),
            Wrap(
              spacing: ELayout.spaceXs,
              runSpacing: ELayout.spaceXs,
              children: activeGoals
                  .map(
                    (goal) => _goalChip(
                      goal,
                      benefit.goalIds.contains(goal.id),
                      () => _toggleGoalLink(benefitIndex, goal.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _goalChip(FitnessGoal goal, bool isLinked, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceSm,
          vertical: ELayout.spaceXs,
        ),
        decoration: BoxDecoration(
          color: isLinked
              ? EColors.accent.withValues(alpha: 0.2)
              : EColors.surface,
          borderRadius: BorderRadius.circular(ELayout.radiusSm),
          border: Border.all(
            color: isLinked
                ? EColors.accent.withValues(alpha: 0.5)
                : EColors.border,
          ),
        ),
        child: Text(
          goal.title,
          style: EText.caption.copyWith(
            color: isLinked ? EColors.accent : EColors.textTertiary,
            fontWeight: isLinked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _addBenefitButton(List<FitnessGoal> activeGoals) {
    return InkWell(
      onTap: _addManualBenefit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: ELayout.spaceMd,
          horizontal: ELayout.spaceLg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              size: 16,
              color: EColors.textTertiary,
            ),
            const SizedBox(width: ELayout.spaceSm),
            Text(
              'Add Benefit',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleGoalLink(int benefitIndex, String goalId) {
    final benefit = _editableBenefits[benefitIndex];
    final updatedGoalIds = List<String>.of(benefit.goalIds);
    if (updatedGoalIds.contains(goalId)) {
      updatedGoalIds.remove(goalId);
    } else {
      updatedGoalIds.add(goalId);
    }
    setState(() {
      _editableBenefits[benefitIndex] = benefit.copyWith(
        goalIds: updatedGoalIds,
      );
    });
  }

  Future<void> _generate(List<FitnessGoal> activeGoals) async {
    setState(() {
      _isGenerating = true;
      _generationError = null;
    });

    try {
      final llmService = ref.read(llmServiceProvider);
      final generatedBenefits = await llmService.generateExerciseBenefits(
        exerciseName: widget.exercise.name,
        activeGoals: activeGoals,
      );
      setState(() => _editableBenefits = generatedBenefits);
    } catch (error) {
      setState(() => _generationError = 'Generation failed: $error');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _addManualBenefit() {
    setState(() {
      _editableBenefits.add(
        ExerciseBenefit(name: _nextManualBenefitName(), goalIds: const []),
      );
    });
  }

  String _nextManualBenefitName() {
    const baseName = 'Manual benefit';
    final existingNames = _editableBenefits
        .map((benefit) => benefit.name)
        .toSet();
    if (!existingNames.contains(baseName)) return baseName;

    var benefitNumber = 2;
    while (existingNames.contains('$baseName $benefitNumber')) {
      benefitNumber++;
    }
    return '$baseName $benefitNumber';
  }

  Future<void> _persistBenefitEdits(BuildContext context) async {
    final benefitsController = ref.read(
      exerciseBenefitsControllerProvider.notifier,
    );
    await benefitsController.saveBenefits(widget.exercise, _editableBenefits);
    final saveState = ref.read(exerciseBenefitsControllerProvider);
    if (mounted && saveState.hasError) {
      setState(() => _generationError = 'Save failed: ${saveState.error}');
      return;
    }
    if (mounted) {
      Navigator.of(this.context).pop();
    }
  }
}
