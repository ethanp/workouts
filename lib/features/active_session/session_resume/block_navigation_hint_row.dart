import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const BlockNavigationHintRow({
  required final VoidCallback? onPrevious,
  required final VoidCallback? onNext,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'Swipe or tap arrows to navigate blocks',
        style: EText.caption.copyWith(color: EColors.textMuted),
      ),
      Row(
        children: [
          _navigationButton(
            icon: Icons.chevron_left,
            onPressed: onPrevious,
          ),
          _navigationButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
          ),
        ],
      ),
    ],
  );

  Widget _navigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(
      icon,
      color: onPressed == null ? EColors.textMuted : EColors.textSecondary,
      size: 20,
    ),
  );
}
