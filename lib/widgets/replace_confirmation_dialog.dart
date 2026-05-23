import 'package:flutter/cupertino.dart';

/// Confirms a destructive in-session exercise replacement when logged sets
/// would be discarded. Returns `true` if the user confirms, `false` otherwise.
///
/// [affectedBlockCount] is the number of round-blocks the replacement
/// touches; the message clarifies the cross-round impact when relevant.
Future<bool> confirmReplaceWithLogs(
  BuildContext context, {
  required int loggedSetCount,
  required int affectedBlockCount,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('Replace exercise?'),
      content: Text(_message(loggedSetCount, affectedBlockCount)),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String _message(int loggedSetCount, int affectedBlockCount) {
  final setLabel = loggedSetCount == 1 ? 'set' : 'sets';
  if (affectedBlockCount <= 1) {
    return 'Replacing will discard $loggedSetCount logged $setLabel.';
  }
  final roundLabel = affectedBlockCount == 1 ? 'round' : 'rounds';
  return 'Replacing will discard $loggedSetCount logged $setLabel '
      'across $affectedBlockCount $roundLabel.';
}
