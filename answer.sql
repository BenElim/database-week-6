-- =====================================================================
-- PostgreSQL Backup, Recovery and Replication Lab
-- Database: bootcamp
-- NOTE: Lines starting with "-- $" are shell commands (run in a terminal).
--       Lines starting with "-- conf:" go in a config file.
--       Everything else is SQL (run in psql).
-- Replace /home/youruser with your real home directory (run: echo $HOME).
-- =====================================================================


-- =====================================================================
-- STEP 1: Take and verify a logical backup
-- =====================================================================
-- $ mkdir -p ~/backups
-- $ pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
-- $ pg_restore --list ~/backups/bootcamp.dump | head
-- $ createdb bootcamp_check && pg_restore -d bootcamp_check ~/backups/bootcamp.dump

-- Verify the restore worked: row counts should match the original.
-- $ psql -d bootcamp        -c "SELECT count(*) FROM students;"
-- $ psql -d bootcamp_check  -c "SELECT count(*) FROM students;"


-- =====================================================================
-- STEP 2: Enable WAL archiving + base backup
-- =====================================================================
-- $ mkdir -p ~/backups/wal
-- (the postgres server user must be able to write there:)
-- $ chmod 700 ~/backups/wal   # and make sure the postgres user owns/can write it

-- conf: postgresql.conf
-- conf:   wal_level = replica
-- conf:   archive_mode = on
-- conf:   archive_command = 'cp %p /home/youruser/backups/wal/%f'
-- (use an absolute path; $USER is not expanded inside postgresql.conf)

-- $ sudo systemctl restart postgresql
-- $ pg_basebackup -D ~/backups/base -Ft -z -Xs -P

-- Confirm archiving is working:
SELECT archived_count, last_archived_wal, failed_count
FROM pg_stat_archiver;


-- =====================================================================
-- STEP 3: Simulate a disaster and recover (point-in-time recovery)
-- =====================================================================
-- Force the current WAL segment to be archived, then record the time.
SELECT pg_switch_wal();
SELECT now();          -- RECORD THIS TIME, e.g. 2026-09-30 10:00:00+03

SELECT count(*) FROM students;   -- note the count before the disaster

DELETE FROM students;            -- oops

SELECT pg_switch_wal();          -- make sure the DELETE's WAL is archived too

-- Recovery outline (shell):
-- 1. Stop PostgreSQL:
-- $ sudo systemctl stop postgresql
-- 2. Replace the data directory with the base backup
--    (Debian/Ubuntu default path shown; check with: SHOW data_directory;)
-- $ sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main.old
-- $ sudo mkdir /var/lib/postgresql/16/main
-- $ sudo tar -xzf ~/backups/base/base.tar.gz -C /var/lib/postgresql/16/main
-- $ sudo tar -xzf ~/backups/base/pg_wal.tar.gz -C /var/lib/postgresql/16/main/pg_wal
-- $ sudo chown -R postgres:postgres /var/lib/postgresql/16/main
-- $ sudo chmod 700 /var/lib/postgresql/16/main
-- 3. Set recovery settings in postgresql.conf:
-- conf:   restore_command = 'cp /home/youruser/backups/wal/%f %p'
-- conf:   recovery_target_time = '2026-09-30 10:00:00'
-- conf:   recovery_target_action = 'promote'
--    Then tell PostgreSQL to enter recovery mode (PostgreSQL 12+):
-- $ sudo -u postgres touch /var/lib/postgresql/16/main/recovery.signal
-- 4. Start PostgreSQL:
-- $ sudo systemctl start postgresql
-- 5. Verify recovery:
SELECT count(*) FROM students;   -- should equal the count before the DELETE


-- =====================================================================
-- STEP 4: Set up a streaming standby
-- =====================================================================
-- On the primary:
CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'reppass';

-- conf: pg_hba.conf
-- conf:   host replication replicator 127.0.0.1/32 md5
-- Reload so the change takes effect:
SELECT pg_reload_conf();

-- Build the standby (separate data directory):
-- $ pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P
-- (-R writes standby.signal and primary_conninfo automatically)
-- The standby must run on a different port, e.g. in ~/standby/postgresql.conf:
-- conf:   port = 5433
-- $ chmod 700 ~/standby
-- $ pg_ctl -D ~/standby -l ~/standby/standby.log start


-- =====================================================================
-- STEP 5: Watch replication health (run on the primary)
-- =====================================================================
SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- On the standby (port 5433) this should return true:
-- $ psql -p 5433 -d bootcamp -c "SELECT pg_is_in_recovery();"
