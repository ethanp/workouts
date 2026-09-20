CREATE TABLE cardio_computed_metrics (
    id TEXT PRIMARY KEY REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    zone1_seconds INTEGER NOT NULL DEFAULT 0,
    zone2_seconds INTEGER NOT NULL DEFAULT 0,
    zone3_seconds INTEGER NOT NULL DEFAULT 0,
    zone4_seconds INTEGER NOT NULL DEFAULT 0,
    zone5_seconds INTEGER NOT NULL DEFAULT 0,
    has_hr_samples INTEGER NOT NULL DEFAULT 0,
    pace_seconds_per_mile DOUBLE PRECISION,
    meters_per_heartbeat DOUBLE PRECISION,
    cardiac_drift_percent DOUBLE PRECISION,
    has_distance_samples INTEGER NOT NULL DEFAULT 0,
    distance_origin TEXT,
    fitness_confidence TEXT,
    computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER update_cardio_computed_metrics_updated_at
    BEFORE UPDATE ON cardio_computed_metrics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
