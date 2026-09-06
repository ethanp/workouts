import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const KeyboardEnterAccessory({
  required final VoidCallback onKeyboardDismissRequested,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        border: Border(top: BorderSide(color: EColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: onKeyboardDismissRequested,
                child: Text(
                  'Enter',
                  style: EText.section.copyWith(color: EColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
