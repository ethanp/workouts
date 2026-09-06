import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

enum SessionFinishAction() {
  cancel,
  save,
  discard,
}

class const SessionFinishSheet._() {
  static Future<SessionFinishAction?> show(BuildContext context) {
    return showModalBottomSheet<SessionFinishAction>(
      context: context,
      backgroundColor: EColors.backgroundLift,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceSm,
              ),
              child: Column(
                children: [
                  Text('Finish Session', style: EText.section),
                  const SizedBox(height: ELayout.spaceXs),
                  Text(
                    'Choose how to wrap up your workout.',
                    style: EText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Save Session'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(SessionFinishAction.save),
            ),
            ListTile(
              title: Text(
                'Discard Session',
                style: TextStyle(color: EColors.danger),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(SessionFinishAction.discard),
            ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(SessionFinishAction.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
