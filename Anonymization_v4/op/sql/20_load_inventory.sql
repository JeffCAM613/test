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

DELETE FROM anon_meta.anon_inventory;
COMMIT;
