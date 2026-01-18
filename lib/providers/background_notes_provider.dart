import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/services/repositories/background_notes_repository_powersync.dart';

part 'background_notes_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<BackgroundNote>> backgroundNotesStream(Ref ref) {
  final repo = ref.watch(backgroundNotesRepositoryPowerSyncProvider);
  return repo.watchNotes();
}

@riverpod
Stream<List<BackgroundNote>> activeBackgroundNotesStream(Ref ref) {
  final repo = ref.watch(backgroundNotesRepositoryPowerSyncProvider);
  return repo.watchActiveNotes();
}

@riverpod
Stream<List<BackgroundNote>> notesForGoalStream(Ref ref, String goalId) {
  final repo = ref.watch(backgroundNotesRepositoryPowerSyncProvider);
  return repo.watchNotesForGoal(goalId);
}

@riverpod
class BackgroundNotesController extends _$BackgroundNotesController {
  @override
  FutureOr<void> build() {}

  Future<void> addNote({
    required String content,
    required NoteCategory category,
    String? goalId,
  }) async {
    final repo = ref.read(backgroundNotesRepositoryPowerSyncProvider);
    final note = BackgroundNote(
      id: _uuid.v4(),
      content: content,
      category: category,
      goalId: goalId,
      isActive: true,
      source: NoteSource.user,
      createdAt: DateTime.now(),
    );
    await repo.saveNote(note);
    ref.invalidate(backgroundNotesStreamProvider);
    ref.invalidate(activeBackgroundNotesStreamProvider);
  }

  Future<void> updateNote(BackgroundNote note) async {
    final repo = ref.read(backgroundNotesRepositoryPowerSyncProvider);
    await repo.saveNote(note.copyWith(updatedAt: DateTime.now()));
    ref.invalidate(backgroundNotesStreamProvider);
    ref.invalidate(activeBackgroundNotesStreamProvider);
  }

  Future<void> archiveNote(String noteId) async {
    final repo = ref.read(backgroundNotesRepositoryPowerSyncProvider);
    await repo.archiveNote(noteId);
    ref.invalidate(backgroundNotesStreamProvider);
    ref.invalidate(activeBackgroundNotesStreamProvider);
  }

  Future<void> activateNote(String noteId) async {
    final repo = ref.read(backgroundNotesRepositoryPowerSyncProvider);
    await repo.activateNote(noteId);
    ref.invalidate(backgroundNotesStreamProvider);
    ref.invalidate(activeBackgroundNotesStreamProvider);
  }

  Future<void> deleteNote(String noteId) async {
    final repo = ref.read(backgroundNotesRepositoryPowerSyncProvider);
    await repo.deleteNote(noteId);
    ref.invalidate(backgroundNotesStreamProvider);
    ref.invalidate(activeBackgroundNotesStreamProvider);
  }
}
