import 'package:flutter/cupertino.dart';
import 'package:workouts/features/goals/goals_modal_labeled_field.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.initialGoal, required this.onSave});

  final FitnessGoal? initialGoal;
  final Future<void> Function(
    String title,
    GoalCategory category,
    String description,
    int priority,
  )
  onSave;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late GoalCategory _selectedCategory;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialGoal?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialGoal?.description ?? '',
    );
    _selectedCategory = widget.initialGoal?.category ?? GoalCategory.strength;
    _priority = widget.initialGoal?.priority ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialGoal != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: AppSpacing.lg),
              _sheetTitle(isEditing),
              const SizedBox(height: AppSpacing.xl),
              _titleField(),
              const SizedBox(height: AppSpacing.lg),
              _categoryField(),
              const SizedBox(height: AppSpacing.lg),
              _priorityField(),
              const SizedBox(height: AppSpacing.lg),
              _descriptionField(),
              const SizedBox(height: AppSpacing.xl),
              _saveButton(context, isEditing),
              const SizedBox(height: AppSpacing.md),
              _cancelButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderDepth3,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _sheetTitle(bool isEditing) => Text(
    isEditing ? 'Edit Goal' : 'New Goal',
    style: AppTypography.title,
    textAlign: TextAlign.center,
  );

  Widget _titleField() => GoalsModalLabeledField(
    label: 'Title',
    child: CupertinoTextField(
      controller: _titleController,
      placeholder: 'e.g., Improve posture',
      onChanged: (_) => setState(() {}),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      style: AppTypography.body.copyWith(color: AppColors.textColor1),
      placeholderStyle: AppTypography.body.copyWith(
        color: AppColors.textColor4,
      ),
    ),
  );

  Widget _categoryField() => GoalsModalLabeledField(
    label: 'Category',
    child: SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: GoalCategory.values.map((cat) {
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.backgroundDepth3,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderDepth2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.textColor2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _priorityField() => GoalsModalLabeledField(
    label: 'Priority  (1 = highest)',
    child: Row(
      children: List.generate(5, (index) {
        final priority = index + 1;
        final isSelected = priority == _priority;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => setState(() => _priority = priority),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.backgroundDepth3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.borderDepth2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? CupertinoColors.white
                      : AppColors.textColor2,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _descriptionField() => GoalsModalLabeledField(
    label: 'Description (optional)',
    child: CupertinoTextField(
      controller: _descriptionController,
      placeholder: 'Why this goal matters to you…',
      padding: const EdgeInsets.all(AppSpacing.md),
      maxLines: 3,
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      style: AppTypography.body.copyWith(color: AppColors.textColor1),
      placeholderStyle: AppTypography.body.copyWith(
        color: AppColors.textColor4,
      ),
    ),
  );

  Widget _saveButton(BuildContext context, bool isEditing) =>
      CupertinoButton.filled(
        onPressed: _titleController.text.trim().isEmpty
            ? null
            : () async {
                final navigator = Navigator.of(context);
                try {
                  await widget.onSave(
                    _titleController.text.trim(),
                    _selectedCategory,
                    _descriptionController.text.trim(),
                    _priority,
                  );
                } finally {
                  if (navigator.canPop()) navigator.pop();
                }
              },
        child: Text(
          isEditing ? 'Save Changes' : 'Add Goal',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _cancelButton(BuildContext context) => CupertinoButton(
    onPressed: () => Navigator.of(context).pop(),
    child: Text('Cancel', style: TextStyle(color: AppColors.textColor3)),
  );
}
