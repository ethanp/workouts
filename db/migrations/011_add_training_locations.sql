CREATE TABLE training_locations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    equipment TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER update_training_locations_updated_at
    BEFORE UPDATE ON training_locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
