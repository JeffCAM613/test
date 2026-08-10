-- ============================================================================
-- Inspect the identifier mapping
-- ============================================================================
-- Read-only. Safe at any time.
--
--   sqlplus op/<password>@<TNS> @tests/manual/inspect_code_map.sql
--
-- anon_meta.code_map is the only record of what the original values were. This
-- shows its shape and looks for the things that would make it untrustworthy.
--
-- ANY OUTPUT FROM THIS SCRIPT IS UNANONYMIZED CLIENT DATA. Do not paste it into
-- a ticket, and drop the anon_meta schema once the copy has been verified and
-- handed over.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK OFF
SET HEADING ON

COLUMN category    FORMAT A16              HEADING 'CATEGORY'
COLUMN mappings    FORMAT 999,999,999      HEADING 'MAPPINGS'
COLUMN lowest      FORMAT A14              HEADING 'FIRST'
COLUMN highest     FORMAT A14              HEADING 'LAST'
COLUMN widest      FORMAT 999              HEADING 'MAX WIDTH'
COLUMN old_code    FORMAT A30              HEADING 'ORIGINAL'
COLUMN new_code    FORMAT A14              HEADING 'REPLACEMENT'
COLUMN issue       FORMAT A54              HEADING 'CHECK'
COLUMN result      FORMAT A20              HEADING 'RESULT'

PROMPT
PROMPT ====================================================================
PROMPT  Shape
PROMPT ====================================================================

SELECT category,
       COUNT(*)           AS mappings,
       MIN(new_code)      AS lowest,
       MAX(new_code)      AS highest,
       MAX(LENGTH(new_code)) AS widest
  FROM anon_meta.code_map
 GROUP BY category
 ORDER BY category;

PROMPT
PROMPT ====================================================================
PROMPT  Health checks
PROMPT ====================================================================

SELECT 'replacements are unique' AS issue,
       CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE COUNT(*) || ' DUPLICATED' END AS result
  FROM (SELECT new_code FROM anon_meta.code_map GROUP BY new_code HAVING COUNT(*) > 1)
UNION ALL
SELECT 'originals spanning two categories',
       CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE COUNT(*) || ' ambiguous' END
  FROM (SELECT old_code FROM anon_meta.code_map
         GROUP BY old_code HAVING COUNT(DISTINCT category) > 1)
UNION ALL
SELECT 'resolved lookup table is complete',
       CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE COUNT(*) || ' MISSING' END
  FROM (SELECT DISTINCT old_code FROM anon_meta.code_map
        MINUS
        SELECT old_code FROM anon_meta.code_map_any)
UNION ALL
SELECT 'original still equals its replacement',
       CASE WHEN COUNT(*) = 0 THEN 'ok' ELSE COUNT(*) || ' NOT ANONYMIZED' END
  FROM anon_meta.code_map WHERE old_code = new_code;

PROMPT
PROMPT ====================================================================
PROMPT  Originals belonging to more than one category
PROMPT ====================================================================
PROMPT  Legal, but it means an unrestricted lookup had to choose. Resolved by
PROMPT  priority: entity, then portfolio, then counterparty, then bank account.
PROMPT  This is exactly where a wrong choice would silently mis-map a column,
PROMPT  so it is worth confirming these are what you expect.

SELECT * FROM (
   SELECT old_code,
          LISTAGG(category || '->' || new_code, '   ') WITHIN GROUP (ORDER BY category) AS new_code
     FROM anon_meta.code_map
    GROUP BY old_code
   HAVING COUNT(DISTINCT category) > 1
) WHERE ROWNUM <= 20;

PROMPT
PROMPT ====================================================================
PROMPT  Sample - 5 per category
PROMPT ====================================================================

SELECT category, old_code, new_code FROM (
   SELECT category, old_code, new_code,
          ROW_NUMBER() OVER (PARTITION BY category ORDER BY new_code) AS rn
     FROM anon_meta.code_map
) WHERE rn <= 5
 ORDER BY category, new_code;

PROMPT
PROMPT  Reminder: the ORIGINAL column above is real client data.
PROMPT
