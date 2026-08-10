-- ============================================================================
-- OP ANONYMIZATION - Progress Tracker
-- ============================================================================
-- Run as SYS or a user with SELECT on OP tables and V$SESSION/V$SQL
--
-- HOW IT WORKS:
-- The pack_anonym.anonymous_tables procedure iterates through each code
-- in tiers (entities, portfolios, counterparties) and compte_banque,
-- renaming them with prefixes: E_, P_, T_, CB_.
-- For each code, it cascades the rename across 60+ history/reference tables.
--
-- Progress = codes already renamed / total codes per category.
-- ============================================================================

-- ============================================================================
-- SECTION 1: Overall Progress by Category
-- ============================================================================
SELECT
 category,
 done,
 total,
 total - done AS remaining,
 CASE WHEN total > 0 THEN ROUND(done * 100.0 / total, 1) ELSE 100 END AS pct_done,
 CASE WHEN total - done = 0 THEN 'COMPLETE' ELSE 'IN PROGRESS' END AS status
FROM (
 -- Entities (tiers where flag_portefeuille = 'N')
 SELECT 'A. Entities (E_)' AS category,
 COUNT(CASE WHEN t.code LIKE 'E_%' THEN 1 END) AS done,
 COUNT(*) AS total
 FROM op.tiers t
 INNER JOIN op.structure s ON s.code = t.code AND s.structure = 'Entite' AND s.ecran = 'w_tiers'
 WHERE t.flag_portefeuille = 'N'

 UNION ALL

 -- Portfolios (tiers where flag_portefeuille = 'O')
 SELECT 'B. Portfolios (P_)',
 COUNT(CASE WHEN t.code LIKE 'P_%' THEN 1 END),
 COUNT(*)
 FROM op.tiers t
 INNER JOIN op.structure s ON s.code = t.code AND s.structure = 'Entite' AND s.ecran = 'w_tiers'
 WHERE t.flag_portefeuille = 'O'

 UNION ALL

 -- Counterparties (tiers via structure='Compte')
 SELECT 'C. Counterparties (T_)',
 COUNT(CASE WHEN s.code LIKE 'T_%' THEN 1 END),
 COUNT(*)
 FROM op.structure s
 WHERE s.structure = 'Compte' AND s.ecran = 'w_tiers'

 UNION ALL

 -- Bank Accounts
 SELECT 'D. Bank Accounts (CB_)',
 COUNT(CASE WHEN code LIKE 'CB_%' THEN 1 END),
 COUNT(*)
 FROM op.compte_banque
)
ORDER BY category;

-- ============================================================================
-- SECTION 2: Structure table progress (mirrors tiers/cb renames)
-- ============================================================================
SELECT
 'Structure codes renamed' AS metric,
 COUNT(CASE WHEN code LIKE 'E_%' OR code LIKE 'P_%' OR code LIKE 'T_%' THEN 1 END) AS done,
 COUNT(*) AS total,
 ROUND(COUNT(CASE WHEN code LIKE 'E_%' OR code LIKE 'P_%' OR code LIKE 'T_%' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS pct
FROM op.structure
WHERE ecran = 'w_tiers';

-- ============================================================================
-- SECTION 3: Audit mapping table (records old->new mappings)
-- ============================================================================
SELECT
 'Mapping entries (ref_tables_modif)' AS metric,
 COUNT(*) AS total_mappings,
 COUNT(CASE WHEN table_name = 'tiers' THEN 1 END) AS tiers_mappings,
 COUNT(CASE WHEN table_name = 'compte_banque' THEN 1 END) AS cb_mappings
FROM atrace.ref_tables_modif;

-- ============================================================================
-- SECTION 4: Current session activity (what's it doing NOW)
-- Adjust SID/SERIAL# to match your running session
-- ============================================================================
-- Find the OP session:
SELECT s.sid, s.serial#, s.username, s.status, s.event,
 s.seconds_in_wait, s.sql_id,
 ROUND((SYSDATE - s.logon_time) * 24 * 60, 1) AS minutes_running
FROM v$session s
WHERE s.username = 'OP'
 AND s.status = 'ACTIVE'
ORDER BY s.logon_time;

-- Get the SQL it's currently executing (replace SQL_ID if needed):
-- SELECT sql_text FROM v$sql WHERE sql_id = '<sql_id_from_above>';

-- ============================================================================
-- SECTION 5: Description field progress (also anonymized by OP procedure)
-- The procedure sets description = '<PREFIX>' || random_number
-- ============================================================================
SELECT
 'Tiers descriptions anonymized' AS metric,
 COUNT(CASE WHEN REGEXP_LIKE(description, '^(E_|P_|T_)\d+') THEN 1 END) AS done,
 COUNT(CASE WHEN description IS NOT NULL THEN 1 END) AS total_with_desc
FROM op.tiers;

SELECT
 'Compte_banque descriptions anonymized' AS metric,
 COUNT(CASE WHEN REGEXP_LIKE(description, '^CB_\d+') THEN 1 END) AS done,
 COUNT(CASE WHEN description IS NOT NULL THEN 1 END) AS total_with_desc
FROM op.compte_banque;

-- ============================================================================
-- SECTION 6: Estimated time remaining
-- Based on elapsed time and progress percentage
-- ============================================================================
-- Run this manually: replace values from Section 1 + session minutes
-- Example: If CB is 73% done at 500 minutes, ETA = 500 * (100-73)/73 = 185 min
--
-- Quick formula (replace with actuals):
-- SELECT ROUND(<minutes_running> * (100 - <pct_done>) / NULLIF(<pct_done>, 0), 0) AS est_minutes_remaining FROM dual;