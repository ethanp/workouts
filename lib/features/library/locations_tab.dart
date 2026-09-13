import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/features/library/locations_provider.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/services/repositories/locations_repository_powersync.dart';
import 'package:workouts/utils/error_bus.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const LocationsTab() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);

    return locationsAsync.when(
      data: (locations) => locations.isEmpty
          ? const _EmptyView()
          : _LocationsList(locations: locations),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load locations: $error',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 32,
                color: EColors.accent,
              ),
            ),
            const SizedBox(height: ELayout.spaceXl),
            Text('No Locations Yet', style: EText.title),
            const SizedBox(height: ELayout.spaceSm),
            Text(
              'Add your training locations so the AI knows what equipment is available.',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class const _LocationsList({required final List<TrainingLocation> locations})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg).withOverlaidTabBar(context),
      children: [
        _explanationBanner(),
        ...locations.map((location) => _LocationCard(location: location)),
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
              'Define where you train and what equipment is available. '
              'Select a location when generating workouts.',
              style: EText.body.medium.copyWith(color: EColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class const _LocationCard({required final TrainingLocation location})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(location.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => ref
          .read(locationsRepositoryPowerSyncProvider)
          .deleteLocation(location.id),
      background: _deleteBackground(),
      child: _card(context),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) => confirmDeleteDialog(
    context,
    title: 'Delete Location?',
    content: '"${location.name}" will be permanently deleted.',
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

  Widget _card(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Row(
        children: [
          _locationIcon(),
          const SizedBox(width: ELayout.spaceMd),
          Expanded(child: _cardContent()),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openEditSheet(context),
            icon: const Icon(
              Icons.edit,
              size: 20,
              color: EColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: EColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: const Icon(
        Icons.location_on_outlined,
        size: 18,
        color: EColors.accent,
      ),
    );
  }

  Widget _cardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: EText.body.medium.copyWith(
            color: EColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (location.equipment.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            location.equipment,
            style: EText.caption.copyWith(color: EColors.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => LocationFormSheet(existing: location),
    );
  }
}

class const LocationFormSheet({final TrainingLocation? existing})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState() extends ConsumerState<LocationFormSheet> {
  final _nameController = TextEditingController();
  final _equipmentController = TextEditingController();
  bool _generating = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _equipmentController.text = widget.existing!.equipment;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _equipmentController.dispose();
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
            _isEditing ? 'Edit Location' : 'Add Location',
            style: EText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ELayout.spaceXl),
          _nameField(),
          const SizedBox(height: ELayout.spaceLg),
          _equipmentField(),
          const SizedBox(height: ELayout.spaceLg),
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
            hintText: 'e.g., Home Gym, Office, Park',
          ),
        ),
      ],
    );
  }

  Widget _equipmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment',
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
        TextField(
          controller: _equipmentController,
          maxLines: 4,
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g., Kettlebells, pull-up bar, bands, foam roller',
          ),
        ),
      ],
    );
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
    final hasName = _nameController.text.trim().isNotEmpty;
    final canGenerate = hasName && !_generating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: hasName ? _save : null,
          child: Text(_isEditing ? 'Save' : 'Add Location'),
        ),
        ConnectionGatedWidget(
          child: Padding(
            padding: const EdgeInsets.only(top: ELayout.spaceSm),
            child: TextButton(
              onPressed: canGenerate ? _generate : null,
              child: _generating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: EColors.accent,
                        ),
                        const SizedBox(width: ELayout.spaceXs),
                        Text(
                          _equipmentController.text.trim().isNotEmpty
                              ? 'Revise with AI'
                              : 'Generate with AI',
                          style: const TextStyle(
                            color: EColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cancelButton() {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel', style: TextStyle(color: EColors.textTertiary)),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final llm = ref.read(llmServiceProvider);
      final currentEquipment = _equipmentController.text.trim();
      final equipment = await llm.generateLocationEquipment(
        locationName: _nameController.text.trim(),
        currentEquipment: currentEquipment.isNotEmpty ? currentEquipment : null,
      );
      if (!mounted) return;
      setState(() {
        _equipmentController.text = equipment;
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
    final locationId = widget.existing?.id ?? const Uuid().v4();
    final location = TrainingLocation(
      id: locationId,
      name: _nameController.text.trim(),
      equipment: _equipmentController.text.trim(),
    );

    try {
      final repository = ref.read(locationsRepositoryPowerSyncProvider);
      if (_isEditing) {
        await repository.updateLocation(location);
      } else {
        await repository.addLocation(location);
      }
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      errorBus.add('Save location: $error');
    }
  }
}
