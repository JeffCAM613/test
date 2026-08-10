-- ============================================================================
-- Row counts for the main anonymization targets
-- ============================================================================
-- Read-only. Safe at any time.
--
--   sqlplus op/<password>@<TNS> @tests/manual/row_counts.sql
--
-- Use it to size a run. Runtime is dominated by the handful of history tables
-- at the bottom of this output, not by the number of columns in the inventory.
--
-- Counts come from optimizer statistics, so they are approximate and can be
-- stale or absent. Exact counts on tables this size are not worth the scan.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK OFF
SET HEADING ON

COLUMN table_name  FORMAT A34               HEADING 'TABLE'
COLUMN num_rows    FORMAT 999,999,999,999   HEADING 'ROWS (approx)'
COLUMN cols        FORMAT 999               HEADING 'COLUMNS'
COLUMN analyzed    FORMAT A12               HEADING 'STATS FROM'
COLUMN category    FORMAT A16               HEADING 'CATEGORY'
COLUMN codes       FORMAT 999,999,999       HEADING 'CODES'

PROMPT
PROMPT ====================================================================
PROMPT  Source populations - how many identifiers will be generated
PROMPT ====================================================================

SELECT 'ENTITY' AS category, COUNT(*) AS codes
  FROM op.structure s JOIN op.tiers t ON t.code = s.code
 WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'N'
UNION ALL
SELECT 'PORTFOLIO', COUNT(*)
  FROM op.structure s JOIN op.tiers t ON t.code = s.code
 WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'O'
UNION ALL
SELECT 'COUNTERPARTY', COUNT(*)
  FROM op.structure WHERE structure = 'Compte' AND ecran = 'w_tiers'
UNION ALL
SELECT 'BANK_ACCOUNT', COUNT(*)
  FROM op.compte_banque;

PROMPT
PROMPT ====================================================================
PROMPT  The 25 largest tables in the inventory
PROMPT ====================================================================
PROMPT  These decide how long a run takes. Everything else is noise.

SELECT * FROM (
   SELECT i.table_name,
          t.num_rows,
          COUNT(*) AS cols,
          NVL(TO_CHAR(t.last_analyzed, 'YYYY-MM-DD'), 'never') AS analyzed
     FROM anon_meta.anon_inventory i
     JOIN all_tables t ON t.owner = 'OP' AND t.table_name = i.table_name
    GROUP BY i.table_name, t.num_rows, t.last_analyzed
    ORDER BY NVL(t.num_rows, 0) DESC
) WHERE ROWNUM <= 25;

PROMPT
PROMPT ====================================================================
PROMPT  Totals
PROMPT ====================================================================

SELECT COUNT(DISTINCT i.table_name) AS tables_in_scope,
       COUNT(*)                     AS columns_in_scope,
       SUM(t.num_rows)              AS approx_rows_in_scope
  FROM anon_meta.anon_inventory i
  LEFT JOIN all_tables t ON t.owner = 'OP' AND t.table_name = i.table_name;

PROMPT
PROMPT  Tables showing 'never' above have no statistics, so their row count is
PROMPT  unknown and excluded from the total. The engine treats them as large and
PROMPT  applies a PARALLEL hint, which is the safe assumption.
PROMPT
