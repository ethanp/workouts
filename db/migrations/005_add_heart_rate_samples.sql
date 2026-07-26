-- R5: Add heart rate samples + session HR stats

ALTER TABLE sessions
ADD COLUMN average_heart_rate INTEGER,
ADD COLUMN max_heart_rate INTEGER;

CREATE TABLE heart_rate_samples (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    bpm INTEGER NOT NULL,
    source TEXT NOT NULL,
    energy_kcal REAL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_heart_rate_samples_session_id ON heart_rate_samples(session_id);
CREATE INDEX idx_heart_rate_samples_timestamp ON heart_rate_samples(timestamp DESC);

CREATE TRIGGER update_heart_rate_samples_updated_at
    BEFORE UPDATE ON heart_rate_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
