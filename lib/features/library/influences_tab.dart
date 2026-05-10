import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/features/library/influences_provider.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/error_bus.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class InfluencesTab extends ConsumerWidget {
  const InfluencesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final influencesAsync = ref.watch(influencesProvider);

    return influencesAsync.when(
      data: (influences) => influences.isEmpty
          ? const _EmptyView()
          : _InfluencesList(influences: influences),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load influences: $error',
          style: AppTypography.body,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No training influences available.',
          style: AppTypography.body.copyWith(color: AppColors.textColor3),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _InfluencesList extends StatelessWidget {
  const _InfluencesList({required this.influences});

  final List<TrainingInfluence> influences;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _explanationBanner(),
        ...influences.map((influence) => _InfluenceCard(influence: influence)),
      ],
    );
  }

  Widget _explanationBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.lightbulb, color: AppColors.textColor2, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Select coaches and philosophies to incorporate their '
              'training principles into your generated workouts.',
              style: AppTypography.body.copyWith(color: AppColors.textColor2),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfluenceCard extends ConsumerStatefulWidget {
  const _InfluenceCard({required this.influence});

  final TrainingInfluence influence;

  @override
  ConsumerState<_InfluenceCard> createState() => _InfluenceCardState();
}

class _InfluenceCardState extends ConsumerState<_InfluenceCard> {
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
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: AppSpacing.lg),
    child: const Icon(
      CupertinoIcons.trash,
      color: CupertinoColors.white,
      size: 22,
    ),
  );

  Widget _card(TrainingInfluence influence) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: influence.isActive
              ? AppColors.accentPrimary.withValues(alpha: 0.5)
              : AppColors.borderDepth1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(influence),
          _expandToggle(),
          if (_isExpanded) ...[
            Container(height: 1, color: AppColors.borderDepth1),
            _principlesList(influence.principles),
          ],
        ],
      ),
    );
  }

  Widget _header(TrainingInfluence influence) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleExpanded,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(influence.name, style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    influence.description,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            onPressed: () => _openEditSheet(context),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 20,
              color: AppColors.textColor3,
            ),
          ),
          CupertinoSwitch(
            value: influence.isActive,
            onChanged: _toggleInfluence,
            activeTrackColor: AppColors.accentPrimary,
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              _isExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 16,
              color: AppColors.textColor3,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _isExpanded ? 'Hide principles' : 'Show principles',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _principlesList(List<String> principles) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Principles',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textColor1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...principles.map(
            (principle) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: AppTypography.body.copyWith(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      principle,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textColor2,
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

class InfluenceFormSheet extends ConsumerStatefulWidget {
  const InfluenceFormSheet({super.key, this.existing});

  final TrainingInfluence? existing;

  @override
  ConsumerState<InfluenceFormSheet> createState() => _InfluenceFormSheetState();
}

class _InfluenceFormSheetState extends ConsumerState<InfluenceFormSheet> {
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
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(top: false, child: _sheetContent()),
    );
  }

  Widget _sheetContent() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _isEditing ? 'Edit Influence' : 'Add Influence',
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          _nameField(),
          const SizedBox(height: AppSpacing.lg),
          if (_hasFields) ...[
            _descriptionField(),
            const SizedBox(height: AppSpacing.lg),
            _principlesFields(),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_errorMessage != null) ...[
            _errorBanner(),
            const SizedBox(height: AppSpacing.lg),
          ],
          _actionButtons(),
          const SizedBox(height: AppSpacing.md),
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
        color: AppColors.borderDepth3,
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
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CupertinoTextField(
          controller: _nameController,
          placeholder: 'e.g., Pavel Tsatsouline, Starting Strength',
          onChanged: (_) => setState(() {}),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor4,
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
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CupertinoTextField(
          controller: _descriptionController,
          placeholder: 'One-sentence description',
          maxLines: 2,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor4,
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
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              onPressed: _addPrinciple,
              child: const Icon(
                CupertinoIcons.add_circled,
                size: 20,
                color: AppColors.accentPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...List.generate(_principleControllers.length, _principleRow),
      ],
    );
  }

  Widget _principleRow(int principleIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              '•',
              style: AppTypography.body.copyWith(
                color: AppColors.accentPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: CupertinoTextField(
              controller: _principleControllers[principleIndex],
              maxLines: null,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundDepth3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              style: AppTypography.body.copyWith(color: AppColors.textColor1),
              placeholderStyle: AppTypography.body.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            minimumSize: const Size(0, 0),
            onPressed: () => _removePrinciple(principleIndex),
            child: const Icon(
              CupertinoIcons.minus_circle,
              size: 18,
              color: AppColors.textColor4,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        _errorMessage!,
        style: AppTypography.body.copyWith(color: AppColors.error),
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
          CupertinoButton.filled(
            onPressed: canSave ? _save : null,
            child: Text(
              _isEditing ? 'Save' : 'Add Influence',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_hasFields) const SizedBox(height: AppSpacing.sm),
        CupertinoButton(
          color: _hasFields ? null : AppColors.accentPrimary,
          onPressed: canGenerate ? _generate : null,
          child: _generating
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.sparkles, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _hasFields ? 'Revise with AI' : 'Generate with AI',
                      style: TextStyle(
                        color: _hasFields
                            ? AppColors.accentPrimary
                            : CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return CupertinoButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel', style: TextStyle(color: AppColors.textColor3)),
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
