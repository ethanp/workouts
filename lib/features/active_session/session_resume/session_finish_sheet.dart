import 'package:flutter/cupertino.dart';

enum SessionFinishAction { cancel, save, discard }

class SessionFinishSheet {
  const SessionFinishSheet._();

  static Future<SessionFinishAction?> show(BuildContext context) {
    return showCupertinoModalPopup<SessionFinishAction>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Finish Session'),
        message: const Text('Choose how to wrap up your workout.'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(SessionFinishAction.save),
            child: const Text('Save Session'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(SessionFinishAction.discard),
            child: const Text('Discard Session'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(popupContext).pop(SessionFinishAction.cancel),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
