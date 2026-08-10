-- ============================================================================
-- 20 - Load the coverage inventory
-- ============================================================================
-- Replaces anon_meta.anon_inventory with the contents of the CSVs.
--
-- The CSVs live on the machine running this, which may not be the database
-- server, so they cannot be read by an external table. The batch script parses
-- them and writes a file of INSERT statements; this script clears the table,
-- runs that file, then validates the result.
--
-- Reloading on every run is what makes editing a CSV sufficient to change what
-- gets anonymized.
--
-- Parameters: &1 = full path to the generated INSERT file
-- ============================================================================

DEFINE inventory_data = &1

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF
SET DEFINE OFF

PROMPT
PROMPT === Coverage inventory ===

DELETE FROM anon_meta.anon_inventory;
COMMIT;

SET DEFINE ON
@&inventory_data
SET DEFINE OFF

-- ----------------------------------------------------------------------------
-- Validate what was loaded.
-- ----------------------------------------------------------------------------
DECLARE
   v_total   PLS_INTEGER;
   v_base    PLS_INTEGER;
   v_custom  PLS_INTEGER;
   v_bad     PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO v_total FROM anon_meta.anon_inventory;

   IF v_total = 0 THEN
      RAISE_APPLICATION_ERROR(-20020,
         'The inventory is empty. config/inventory_op.csv was not found, or every line in it '
      || 'was a comment. There is nothing to anonymize - stopping before any changes are made.');
   END IF;

   SELECT COUNT(*) INTO v_base   FROM anon_meta.anon_inventory WHERE source = 'BASE';
   SELECT COUNT(*) INTO v_custom FROM anon_meta.anon_inventory WHERE source = 'CUSTOM';

   -- A BANK_ACCOUNT rule on anything other than CODE, DESCRIPTION or SELF_CODE
   -- would silently do nothing, so catch it here rather than at run time.
   SELECT COUNT(*) INTO v_bad
     FROM anon_meta.anon_inventory
    WHERE (rule = 'NULL_OUT'    AND category <> 'NONE')
       OR (rule <> 'NULL_OUT'   AND category  = 'NONE');

   DBMS_OUTPUT.PUT_LINE('  loaded ............ ' || v_total || ' items');
   DBMS_OUTPUT.PUT_LINE('    shipped ......... ' || v_base);
   DBMS_OUTPUT.PUT_LINE('    site-specific ... ' || v_custom);

   IF v_bad > 0 THEN
      RAISE_APPLICATION_ERROR(-20021,
         v_bad || ' inventory row(s) pair a rule with a category that cannot apply. '
      || 'NULL_OUT requires category NONE; every other rule requires a real category. '
      || 'Query anon_meta.anon_inventory to find them.');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- Breakdown, so the run log records exactly what scope was loaded.
-- ----------------------------------------------------------------------------
COLUMN rule     FORMAT A14
COLUMN category FORMAT A14
COLUMN items    FORMAT 9999
SET HEADING ON

PROMPT
SELECT rule, category, COUNT(*) AS items
  FROM anon_meta.anon_inventory
 GROUP BY rule, category
 ORDER BY DECODE(rule, 'NULL_OUT', 1, 'CODE', 2, 'DESCRIPTION', 3, 4), category;

SET HEADING OFF
PROMPT
SET DEFINE ON
