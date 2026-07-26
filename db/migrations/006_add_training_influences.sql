-- R9: Add training influences (coaching philosophies)

CREATE TABLE training_influences (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    principles TEXT NOT NULL DEFAULT '[]',
    is_active INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_training_influences_is_active ON training_influences(is_active);

CREATE TRIGGER update_training_influences_updated_at
    BEFORE UPDATE ON training_influences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
