import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

/// The shared sync connection panel on a settings card.
class const ConnectionTile() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const ESettingsCard(child: ESyncConnectionPanel());
  }
}
