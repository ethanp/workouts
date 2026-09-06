import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/features/active_session/session_notes_provider.dart';

class const AddNoteSheet({
  required final String sessionId,
  final String? currentBlockId,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState() extends ConsumerState<AddNoteSheet> {
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
        color: EColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ELayout.radiusXl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(ELayout.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(),
              const SizedBox(height: ELayout.spaceLg),
              if (_errorText != null) ...[
                _errorBanner(),
                const SizedBox(height: ELayout.spaceMd),
              ],
              _typeSelector(),
              const SizedBox(height: ELayout.spaceMd),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'What do you want to remember?',
                ),
                maxLines: 4,
                minLines: 2,
                onChanged: (_) => setState(() => _errorText = null),
              ),
              const SizedBox(height: ELayout.spaceLg),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Text('Add Note', style: EText.title),
        TextButton(
          onPressed: _contentController.text.trim().isEmpty || _isSaving
              ? null
              : _saveNote,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _typeSelector() {
    return Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceSm,
      children: SessionNoteType.values.map((type) {
        final isSelected = type == _selectedType;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceMd,
              vertical: ELayout.spaceSm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? EColors.accent.withValues(alpha: 0.2)
                  : EColors.backgroundLift,
              borderRadius: BorderRadius.circular(ELayout.radiusSm),
              border: Border.all(
                color: isSelected
                    ? EColors.accent
                    : EColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: ELayout.spaceXs),
                Text(
                  type.displayName,
                  style: EText.body.medium.copyWith(
                    color: isSelected
                        ? EColors.accent
                        : EColors.textSecondary,
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
      padding: const EdgeInsets.all(ELayout.spaceSm),
      decoration: BoxDecoration(
        color: EColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(
          color: EColors.danger.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning,
            size: 16,
            color: EColors.danger,
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Text(
              _errorText!,
              style: EText.caption.copyWith(
                color: EColors.danger,
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
