import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/exercise_benefits_provider.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/theme/app_theme.dart';

/// Review sheet for AI-generated or manually edited exercise benefits.
///
/// The user sees proposed benefits with their goal links and can:
/// - Swipe to delete a benefit
/// - Tap a benefit to toggle goal links
/// - Add a benefit manually
/// - Tap "Apply" to persist or "Cancel" to discard
class ExerciseBenefitsSheet extends ConsumerStatefulWidget {
  const ExerciseBenefitsSheet({super.key, required this.exercise});

  final WorkoutExercise exercise;

  @override
  ConsumerState<ExerciseBenefitsSheet> createState() =>
      _ExerciseBenefitsSheetState();
}

class _ExerciseBenefitsSheetState extends ConsumerState<ExerciseBenefitsSheet> {
  late List<ExerciseBenefit> _editableBenefits;
  bool _isGenerating = false;
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

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: _navigationBar(activeGoals, isSaving, context),
      child: SafeArea(child: _body(activeGoals)),
    );
  }

  CupertinoNavigationBar _navigationBar(
    List<FitnessGoal> activeGoals,
    bool isSaving,
    BuildContext context,
  ) {
    return CupertinoNavigationBar(
      backgroundColor: AppColors.backgroundDepth1,
      border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
      middle: Text(
        widget.exercise.name,
        style: AppTypography.subtitle,
        overflow: TextOverflow.ellipsis,
      ),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Cancel',
          style: TextStyle(color: AppColors.textColor3),
        ),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isSaving ? null : () => _apply(context),
        child: Text(
          'Apply',
          style: TextStyle(
            color: isSaving ? AppColors.textColor4 : AppColors.accentPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _body(List<FitnessGoal> activeGoals) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _generateButton(activeGoals),
              if (_generationError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _generationError!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_editableBenefits.isEmpty)
                _emptyState()
              else
                ..._editableBenefits.asMap().entries.map(
                  (entry) => _benefitTile(entry.value, entry.key, activeGoals),
                ),
              const SizedBox(height: AppSpacing.md),
              _addBenefitButton(activeGoals),
            ],
          ),
        ),
      ],
    );
  }

  Widget _generateButton(List<FitnessGoal> activeGoals) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _isGenerating ? null : () => _generate(activeGoals),
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
            if (_isGenerating)
              const CupertinoActivityIndicator()
            else
              const Icon(
                CupertinoIcons.sparkles,
                size: 16,
                color: AppColors.accentSecondary,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _isGenerating ? 'Generating…' : 'Generate Benefits with AI',
              style: AppTypography.body.copyWith(
                color: AppColors.accentSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          'No benefits yet. Generate with AI or add manually.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
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
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Icon(CupertinoIcons.trash, color: AppColors.error, size: 20),
    );
  }

  Widget _benefitCard(
    ExerciseBenefit benefit,
    int benefitIndex,
    List<FitnessGoal> activeGoals,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            benefit.name,
            style: AppTypography.body.copyWith(color: AppColors.textColor1),
          ),
          if (activeGoals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isLinked
              ? AppColors.accentPrimary.withValues(alpha: 0.2)
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isLinked
                ? AppColors.accentPrimary.withValues(alpha: 0.5)
                : AppColors.borderDepth1,
          ),
        ),
        child: Text(
          goal.title,
          style: AppTypography.caption.copyWith(
            color: isLinked ? AppColors.accentPrimary : AppColors.textColor3,
            fontWeight: isLinked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _addBenefitButton(List<FitnessGoal> activeGoals) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _addManualBenefit(activeGoals),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.add,
              size: 16,
              color: AppColors.textColor3,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add Benefit',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
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

  Future<void> _addManualBenefit(List<FitnessGoal> activeGoals) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => _AddBenefitDialog(
        activeGoals: activeGoals,
        onAdd: (benefit) => setState(() => _editableBenefits.add(benefit)),
      ),
    );
  }

  Future<void> _apply(BuildContext context) async {
    await ref
        .read(exerciseBenefitsControllerProvider.notifier)
        .saveBenefits(widget.exercise, _editableBenefits);
    if (mounted) {
      Navigator.of(this.context).pop();
    }
  }
}

class _AddBenefitDialog extends StatefulWidget {
  const _AddBenefitDialog({required this.activeGoals, required this.onAdd});

  final List<FitnessGoal> activeGoals;
  final void Function(ExerciseBenefit) onAdd;

  @override
  State<_AddBenefitDialog> createState() => _AddBenefitDialogState();
}

class _AddBenefitDialogState extends State<_AddBenefitDialog> {
  final _nameController = TextEditingController();
  final Set<String> _selectedGoalIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Add Benefit'),
      content: _dialogContent(),
      actions: [_cancelAction(context), _addAction(context)],
    );
  }

  Widget _dialogContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _nameField(),
        if (widget.activeGoals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _goalLinkSection(),
        ],
      ],
    );
  }

  Widget _nameField() {
    return CupertinoTextField(
      controller: _nameController,
      placeholder: 'e.g. "spinal stability"',
      style: const TextStyle(color: AppColors.textColor1),
    );
  }

  Widget _goalLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Link to goals (optional):',
            style: TextStyle(fontSize: 12, color: AppColors.textColor3),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: widget.activeGoals.map(_goalToggleChip).toList(),
        ),
      ],
    );
  }

  Widget _goalToggleChip(FitnessGoal goal) {
    final isSelected = _selectedGoalIds.contains(goal.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedGoalIds.remove(goal.id);
        } else {
          _selectedGoalIds.add(goal.id);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.2)
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          goal.title,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? AppColors.accentPrimary : AppColors.textColor3,
          ),
        ),
      ),
    );
  }

  CupertinoDialogAction _cancelAction(BuildContext context) {
    return CupertinoDialogAction(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    );
  }

  CupertinoDialogAction _addAction(BuildContext context) {
    return CupertinoDialogAction(
      isDefaultAction: true,
      onPressed: () {
        final name = _nameController.text.trim();
        if (name.isEmpty) return;
        widget.onAdd(
          ExerciseBenefit(name: name, goalIds: _selectedGoalIds.toList()),
        );
        Navigator.of(context).pop();
      },
      child: const Text('Add'),
    );
  }
}
