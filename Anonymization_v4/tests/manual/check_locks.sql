-- ============================================================================
-- Who is holding the anonymization metadata tables?
-- ============================================================================
-- Read-only. Run as SYS.
--
--   sqlplus sys/<password>@<TNS> as sysdba @tests/manual/check_locks.sql
--
-- Run this when a run stalls or fails at "=== Coverage inventory ===". The
-- inventory reload takes an exclusive lock on anon_meta.anon_inventory; if an
-- abandoned session still holds a row lock, the reload cannot proceed.
--
-- ----------------------------------------------------------------------------
-- WHY THE SYMPTOM IS MISLEADING
--
-- Oracle DML has no default lock timeout. A blocked DELETE waits forever, so
-- the run looks hung rather than failed. If that session is then killed, the
-- client reports ORA-03114 "not connected to ORACLE" - which reads as a network
-- fault and sends the diagnosis in the wrong direction entirely.
--
-- The run now takes the lock explicitly with WAIT 10 and names the holder, so
-- this script is a second opinion rather than the only way to find out.
--
-- ----------------------------------------------------------------------------
-- WHAT IS NOT THE CAUSE
--
-- Sessions do NOT survive an instance restart. If a run fails the same way
-- immediately after a bounce, locks are not the explanation - look at the alert
-- log instead:
--   SELECT name, value FROM v$diag_info WHERE name IN ('Diag Trace','Diag Alert');
-- and search it for ORA-00600, ORA-07445 or ORA-04030 around the failure time.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK OFF
SET HEADING ON

COLUMN sid_serial   FORMAT A14  HEADING 'SID,SERIAL#'
COLUMN username     FORMAT A12  HEADING 'USER'
COLUMN os_user      FORMAT A16  HEADING 'OS USER'
COLUMN status       FORMAT A9   HEADING 'STATUS'
COLUMN program      FORMAT A24  HEADING 'PROGRAM'
COLUMN object_name  FORMAT A22  HEADING 'OBJECT'
COLUMN lock_mode    FORMAT A10  HEADING 'MODE'
COLUMN idle         FORMAT A12  HEADING 'IDLE'
COLUMN kill_command FORMAT A56  HEADING 'TO CLEAR IT'

PROMPT
PROMPT ====================================================================
PROMPT  Locks held on ANON_META objects
PROMPT ====================================================================

SELECT s.sid || ',' || s.serial#                        AS sid_serial,
       s.username,
       s.osuser                                         AS os_user,
       s.status,
       SUBSTR(s.program, 1, 24)                         AS program,
       o.object_name,
       DECODE(lo.locked_mode, 1,'Null', 2,'Row-S', 3,'Row-X',
                              4,'Share', 5,'S/Row-X', 6,'Exclusive',
                              TO_CHAR(lo.locked_mode))  AS lock_mode,
       TO_CHAR(ROUND(s.last_call_et / 60), '999999') || ' min' AS idle
  FROM v$locked_object lo
  JOIN dba_objects o ON o.object_id = lo.object_id
  JOIN v$session   s ON s.sid       = lo.session_id
 WHERE o.owner = 'ANON_META'
 ORDER BY s.sid;

PROMPT
PROMPT  No rows above means nothing is holding these tables.

PROMPT
PROMPT ====================================================================
PROMPT  Ready-to-paste kill statements
PROMPT ====================================================================
PROMPT  Check STATUS and IDLE first. An ACTIVE session with low idle time may
PROMPT  be a legitimate run in progress - killing it is safe for the data but
PROMPT  wastes its work.

SELECT DISTINCT
       'ALTER SYSTEM KILL SESSION ''' || s.sid || ',' || s.serial#
       || ''' IMMEDIATE;   -- ' || s.status || ', idle '
       || TRIM(TO_CHAR(ROUND(s.last_call_et / 60))) || ' min' AS kill_command
  FROM v$locked_object lo
  JOIN dba_objects o ON o.object_id = lo.object_id
  JOIN v$session   s ON s.sid       = lo.session_id
 WHERE o.owner = 'ANON_META';

PROMPT
PROMPT ====================================================================
PROMPT  All OP sessions
PROMPT ====================================================================
PROMPT  INACTIVE sessions with a long idle time are abandoned runs.

SELECT s.sid || ',' || s.serial#   AS sid_serial,
       s.username,
       s.osuser                    AS os_user,
       s.status,
       SUBSTR(s.program, 1, 24)    AS program,
       TO_CHAR(ROUND(s.last_call_et / 60), '999999') || ' min' AS idle
  FROM v$session s
 WHERE s.username IN ('OP', 'ANON_META', 'ATRACE')
 ORDER BY s.status, s.last_call_et DESC;

PROMPT
PROMPT ====================================================================
PROMPT  Blocking chains anywhere in the instance
PROMPT ====================================================================

SELECT s.sid || ',' || s.serial#   AS sid_serial,
       s.username,
       s.status,
       SUBSTR(s.program, 1, 24)    AS program,
       'blocked by SID ' || s.blocking_session AS object_name
  FROM v$session s
 WHERE s.blocking_session IS NOT NULL
 ORDER BY s.sid;

PROMPT
PROMPT  No rows above means nothing is blocked anywhere.
PROMPT
