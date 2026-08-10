-- ============================================================================
-- Monitor a run in progress
-- ============================================================================
-- Read-only. Run from a SECOND session while an anonymization is going.
--
--   sqlplus op/<password>@<TNS> @tests/manual/monitor_op_progress.sql
--
-- Why this is needed: sqlplus only prints DBMS_OUTPUT once a PL/SQL block ends,
-- so the running session shows nothing for minutes at a time. The engine writes
-- anon_meta.anon_step_log through an autonomous transaction, so rows appear as
-- each item completes and are visible from here immediately.
--
-- Re-run it whenever you want a fresh picture; it takes no locks.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK OFF
SET HEADING ON

COLUMN run_id     FORMAT 9999      HEADING 'RUN'
COLUMN mode       FORMAT A8        HEADING 'MODE'
COLUMN status     FORMAT A10       HEADING 'STATUS'
COLUMN started    FORMAT A20       HEADING 'STARTED'
COLUMN elapsed    FORMAT A12       HEADING 'ELAPSED'
COLUMN phase      FORMAT A14       HEADING 'PHASE'
COLUMN done       FORMAT 9999      HEADING 'ITEMS'
COLUMN rows_done  FORMAT 999,999,999,999 HEADING 'ROWS'
COLUMN secs       FORMAT 999,999   HEADING 'SECONDS'
COLUMN object_name FORMAT A46      HEADING 'OBJECT'
COLUMN message    FORMAT A60       HEADING 'MESSAGE'
COLUMN logged     FORMAT A10       HEADING 'AT'

PROMPT
PROMPT ====================================================================
PROMPT  Current run
PROMPT ====================================================================

SELECT run_id, mode, status,
       TO_CHAR(started_at, 'YYYY-MM-DD HH24:MI:SS') AS started,
       CASE
          WHEN finished_at IS NULL THEN
             TO_CHAR(ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(started_at AS DATE)) * 1440, 1))
             || ' min (running)'
          ELSE
             TO_CHAR(ROUND((CAST(finished_at AS DATE) - CAST(started_at AS DATE)) * 1440, 1))
             || ' min'
       END AS elapsed
  FROM anon_meta.anon_run
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run);

PROMPT
PROMPT ====================================================================
PROMPT  Progress by phase
PROMPT ====================================================================
PROMPT  Phases run in this order: TRIGGERS, MAPPING, NULL_OUT, CODE,
PROMPT  DESCRIPTION / SELF_CODE, TRIGGERS.

SELECT phase,
       COUNT(*)                  AS done,
       SUM(rows_affected)        AS rows_done,
       ROUND(SUM(elapsed_ms)/1000) AS secs
  FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
 GROUP BY phase
 ORDER BY MIN(logged_at);

PROMPT
PROMPT ====================================================================
PROMPT  Against the inventory
PROMPT ====================================================================

SELECT (SELECT COUNT(*) FROM anon_meta.anon_inventory)     AS in_inventory,
       (SELECT COUNT(*) FROM anon_meta.anon_step_log
         WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
           AND phase IN ('NULL_OUT','CODE','DESCRIPTION','SELF_CODE')) AS items_logged
  FROM dual;

PROMPT
PROMPT  (items_logged counts grouped statements, so it is normally lower than
PROMPT   in_inventory: all NULL_OUT columns of one table share one statement.)

PROMPT
PROMPT ====================================================================
PROMPT  Last 25 items
PROMPT ====================================================================

SELECT * FROM (
   SELECT TO_CHAR(logged_at, 'HH24:MI:SS') AS logged,
          phase, object_name, status, rows_affected AS rows_done
     FROM anon_meta.anon_step_log
    WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
    ORDER BY logged_at DESC
) WHERE ROWNUM <= 25;

PROMPT
PROMPT ====================================================================
PROMPT  Slowest 10 so far
PROMPT ====================================================================

SELECT * FROM (
   SELECT object_name, phase, rows_affected AS rows_done,
          ROUND(elapsed_ms/1000) AS secs
     FROM anon_meta.anon_step_log
    WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
      AND elapsed_ms IS NOT NULL
    ORDER BY elapsed_ms DESC
) WHERE ROWNUM <= 10;

PROMPT
PROMPT ====================================================================
PROMPT  Errors  (should be empty)
PROMPT ====================================================================

SELECT TO_CHAR(logged_at, 'HH24:MI:SS') AS logged, object_name, message
  FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
   AND status = 'ERROR'
 ORDER BY logged_at;

PROMPT
