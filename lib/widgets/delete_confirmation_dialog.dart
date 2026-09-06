import 'package:flutter/material.dart';

/// Shows a confirmation dialog for a destructive delete action.
///
/// Returns `true` if the user confirmed, `false` if they cancelled.
Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}
