ALTER TABLE cardio_workouts
    ADD COLUMN device_name TEXT,
    ADD COLUMN elevation_ascended_meters DOUBLE PRECISION,
    ADD COLUMN recovery_bpm DOUBLE PRECISION,
    ADD COLUMN effort_score DOUBLE PRECISION,
    ADD COLUMN estimated_effort_score DOUBLE PRECISION,
    ADD COLUMN machine_linked BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE cardio_distance_samples (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, started_at)
);

CREATE INDEX idx_cardio_distance_samples_workout_id ON cardio_distance_samples(workout_id);

CREATE TABLE cardio_step_samples (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, started_at)
);

CREATE INDEX idx_cardio_step_samples_workout_id ON cardio_step_samples(workout_id);

CREATE TABLE cardio_workout_events (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, event_type, occurred_at)
);

CREATE INDEX idx_cardio_workout_events_workout_id ON cardio_workout_events(workout_id);

CREATE TRIGGER update_cardio_distance_samples_updated_at BEFORE UPDATE ON cardio_distance_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cardio_step_samples_updated_at BEFORE UPDATE ON cardio_step_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cardio_workout_events_updated_at BEFORE UPDATE ON cardio_workout_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
