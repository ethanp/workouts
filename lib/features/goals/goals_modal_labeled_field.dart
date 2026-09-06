import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const GoalsModalLabeledField({
  required final String label,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
        child,
      ],
    );
  }
}
