ALTER TABLE cardio_workouts
    ADD COLUMN average_mets DOUBLE PRECISION,
    ADD COLUMN fitness_machine_duration_seconds DOUBLE PRECISION,
    ADD COLUMN cross_trainer_distance_meters DOUBLE PRECISION,
    ADD COLUMN indoor_bike_distance_meters DOUBLE PRECISION,
    ADD COLUMN basal_energy_kcal DOUBLE PRECISION,
    ADD COLUMN step_count DOUBLE PRECISION,
    ADD COLUMN flights_climbed DOUBLE PRECISION,
    ADD COLUMN min_heart_rate_bpm DOUBLE PRECISION;
