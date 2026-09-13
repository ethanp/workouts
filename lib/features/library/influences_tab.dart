import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/features/library/influences_provider.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/utils/error_bus.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const InfluencesTab() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final influencesAsync = ref.watch(influencesProvider);

    return influencesAsync.when(
      data: (influences) => influences.isEmpty
          ? const _EmptyView()
          : _InfluencesList(influences: influences),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load influences: $error',
          style: EText.body.medium,
        ),
      ),
    );
  }
}

class const _EmptyView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Text(
          'No training influences available.',
          style: EText.body.medium.copyWith(color: EColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class const _InfluencesList({required final List<TrainingInfluence> influences})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg).withOverlaidTabBar(context),
      children: [
        _explanationBanner(),
        ...influences.map((influence) => _InfluenceCard(influence: influence)),
      ],
    );
  }

  Widget _explanationBanner() {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      margin: const EdgeInsets.only(bottom: ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: EColors.textSecondary, size: 20),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Text(
              'Select coaches and philosophies to incorporate their '
              'training principles into your generated workouts.',
              style: EText.body.medium.copyWith(color: EColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class const _InfluenceCard({required final TrainingInfluence influence})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<_InfluenceCard> createState() => _InfluenceCardState();
}

class _InfluenceCardState() extends ConsumerState<_InfluenceCard> {
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
              _isExpanded
                  ? Icons.expand_less
                  : Icons.expand_more,
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

class const InfluenceFormSheet({final TrainingInfluence? existing})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<InfluenceFormSheet> createState() => _InfluenceFormSheetState();
}

class _InfluenceFormSheetState() extends ConsumerState<InfluenceFormSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _principleControllers = <TextEditingController>[];
  bool _generating = false;
  bool _hasFields = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _descriptionController.text = widget.existing!.description;
      _populatePrinciples(widget.existing!.principles);
      _hasFields = true;
    }
  }

  void _populatePrinciples(List<String> principles) {
    for (final controller in _principleControllers) {
      controller.dispose();
    }
    _principleControllers.clear();
    for (final principle in principles) {
      _principleControllers.add(TextEditingController(text: principle));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final controller in _principleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ELayout.radiusXl)),
      ),
      child: SafeArea(top: false, child: _sheetContent()),
    );
  }

  Widget _sheetContent() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(ELayout.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: ELayout.spaceLg),
          Text(
            _isEditing ? 'Edit Influence' : 'Add Influence',
            style: EText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ELayout.spaceXl),
          _nameField(),
          const SizedBox(height: ELayout.spaceLg),
          if (_hasFields) ...[
            _descriptionField(),
            const SizedBox(height: ELayout.spaceLg),
            _principlesFields(),
            const SizedBox(height: ELayout.spaceLg),
          ],
          if (_errorMessage != null) ...[
            _errorBanner(),
            const SizedBox(height: ELayout.spaceLg),
          ],
          _actionButtons(),
          const SizedBox(height: ELayout.spaceMd),
          _cancelButton(),
        ],
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: EColors.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g., Pavel Tsatsouline, Starting Strength',
          ),
        ),
      ],
    );
  }

  Widget _descriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
        TextField(
          controller: _descriptionController,
          maxLines: 2,
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'One-sentence description',
          ),
        ),
      ],
    );
  }

  Widget _principlesFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Key Principles',
              style: EText.caption.copyWith(
                color: EColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Add principle',
              onPressed: _addPrinciple,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.add_circle_outline,
                size: 20,
                color: EColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: ELayout.spaceSm),
        ...List.generate(_principleControllers.length, _principleRow),
      ],
    );
  }

  Widget _principleRow(int principleIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: ELayout.spaceMd),
            child: Text(
              '•',
              style: EText.body.medium.copyWith(
                color: EColors.accent,
              ),
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: TextField(
              controller: _principleControllers[principleIndex],
              maxLines: null,
              style: EText.body.medium.copyWith(color: EColors.textPrimary),
              decoration: const InputDecoration(),
            ),
          ),
          IconButton(
            tooltip: 'Remove principle',
            onPressed: () => _removePrinciple(principleIndex),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: EColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _addPrinciple() {
    setState(() {
      _principleControllers.add(TextEditingController());
    });
  }

  void _removePrinciple(int principleIndex) {
    setState(() {
      _principleControllers[principleIndex].dispose();
      _principleControllers.removeAt(principleIndex);
    });
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
      ),
      child: Text(
        _errorMessage!,
        style: EText.body.medium.copyWith(color: EColors.danger),
      ),
    );
  }

  Widget _actionButtons() {
    final canGenerate = _nameController.text.trim().isNotEmpty && !_generating;
    final canSave =
        _hasFields &&
        _nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasFields)
          FilledButton(
            onPressed: canSave ? _save : null,
            child: Text(_isEditing ? 'Save' : 'Add Influence'),
          ),
        if (_hasFields) const SizedBox(height: ELayout.spaceSm),
        ConnectionGatedWidget(
          child: _hasFields
              ? TextButton(
                  onPressed: canGenerate ? _generate : null,
                  child: _generateButtonChild(),
                )
              : FilledButton(
                  onPressed: canGenerate ? _generate : null,
                  child: _generateButtonChild(),
                ),
        ),
      ],
    );
  }

  Widget _generateButtonChild() {
    if (_generating) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, size: 16),
        const SizedBox(width: ELayout.spaceXs),
        Text(_hasFields ? 'Revise with AI' : 'Generate with AI'),
      ],
    );
  }

  Widget _cancelButton() {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel', style: TextStyle(color: EColors.textTertiary)),
    );
  }

  List<String> get _currentPrinciples => _principleControllers
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final llm = ref.read(llmServiceProvider);
      final influenceId = widget.existing?.id ?? const Uuid().v4();
      final description = _descriptionController.text.trim();
      final principles = _currentPrinciples;

      final influence = await llm.generateInfluenceDetails(
        id: influenceId,
        name: _nameController.text.trim(),
        currentDescription: description.isNotEmpty ? description : null,
        currentPrinciples: principles.isNotEmpty ? principles : null,
      );
      if (!mounted) return;
      setState(() {
        _descriptionController.text = influence.description;
        _populatePrinciples(influence.principles);
        _hasFields = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final influenceId = widget.existing?.id ?? const Uuid().v4();
    final influence = TrainingInfluence(
      id: influenceId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      principles: _currentPrinciples,
      isActive: widget.existing?.isActive ?? true,
    );

    try {
      final repository = ref.read(influencesRepositoryPowerSyncProvider);
      if (_isEditing) {
        await repository.updateInfluence(influence);
      } else {
        await repository.addInfluence(influence);
      }
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      errorBus.add('Save influence: $error');
    }
  }
}
