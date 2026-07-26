CREATE TABLE cardio_best_efforts (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    distance_meters DOUBLE PRECISION NOT NULL,
    elapsed_seconds DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, distance_meters)
);

CREATE INDEX idx_cardio_best_efforts_workout_id ON cardio_best_efforts(workout_id);

CREATE TRIGGER update_cardio_best_efforts_updated_at BEFORE UPDATE ON cardio_best_efforts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
