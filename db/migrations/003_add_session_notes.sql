-- R3: Add session notes table
-- Notes captured during or after workout sessions
-- Note: session_id is TEXT to match existing sessions table

CREATE TABLE session_notes (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    exercise_id TEXT,
    block_id TEXT,
    content TEXT NOT NULL,
    note_type TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'user',
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_session_notes_session_id ON session_notes(session_id);
CREATE INDEX idx_session_notes_timestamp ON session_notes(timestamp DESC);

CREATE TRIGGER update_session_notes_updated_at
    BEFORE UPDATE ON session_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
