# PostgreSQL Backup, Recovery & Replication Lab

This repo contains my solution to the PLP PostgreSQL backup and recovery lab, using the `bootcamp` database.

## Files

- `answer.sql` – all commands and SQL for the five steps, with comments explaining where each line is run (psql, shell, or a config file).

## What I did

1. **Logical backup** – used `pg_dump -Fc` to back up `bootcamp`, listed the archive with `pg_restore --list`, and restored it into `bootcamp_check` to prove the backup works.
2. **WAL archiving** – set `wal_level = replica`, `archive_mode = on` and an `archive_command` that copies WAL files to `~/backups/wal`, then took a base backup with `pg_basebackup`.
3. **Point-in-time recovery** – recorded the time with `SELECT now();`, deleted the `students` data, then restored the base backup and replayed archived WAL up to `recovery_target_time`.
4. **Streaming standby** – created a `replicator` role, allowed it in `pg_hba.conf`, and built a standby with `pg_basebackup -R` in a separate data directory.
5. **Replication health** – used `pg_stat_replication` and `pg_wal_lsn_diff` to check state and lag in bytes.

## Notes

- Paths in `postgresql.conf` must be absolute (`~` and `$USER` are not expanded there).
- On PostgreSQL 12+, recovery is triggered by a `recovery.signal` file, and a standby by `standby.signal` (created by `-R`).
- The standby runs on port 5433 so it does not clash with the primary on 5432.
- The `reppass` password is for lab use only; use a strong password in real systems.

## Requirements

PostgreSQL 12 or newer, a Linux shell with `sudo`, and the `bootcamp` database with a `students` table.
