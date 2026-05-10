import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/services/repositories/session_notes_repository_powersync.dart';

part 'session_notes_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<SessionNote>> sessionNotesStream(Ref ref, String sessionId) {
  final sessionNotesRepository = ref.watch(
    sessionNotesRepositoryPowerSyncProvider,
  );
  return sessionNotesRepository.watchNotesForSession(sessionId);
}

@riverpod
class SessionNotesController extends _$SessionNotesController {
  @override
  void build() {}

  Future<void> addNote({
    required String sessionId,
    required String content,
    required SessionNoteType noteType,
    String? exerciseId,
    String? blockId,
  }) async {
    final sessionNotesRepository = ref.read(
      sessionNotesRepositoryPowerSyncProvider,
    );
    final note = SessionNote(
      id: _uuid.v4(),
      sessionId: sessionId,
      exerciseId: exerciseId,
      blockId: blockId,
      content: content,
      noteType: noteType,
      source: SessionNoteSource.user,
      timestamp: DateTime.now(),
    );
    await sessionNotesRepository.saveNote(note);
  }

  Future<void> updateNote(SessionNote note, String newContent) async {
    final sessionNotesRepository = ref.read(
      sessionNotesRepositoryPowerSyncProvider,
    );
    await sessionNotesRepository.saveNote(note.copyWith(content: newContent));
  }

  Future<void> deleteNote(String id) async {
    final sessionNotesRepository = ref.read(
      sessionNotesRepositoryPowerSyncProvider,
    );
    await sessionNotesRepository.deleteNote(id);
  }
}
