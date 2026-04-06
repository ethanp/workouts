import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:workouts/features/goals/goals_modal_labeled_field.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/theme/app_theme.dart';

class NoteFormSheet extends StatefulWidget {
  const NoteFormSheet({
    super.key,
    required this.availableGoals,
    this.initialNote,
    required this.onSave,
  });

  final List<FitnessGoal> availableGoals;
  final BackgroundNote? initialNote;
  final void Function(String content, NoteCategory category, String? goalId)
      onSave;

  @override
  State<NoteFormSheet> createState() => _NoteFormSheetState();
}

class _NoteFormSheetState extends State<NoteFormSheet> {
  late final TextEditingController _contentController;
  late NoteCategory _selectedCategory;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.initialNote?.content ?? '',
    );
    _selectedCategory =
        widget.initialNote?.category ?? NoteCategory.preference;
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
        color: AppColors.backgroundDepth2,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: AppSpacing.lg),
              _sheetHeader(isEditing),
              const SizedBox(height: AppSpacing.xl),
              _contentField(),
              const SizedBox(height: AppSpacing.lg),
              _categoryField(),
              if (widget.availableGoals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _goalLinkField(),
              ],
              const SizedBox(height: AppSpacing.xl),
              _saveButton(isEditing),
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

  Widget _sheetHeader(bool isEditing) => Column(
        children: [
          Text(
            isEditing ? 'Edit Note' : 'New Background Note',
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add context about your body, preferences, or constraints.',
            style:
                AppTypography.caption.copyWith(color: AppColors.textColor4),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _contentField() => GoalsModalLabeledField(
        label: 'Note',
        child: CupertinoTextField(
          controller: _contentController,
          placeholder:
              'e.g., Lower back sensitivity — avoid heavy axial loading',
          padding: const EdgeInsets.all(AppSpacing.md),
          maxLines: 4,
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle:
              AppTypography.body.copyWith(color: AppColors.textColor4),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _categoryField() => GoalsModalLabeledField(
        label: 'Category',
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: NoteCategory.values.mapL(_categoryChip),
        ),
      );

  Widget _categoryChip(NoteCategory cat) {
    final isSelected = cat == _selectedCategory;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? CupertinoColors.white
                    : AppColors.textColor2,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
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
                icon: CupertinoIcons.globe),
            const SizedBox(height: AppSpacing.sm),
            ...widget.availableGoals
                .where((goal) => goal.status == GoalStatus.active)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _goalOption(
                      id: goal.id,
                      label: goal.title,
                      icon: CupertinoIcons.flag_fill,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.12)
              : AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDepth2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textColor3,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.textColor2,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(bool isEditing) => CupertinoButton.filled(
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
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _cancelButton(BuildContext context) => CupertinoButton(
        onPressed: () => Navigator.of(context).pop(),
        child:
            Text('Cancel', style: TextStyle(color: AppColors.textColor3)),
      );
}
