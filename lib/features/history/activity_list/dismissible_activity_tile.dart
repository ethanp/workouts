import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class DismissibleActivityTile extends ConsumerWidget {
  const DismissibleActivityTile({
    required super.key,
    required this.item,
    required this.onDelete,
    required this.child,
  });

  final ActivityItem item;
  final Future<void> Function() onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, content) = switch (item) {
      ActivityCardio() => (
        'Delete Workout',
        'This will remove the workout from this app. It will stay in Apple Health '
            'and may be re-imported if you run Import again.',
      ),
      ActivitySession() => (
        'Delete Session',
        'Are you sure you want to delete this workout session? '
            'This action cannot be undone.',
      ),
    };

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, title, content),
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
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: CupertinoColors.destructiveRed,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.delete, color: CupertinoColors.white, size: 28),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Delete',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
