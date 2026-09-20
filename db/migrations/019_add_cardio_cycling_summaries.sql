ALTER TABLE cardio_workouts
    ADD COLUMN average_cycling_cadence_rpm DOUBLE PRECISION,
    ADD COLUMN average_cycling_power_watts DOUBLE PRECISION,
    ADD COLUMN average_cycling_speed_meters_per_second DOUBLE PRECISION;
