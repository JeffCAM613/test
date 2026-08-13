-- ============================================================================
-- 20 - Prepare to load the coverage inventory
-- ============================================================================
-- Clears anon_meta.anon_inventory so the generated INSERT file can repopulate
-- it. The orchestrator runs that file directly, then 21_validate_inventory.sql.
--
-- The CSVs live on the machine running this, which may not be the database
-- server, so they cannot be read by an external table. The batch script parses
-- them and writes a file of INSERT statements.
--
-- Reloading on every run is what makes editing a CSV sufficient to change what
-- gets anonymized.
--
-- Takes no parameters. It deliberately does NOT @-include the generated file:
-- a nested @ inside a script that was itself @-included, with the path arriving
-- through a re-DEFINE, is one indirection too many to debug when it goes wrong.
-- The orchestrator holds the path and runs the file itself.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF

PROMPT
PROMPT === Coverage inventory ===

-- Take the table lock explicitly, with a bounded wait, before deleting.
--
-- Without this, a row lock held by an abandoned session makes the DELETE wait
-- FOREVER - Oracle DML has no default timeout - so the run appears to hang, and
-- if that session is then killed the failure surfaces as ORA-03114, which reads
-- as a network problem and sends the diagnosis in the wrong direction.
--
-- Ten seconds is generous: nothing legitimate holds this table, since it is
-- written only at the start of a run.
DECLARE
   v_blocker VARCHAR2(400);
BEGIN
   EXECUTE IMMEDIATE 'LOCK TABLE anon_meta.anon_inventory IN EXCLUSIVE MODE WAIT 10';

EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE = -54 THEN            -- ORA-00054: resource busy
         BEGIN
            SELECT LISTAGG('session ' || s.sid || ',' || s.serial#
                        || ' (' || s.username || ', ' || s.status
                        || ', ' || NVL(s.program, '?') || ')', '; ')
                     WITHIN GROUP (ORDER BY s.sid)
              INTO v_blocker
              FROM v$session s
              JOIN v$locked_object lo ON lo.session_id = s.sid
              JOIN all_objects o      ON o.object_id   = lo.object_id
             WHERE o.owner = 'ANON_META' AND o.object_name = 'ANON_INVENTORY';
         EXCEPTION
            WHEN OTHERS THEN
               v_blocker := '(no privilege on v$session - run '
                         || 'tests/manual/check_locks.sql as SYS)';
         END;

         RAISE_APPLICATION_ERROR(-20022,
            'anon_meta.anon_inventory is locked by another session, so the inventory '
         || 'cannot be reloaded. Nothing has been changed. Holder: '
         || NVL(v_blocker, 'unknown') || '. Usually an abandoned run - clear it with '
         || 'ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE as SYS, then re-run.');
      ELSE
         RAISE;
      END IF;
END;
/

DELETE FROM anon_meta.anon_inventory;
COMMIT;
