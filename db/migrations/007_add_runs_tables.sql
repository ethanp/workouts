-- R7: Dedicated run tracking tables

CREATE TABLE runs (
    id TEXT PRIMARY KEY,
    external_workout_id TEXT NOT NULL UNIQUE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER NOT NULL,
    distance_meters DOUBLE PRECISION NOT NULL,
    energy_kcal DOUBLE PRECISION,
    avg_heart_rate_bpm DOUBLE PRECISION,
    max_heart_rate_bpm DOUBLE PRECISION,
    is_indoor BOOLEAN NOT NULL DEFAULT false,
    route_available BOOLEAN NOT NULL DEFAULT false,
    source_name TEXT NOT NULL DEFAULT 'Apple Health',
    source_bundle_id TEXT,
    device_model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_runs_started_at ON runs(started_at DESC);
CREATE INDEX idx_runs_external_workout_id ON runs(external_workout_id);

CREATE TABLE run_route_points (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    point_index INTEGER NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    altitude_meters DOUBLE PRECISION,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(run_id, point_index)
);

CREATE INDEX idx_run_route_points_run_id ON run_route_points(run_id);
CREATE INDEX idx_run_route_points_timestamp ON run_route_points(timestamp DESC);

CREATE TABLE run_heart_rate_samples (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    bpm INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(run_id, timestamp)
);

CREATE INDEX idx_run_heart_rate_samples_run_id ON run_heart_rate_samples(run_id);
CREATE INDEX idx_run_heart_rate_samples_timestamp ON run_heart_rate_samples(timestamp DESC);

CREATE TRIGGER update_runs_updated_at
    BEFORE UPDATE ON runs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_run_route_points_updated_at
    BEFORE UPDATE ON run_route_points
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_run_heart_rate_samples_updated_at
    BEFORE UPDATE ON run_heart_rate_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
