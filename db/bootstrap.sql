-- Workouts role bootstrap
-- Creates the workouts role with replication privileges.
-- This is run by reset-workouts-db.sh using the Postgres admin user.
-- Password is set separately by the calling script.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'workouts') THEN
    CREATE ROLE workouts LOGIN;
  END IF;
END
$$;

ALTER ROLE workouts WITH REPLICATION;
