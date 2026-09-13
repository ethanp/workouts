import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const CardioDetailCard({required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: child,
    );
  }
}
