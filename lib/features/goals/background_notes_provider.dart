import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/background_note.dart';
import 'package:workouts/services/repositories/background_notes_repository_powersync.dart';

part 'background_notes_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<BackgroundNote>> backgroundNotesStream(Ref ref) {
  final backgroundNotesRepository = ref.watch(
    backgroundNotesRepositoryPowerSyncProvider,
  );
  return backgroundNotesRepository.watchNotes();
}

@riverpod
Stream<List<BackgroundNote>> activeBackgroundNotesStream(Ref ref) {
  final backgroundNotesRepository = ref.watch(
    backgroundNotesRepositoryPowerSyncProvider,
  );
  return backgroundNotesRepository.watchActiveNotes();
}

@riverpod
Stream<List<BackgroundNote>> notesForGoalStream(Ref ref, String goalId) {
  final backgroundNotesRepository = ref.watch(
    backgroundNotesRepositoryPowerSyncProvider,
  );
  return backgroundNotesRepository.watchNotesForGoal(goalId);
}

@riverpod
class BackgroundNotesController extends _$BackgroundNotesController {
  @override
  FutureOr<void> build() {}

  void _invalidateNotesStreamsIfMounted() {
    if (ref.mounted) {
      ref.invalidate(backgroundNotesStreamProvider);
      ref.invalidate(activeBackgroundNotesStreamProvider);
    }
  }

  Future<void> addNote({
    required String content,
    required NoteCategory category,
    String? goalId,
  }) async {
    final backgroundNotesRepository = ref.read(
      backgroundNotesRepositoryPowerSyncProvider,
    );
    final note = BackgroundNote(
      id: _uuid.v4(),
      content: content,
      category: category,
      goalId: goalId,
      isActive: true,
      source: NoteSource.user,
      createdAt: DateTime.now(),
    );
    await backgroundNotesRepository.saveNote(note);
    _invalidateNotesStreamsIfMounted();
  }

  Future<void> updateNote(BackgroundNote note) async {
    final backgroundNotesRepository = ref.read(
      backgroundNotesRepositoryPowerSyncProvider,
    );
    await backgroundNotesRepository.saveNote(
      note.copyWith(updatedAt: DateTime.now()),
    );
    _invalidateNotesStreamsIfMounted();
  }

  Future<void> archiveNote(String noteId) async {
    final backgroundNotesRepository = ref.read(
      backgroundNotesRepositoryPowerSyncProvider,
    );
    await backgroundNotesRepository.archiveNote(noteId);
    _invalidateNotesStreamsIfMounted();
  }

  Future<void> activateNote(String noteId) async {
    final backgroundNotesRepository = ref.read(
      backgroundNotesRepositoryPowerSyncProvider,
    );
    await backgroundNotesRepository.activateNote(noteId);
    _invalidateNotesStreamsIfMounted();
  }

  Future<void> deleteNote(String noteId) async {
    final backgroundNotesRepository = ref.read(
      backgroundNotesRepositoryPowerSyncProvider,
    );
    await backgroundNotesRepository.deleteNote(noteId);
    _invalidateNotesStreamsIfMounted();
  }
}
