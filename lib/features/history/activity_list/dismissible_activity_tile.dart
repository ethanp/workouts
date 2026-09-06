import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const DismissibleActivityTile({
  required super.key,
  required final ActivityItem item,
  required final Future<void> Function() onDelete,
  required final Widget child,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = switch (item) {
      ActivityCardio() => const _DeletePrompt(
        title: 'Delete Workout',
        content:
            'This will remove the workout from this app. It will stay in Apple Health '
            'and may be re-imported if you run Import again.',
      ),
      ActivitySession() => const _DeletePrompt(
        title: 'Delete Session',
        content:
            'Are you sure you want to delete this workout session? '
            'This action cannot be undone.',
      ),
    };

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          _confirmDelete(context, prompt.title, prompt.content),
      background: _deleteBackground(),
      child: child,
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    String title,
    String content,
  ) async {
    final confirmed = await confirmDeleteDialog(
      context,
      title: title,
      content: content,
    );
    if (confirmed) await onDelete();
    return confirmed;
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.danger,
        borderRadius: BorderRadius.circular(ELayout.radiusXl),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 28),
          SizedBox(height: ELayout.spaceXs),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class const _DeletePrompt({
  required final String title,
  required final String content,
});
