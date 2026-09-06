import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/features/goals/goals_modal_labeled_field.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';

class const NoteFormSheet({
  required final List<FitnessGoal> availableGoals,
  final BackgroundNote? initialNote,
  required final void Function(
    String content,
    NoteCategory category,
    String? goalId,
  )
  onSave,
}) extends StatefulWidget {
  @override
  State<NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState() extends State<NoteFormSheet> {
  late final TextEditingController _contentController;
  late NoteCategory _selectedCategory;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.initialNote?.content ?? '',
    );
    _selectedCategory = widget.initialNote?.category ?? NoteCategory.preference;
    _selectedGoalId = widget.initialNote?.goalId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialNote != null;
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
              _sheetHeader(isEditing),
              const SizedBox(height: ELayout.spaceXl),
              _contentField(),
              const SizedBox(height: ELayout.spaceLg),
              _categoryField(),
              if (widget.availableGoals.isNotEmpty) ...[
                const SizedBox(height: ELayout.spaceLg),
                _goalLinkField(),
              ],
              const SizedBox(height: ELayout.spaceXl),
              _saveButton(isEditing),
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

  Widget _sheetHeader(bool isEditing) => Column(
    children: [
      Text(
        isEditing ? 'Edit Note' : 'New Background Note',
        style: EText.title,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: ELayout.spaceSm),
      Text(
        'Add context about your body, preferences, or constraints.',
        style: EText.caption.copyWith(color: EColors.textMuted),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _contentField() => GoalsModalLabeledField(
    label: 'Note',
    child: TextField(
      controller: _contentController,
      decoration: const InputDecoration(
        hintText: 'e.g., Lower back sensitivity — avoid heavy axial loading',
      ),
      maxLines: 4,
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _categoryField() => GoalsModalLabeledField(
    label: 'Category',
    child: Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceSm,
      children: NoteCategory.values.mapL(_categoryChip),
    ),
  );

  Widget _categoryChip(NoteCategory cat) {
    final isSelected = cat == _selectedCategory;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceSm,
        ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: ELayout.spaceXs),
            Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : EColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalLinkField() => GoalsModalLabeledField(
    label: 'Link to Goal (optional)',
    child: Column(
      children: [
        _goalOption(
          id: null,
          label: 'General (all goals)',
          icon: Icons.public,
        ),
        const SizedBox(height: ELayout.spaceSm),
        ...widget.availableGoals
            .where((goal) => goal.isActive)
            .map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
                child: _goalOption(
                  id: goal.id,
                  label: goal.title,
                  icon: Icons.flag,
                ),
              ),
            ),
      ],
    ),
  );

  Widget _goalOption({
    required String? id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedGoalId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoalId = id),
      child: Container(
        padding: const EdgeInsets.all(ELayout.spaceMd),
        decoration: BoxDecoration(
          color: isSelected
              ? EColors.accent.withValues(alpha: 0.12)
              : EColors.surface,
          borderRadius: BorderRadius.circular(ELayout.radiusSm),
          border: Border.all(
            color: isSelected
                ? EColors.accent
                : EColors.borderStrong,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? EColors.accent
                  : EColors.textTertiary,
            ),
            const SizedBox(width: ELayout.spaceSm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? EColors.accent
                      : EColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(bool isEditing) => FilledButton(
    onPressed: _contentController.text.trim().isEmpty
        ? null
        : () => widget.onSave(
            _contentController.text.trim(),
            _selectedCategory,
            _selectedGoalId,
          ),
    child: Text(
      isEditing ? 'Save Changes' : 'Add Note',
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
