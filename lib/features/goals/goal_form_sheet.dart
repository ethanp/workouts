import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/goals/goals_modal_labeled_field.dart';
import 'package:workouts/models/fitness_goal.dart';

class const GoalFormSheet({
  final FitnessGoal? initialGoal,
  required final Future<void> Function(
    String title,
    GoalCategory category,
    String description,
    int priority,
  )
  onSave,
}) extends StatefulWidget {
  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState() extends State<GoalFormSheet> {
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
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ELayout.radiusXl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(ELayout.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: ELayout.spaceLg),
              _sheetTitle(isEditing),
              const SizedBox(height: ELayout.spaceXl),
              _titleField(),
              const SizedBox(height: ELayout.spaceLg),
              _categoryField(),
              const SizedBox(height: ELayout.spaceLg),
              _priorityField(),
              const SizedBox(height: ELayout.spaceLg),
              _descriptionField(),
              const SizedBox(height: ELayout.spaceXl),
              _saveButton(context, isEditing),
              const SizedBox(height: ELayout.spaceMd),
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
        color: EColors.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _sheetTitle(bool isEditing) => Text(
    isEditing ? 'Edit Goal' : 'New Goal',
    style: EText.title,
    textAlign: TextAlign.center,
  );

  Widget _titleField() => GoalsModalLabeledField(
    label: 'Title',
    child: TextField(
      controller: _titleController,
      decoration: const InputDecoration(hintText: 'e.g., Improve posture'),
      onChanged: (_) => setState(() {}),
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
            padding: const EdgeInsets.only(right: ELayout.spaceSm),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceMd),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EColors.accent
                      : EColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? EColors.accent
                        : EColors.borderStrong,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white
                        : EColors.textSecondary,
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
          padding: const EdgeInsets.only(right: ELayout.spaceSm),
          child: GestureDetector(
            onTap: () => setState(() => _priority = priority),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? EColors.accent
                    : EColors.surface,
                borderRadius: BorderRadius.circular(ELayout.radiusSm),
                border: Border.all(
                  color: isSelected
                      ? EColors.accent
                      : EColors.borderStrong,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : EColors.textSecondary,
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
    child: TextField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        hintText: 'Why this goal matters to you…',
      ),
      maxLines: 3,
    ),
  );

  Widget _saveButton(BuildContext context, bool isEditing) =>
      FilledButton(
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
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _cancelButton(BuildContext context) => TextButton(
    onPressed: () => Navigator.of(context).pop(),
    child: Text('Cancel', style: TextStyle(color: EColors.textTertiary)),
  );
}
