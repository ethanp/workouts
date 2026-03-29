import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/providers/locations_provider.dart';
import 'package:workouts/services/llm_service.dart';
import 'package:workouts/services/repositories/locations_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/error_bus.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class LocationsTab extends ConsumerWidget {
  const LocationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);

    return locationsAsync.when(
      data: (locations) => locations.isEmpty
          ? const _EmptyView()
          : _LocationsList(locations: locations),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load locations: $error',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.location,
                size: 32,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('No Locations Yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your training locations so the AI knows what equipment is available.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationsList extends StatelessWidget {
  const _LocationsList({required this.locations});

  final List<TrainingLocation> locations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _explanationBanner(),
        ...locations.map(
          (location) => _LocationCard(location: location),
        ),
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
          Icon(
            CupertinoIcons.lightbulb,
            color: AppColors.textColor2,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Define where you train and what equipment is available. '
              'Select a location when generating workouts.',
              style: AppTypography.body.copyWith(color: AppColors.textColor2),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.location});

  final TrainingLocation location;

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
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(CupertinoIcons.trash,
            color: CupertinoColors.white, size: 22),
      );

  Widget _card(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Row(
        children: [
          _locationIcon(),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _cardContent()),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            onPressed: () => _openEditSheet(context),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 20,
              color: AppColors.textColor3,
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
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(
        CupertinoIcons.location,
        size: 18,
        color: AppColors.accentPrimary,
      ),
    );
  }

  Widget _cardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: AppTypography.body.copyWith(
            color: AppColors.textColor1,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (location.equipment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            location.equipment,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  void _openEditSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => LocationFormSheet(existing: location),
    );
  }
}

class LocationFormSheet extends ConsumerStatefulWidget {
  const LocationFormSheet({super.key, this.existing});

  final TrainingLocation? existing;

  @override
  ConsumerState<LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends ConsumerState<LocationFormSheet> {
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(top: false, child: _sheetContent()),
    );
  }

  Widget _sheetContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _isEditing ? 'Edit Location' : 'Add Location',
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          _nameField(),
          const SizedBox(height: AppSpacing.lg),
          _equipmentField(),
          const SizedBox(height: AppSpacing.lg),
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
          placeholder: 'e.g., Home Gym, Office, Park',
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

  Widget _equipmentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CupertinoTextField(
          controller: _equipmentController,
          placeholder: 'e.g., Kettlebells, pull-up bar, bands, foam roller',
          maxLines: 4,
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
    final hasName = _nameController.text.trim().isNotEmpty;
    final canGenerate = hasName && !_generating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoButton.filled(
          onPressed: hasName ? _save : null,
          child: Text(
            _isEditing ? 'Save' : 'Add Location',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CupertinoButton(
          onPressed: canGenerate ? _generate : null,
          child: _generating
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.sparkles, size: 16,
                        color: AppColors.accentPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _equipmentController.text.trim().isNotEmpty
                          ? 'Revise with AI'
                          : 'Generate with AI',
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
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
        currentEquipment:
            currentEquipment.isNotEmpty ? currentEquipment : null,
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
