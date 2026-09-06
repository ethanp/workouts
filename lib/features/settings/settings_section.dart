import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

/// A section of the settings screen with a header label and stacked tiles.
///
/// Tiles are spaced with [ELayout.spaceMd] between each other and the section
/// itself is padded with [ELayout.spaceLg] below the header for breathing room.
class const SettingsSection({
  required final String title,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: ELayout.spaceSm,
            bottom: ELayout.spaceSm,
          ),
          child: Text(
            title.toUpperCase(),
            style: EText.caption.copyWith(
              color: EColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (
          var childIndex = 0;
          childIndex < children.length;
          childIndex++
        ) ...[
          children[childIndex],
          if (childIndex < children.length - 1)
            const SizedBox(height: ELayout.spaceMd),
        ],
      ],
    );
  }
}
