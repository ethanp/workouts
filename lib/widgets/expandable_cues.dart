import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const ExpandableCues({
  required final List<String> cues,
  final bool isInitiallyExpanded = true,
}) extends StatefulWidget {
  @override
  State<ExpandableCues> createState() => _ExpandableCuesState();
}

class _ExpandableCuesState() extends State<ExpandableCues> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleButton(),
        if (_isExpanded) ...[
          const SizedBox(height: ELayout.spaceXs),
          ..._cueItems(),
        ],
      ],
    );
  }

  Widget _toggleButton() => InkWell(
    onTap: () => setState(() => _isExpanded = !_isExpanded),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isExpanded ? Icons.expand_more : Icons.chevron_right,
          size: 16,
          color: EColors.textTertiary,
        ),
        const SizedBox(width: ELayout.spaceXs),
        Text(
          _isExpanded ? 'Form Cues' : 'Form Cues (${widget.cues.length})',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  List<Widget> _cueItems() => widget.cues
      .map(
        (cue) => Padding(
          padding: const EdgeInsets.only(
            bottom: ELayout.spaceXs,
            left: ELayout.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: EColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: ELayout.spaceSm),
              Expanded(
                child: Text(
                  cue,
                  style: EText.body.medium.copyWith(
                    color: EColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      .toList();
}
