-- R8: Rename runs tables to cardio_workouts, replace is_indoor with activity_type

ALTER TABLE runs RENAME TO cardio_workouts;
ALTER TABLE run_route_points RENAME TO cardio_route_points;
ALTER TABLE run_heart_rate_samples RENAME TO cardio_heart_rate_samples;

ALTER TABLE cardio_workouts ADD COLUMN activity_type TEXT NOT NULL DEFAULT 'outdoorRun';
UPDATE cardio_workouts SET activity_type = 'indoorRun' WHERE is_indoor = true;
ALTER TABLE cardio_workouts DROP COLUMN is_indoor;

ALTER TABLE cardio_route_points RENAME COLUMN run_id TO workout_id;
ALTER TABLE cardio_heart_rate_samples RENAME COLUMN run_id TO workout_id;
