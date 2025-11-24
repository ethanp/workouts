import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/local_database.dart';
import 'package:workouts/services/repositories/template_repository.dart';

part 'template_version_provider.g.dart';

@riverpod
class TemplateVersionController extends _$TemplateVersionController {
  @override
  Future<TemplateVersionStatus> build() async {
    final db = ref.watch(localDatabaseProvider);
    final rows = await db.readTemplates();
    final currentVersion = TemplateRepository.currentTemplateVersion;

    if (rows.isEmpty) {
      return TemplateVersionStatus(
        current: currentVersion,
        installed: null,
        needsUpdate: true,
      );
    }

    final minVersion = rows.map((r) => r.version).reduce((a, b) => a < b ? a : b);
    return TemplateVersionStatus(
      current: currentVersion,
      installed: minVersion,
      needsUpdate: minVersion < currentVersion,
    );
  }

  Future<void> reseed() async {
    state = const AsyncValue.loading();
    final repository = ref.read(templateRepositoryProvider);
    final db = ref.read(localDatabaseProvider);
    await db.delete(db.workoutTemplatesTable).go();
    await repository.fetchTemplates();
    ref.invalidateSelf();
  }
}

class TemplateVersionStatus {
  const TemplateVersionStatus({
    required this.current,
    required this.installed,
    required this.needsUpdate,
  });

  final int current;
  final int? installed;
  final bool needsUpdate;
}

