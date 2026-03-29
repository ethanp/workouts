import 'package:flutter/cupertino.dart';

/// Shows a Cupertino confirmation dialog for a destructive delete action.
///
/// Returns `true` if the user confirmed, `false` if they cancelled.
Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  return await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}
