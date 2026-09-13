import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/error_bus.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

import 'influence_form_sheet.dart';

class const InfluenceCard({required final TrainingInfluence influence})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<InfluenceCard> createState() => _InfluenceCardState();
}

class _InfluenceCardState() extends ConsumerState<InfluenceCard> {
  bool _isExpanded = false;

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final influence = widget.influence;

    return Dismissible(
      key: ValueKey(influence.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => ref
          .read(influencesRepositoryPowerSyncProvider)
          .deleteInfluence(influence.id),
      background: _deleteBackground(),
      child: _card(influence),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) => confirmDeleteDialog(
    context,
    title: 'Delete Influence?',
    content: '"${widget.influence.name}" will be permanently deleted.',
  );

  Widget _deleteBackground() => Container(
    margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
    decoration: BoxDecoration(
      color: EColors.danger,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: ELayout.spaceLg),
    child: const Icon(
      Icons.delete,
      color: Colors.white,
      size: 22,
    ),
  );

  Widget _card(TrainingInfluence influence) {
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(
          color: influence.isActive
              ? EColors.accent.withValues(alpha: 0.5)
              : EColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(influence),
          _expandToggle(),
          if (_isExpanded) ...[
            Container(height: 1, color: EColors.border),
            _principlesList(influence.principles),
          ],
        ],
      ),
    );
  }

  Widget _header(TrainingInfluence influence) {
    return Padding(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleExpanded,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(influence.name, style: EText.section),
                  const SizedBox(height: ELayout.spaceXs),
                  Text(
                    influence.description,
                    style: EText.body.medium.copyWith(
                      color: EColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openEditSheet(context),
            icon: const Icon(
              Icons.edit,
              size: 20,
              color: EColors.textTertiary,
            ),
          ),
          Switch(
            value: influence.isActive,
            onChanged: _toggleInfluence,
            activeTrackColor: EColors.accent,
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => InfluenceFormSheet(existing: widget.influence),
    );
  }

  Widget _expandToggle() {
    return GestureDetector(
      onTap: _toggleExpanded,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceSm,
        ),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: EColors.textTertiary,
            ),
            const SizedBox(width: ELayout.spaceXs),
            Text(
              _isExpanded ? 'Hide principles' : 'Show principles',
              style: EText.caption.copyWith(
                color: EColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _principlesList(List<String> principles) {
    return Padding(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Principles',
            style: EText.body.medium.copyWith(
              fontWeight: FontWeight.bold,
              color: EColors.textPrimary,
            ),
          ),
          const SizedBox(height: ELayout.spaceSm),
          ...principles.map(
            (principle) => Padding(
              padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: EText.body.medium.copyWith(
                      color: EColors.accent,
                    ),
                  ),
                  const SizedBox(width: ELayout.spaceSm),
                  Expanded(
                    child: Text(
                      principle,
                      style: EText.body.medium.copyWith(
                        color: EColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleInfluence(bool isActive) async {
    try {
      await ref
          .read(influencesRepositoryPowerSyncProvider)
          .toggleInfluence(widget.influence.id, isActive);
    } catch (error) {
      errorBus.add('Toggle influence ${widget.influence.name}: $error');
    }
  }
}
