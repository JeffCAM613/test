-- ============================================================================
-- Which inventory objects exist on this instance
-- ============================================================================
-- Read-only. Safe at any time.
--
--   sqlplus op/<password>@<TNS> @tests/manual/check_tables_exist.sql
--
-- Answers "what will be skipped?" before committing to a run. The inventory
-- deliberately covers several KTP/CTI versions, so some absences are normal -
-- val_ssi_account and val_cptyrating in particular are not on every instance.
--
-- Requires the inventory to be loaded; any run, including a dry run, loads it.
-- The dry run reports the same thing and also checks column widths, so prefer
-- it when you are about to run for real.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 500
SET FEEDBACK OFF
SET HEADING ON

COLUMN table_name  FORMAT A34 HEADING 'TABLE'
COLUMN column_name FORMAT A26 HEADING 'COLUMN'
COLUMN rule        FORMAT A12 HEADING 'RULE'
COLUMN items       FORMAT 999 HEADING 'COLUMNS'
COLUMN present     FORMAT A9  HEADING 'PRESENT'
COLUMN state       FORMAT A12 HEADING 'STATE'

PROMPT
PROMPT ====================================================================
PROMPT  Overall
PROMPT ====================================================================

SELECT COUNT(*)                                                    AS inventory,
       COUNT(c.column_name)                                        AS found,
       COUNT(*) - COUNT(c.column_name)                             AS missing
  FROM anon_meta.anon_inventory i
  LEFT JOIN all_tab_columns c
    ON c.owner = 'OP' AND c.table_name = i.table_name AND c.column_name = i.column_name;

PROMPT
PROMPT ====================================================================
PROMPT  Tables entirely absent
PROMPT ====================================================================

SELECT i.table_name, COUNT(*) AS items
  FROM anon_meta.anon_inventory i
 WHERE NOT EXISTS (SELECT 1 FROM all_tables t
                    WHERE t.owner = 'OP' AND t.table_name = i.table_name)
 GROUP BY i.table_name
 ORDER BY i.table_name;

PROMPT
PROMPT ====================================================================
PROMPT  Columns absent from a table that DOES exist
PROMPT ====================================================================
PROMPT  These are worth a look: a table present but a column missing usually
PROMPT  means a version difference, occasionally a typo in the inventory.

SELECT i.table_name, i.column_name, i.rule
  FROM anon_meta.anon_inventory i
 WHERE EXISTS     (SELECT 1 FROM all_tables t
                    WHERE t.owner = 'OP' AND t.table_name = i.table_name)
   AND NOT EXISTS (SELECT 1 FROM all_tab_columns c
                    WHERE c.owner = 'OP' AND c.table_name = i.table_name
                      AND c.column_name = i.column_name)
 ORDER BY i.table_name, i.column_name;

PROMPT
PROMPT ====================================================================
PROMPT  Columns too narrow for a generated identifier  (should be empty)
PROMPT ====================================================================
PROMPT  Widest generated value is CB_ + 7 digits = 10 characters.

SELECT i.table_name, i.column_name, c.data_type || '(' || c.char_length || ')' AS present,
       'TOO NARROW' AS state
  FROM anon_meta.anon_inventory i
  JOIN all_tab_columns c
    ON c.owner = 'OP' AND c.table_name = i.table_name AND c.column_name = i.column_name
 WHERE i.rule IN ('CODE', 'DESCRIPTION', 'SELF_CODE')
   AND (c.data_type NOT IN ('VARCHAR2','CHAR','NVARCHAR2','NCHAR') OR c.char_length < 10)
 ORDER BY i.table_name, i.column_name;

PROMPT
