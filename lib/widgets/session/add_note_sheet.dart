import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/providers/session_notes_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class AddNoteSheet extends ConsumerStatefulWidget {
  const AddNoteSheet({
    super.key,
    required this.sessionId,
    this.currentBlockId,
  });

  final String sessionId;
  final String? currentBlockId;

  @override
  ConsumerState<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<AddNoteSheet> {
  final _contentController = TextEditingController();
  SessionNoteType _selectedType = SessionNoteType.observation;
  String? _errorText;
  bool _isSaving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(),
              const SizedBox(height: AppSpacing.lg),
              if (_errorText != null) ...[
                _errorBanner(),
                const SizedBox(height: AppSpacing.md),
              ],
              _typeSelector(),
              const SizedBox(height: AppSpacing.md),
              CupertinoTextField(
                controller: _contentController,
                placeholder: 'What do you want to remember?',
                maxLines: 4,
                minLines: 2,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDepth2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDepth1),
                ),
                style: AppTypography.body,
                placeholderStyle: AppTypography.body.copyWith(
                  color: AppColors.textColor4,
                ),
                onChanged: (_) => setState(() => _errorText = null),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Text('Add Note', style: AppTypography.title),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed:
              _contentController.text.trim().isEmpty || _isSaving
              ? null
              : _saveNote,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _typeSelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: SessionNoteType.values.map((type) {
        final isSelected = type == _selectedType;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary.withValues(alpha: 0.2)
                  : AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.borderDepth1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  type.displayName,
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.textColor2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: CupertinoColors.destructiveRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: CupertinoColors.destructiveRed.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: CupertinoColors.destructiveRed,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorText!,
              style: AppTypography.caption.copyWith(
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNote() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(sessionNotesControllerProvider.notifier)
          .addNote(
            sessionId: widget.sessionId,
            content: content,
            noteType: _selectedType,
            blockId: widget.currentBlockId,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        final firstLine = error.toString().split('\n').first;
        final cleaned = firstLine.startsWith('Exception: ')
            ? firstLine.substring('Exception: '.length)
            : firstLine.startsWith('Error: ')
            ? firstLine.substring('Error: '.length)
            : firstLine;
        setState(() {
          _isSaving = false;
          _errorText = cleaned;
        });
      }
    }
  }
}
