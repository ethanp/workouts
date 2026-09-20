-- Cardio GPS/HR/distance/step series stay in Postgres for PostgREST upload
-- and on-demand reads. They are no longer in powersync.yaml buckets, so a
-- Health backfill does not rebuild giant sync buckets.
--
-- The workouts publication is FOR ALL TABLES (it also covers PowerSync
-- storage tables in this database), so individual tables cannot be dropped
-- from it. WAL still sees series inserts; clients no longer download them.

COMMENT ON TABLE cardio_route_points IS
  'Bulk-uploaded via PostgREST; not in PowerSync sync rules.';
COMMENT ON TABLE cardio_heart_rate_samples IS
  'Bulk-uploaded via PostgREST; not in PowerSync sync rules.';
COMMENT ON TABLE cardio_distance_samples IS
  'Bulk-uploaded via PostgREST; not in PowerSync sync rules.';
COMMENT ON TABLE cardio_step_samples IS
  'Bulk-uploaded via PostgREST; not in PowerSync sync rules.';
