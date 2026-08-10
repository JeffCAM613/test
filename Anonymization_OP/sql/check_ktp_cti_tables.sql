-- ============================================================================
-- KTP/CTI Table Existence Check
-- ============================================================================
-- PURPOSE: Verify which tables from the KTP/CTI scope exist in this database
-- RUN AS: Any user with SELECT on DBA_TABLES or ALL_TABLES
-- ============================================================================

SET PAGESIZE 100
SET LINESIZE 150
SET HEADING ON
SET FEEDBACK OFF
COLUMN table_name FORMAT A35
COLUMN owner FORMAT A10
COLUMN exists_flag FORMAT A10

PROMPT
PROMPT ====================================================================
PROMPT KTP/CTI TABLE EXISTENCE CHECK
PROMPT ====================================================================
PROMPT

-- Check all tables from the reference list
SELECT 
 t.table_name AS "Table Name",
 CASE WHEN a.table_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS "Exists?",
 a.owner AS "Owner",
 a.num_rows AS "Row Count"
FROM (
 -- Tables from your reference
 SELECT 'CHARGE_CONTRACT_CRITERIA' AS table_name FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_PROCESS' FROM dual UNION ALL
 SELECT 'CHARGE_MISSING_PROCESS' FROM dual UNION ALL
 SELECT 'MPM_FILE_BKD' FROM dual UNION ALL
 SELECT 'TRADE_REPOSITORY_BREAKDOWN' FROM dual UNION ALL
 SELECT 'VAL_CPTYRATING' FROM dual UNION ALL
 SELECT 'VAL_CURRENCY_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP' FROM dual UNION ALL
 SELECT 'VAL_THIRD_PARTY_LIMIT' FROM dual UNION ALL
 SELECT 'VAL_USER' FROM dual UNION ALL
 -- Also check OP equivalents for comparison
 SELECT 'CTPYRATING' FROM dual UNION ALL
 SELECT 'VENTILER_CORRESP' FROM dual UNION ALL
 SELECT 'VENTILER_CORRESP_BQE' FROM dual
) t
LEFT JOIN all_tables a ON UPPER(a.table_name) = t.table_name
ORDER BY t.table_name;

PROMPT
PROMPT ====================================================================
PROMPT COLUMN COMPARISON: VAL_CPTYRATING vs CTPYRATING
PROMPT ====================================================================
PROMPT

-- Compare columns of val_cptyrating and ctpyrating
SELECT 
 'VAL_CPTYRATING' AS table_name,
 column_name,
 data_type,
 data_length
FROM all_tab_columns
WHERE UPPER(table_name) = 'VAL_CPTYRATING'
ORDER BY column_id;

SELECT 
 'CTPYRATING' AS table_name,
 column_name,
 data_type,
 data_length
FROM all_tab_columns
WHERE UPPER(table_name) = 'CTPYRATING'
ORDER BY column_id;

PROMPT
PROMPT ====================================================================
PROMPT COLUMN COMPARISON: VAL_SSI_CORRESP vs VENTILER_CORRESP
PROMPT ====================================================================
PROMPT

-- Compare columns of val_ssi_corresp and ventiler_corresp
SELECT 
 'VAL_SSI_CORRESP' AS table_name,
 column_name,
 data_type,
 data_length
FROM all_tab_columns
WHERE UPPER(table_name) = 'VAL_SSI_CORRESP'
ORDER BY column_id;

SELECT 
 'VENTILER_CORRESP' AS table_name,
 column_name,
 data_type,
 data_length
FROM all_tab_columns
WHERE UPPER(table_name) = 'VENTILER_CORRESP'
ORDER BY column_id;

PROMPT
PROMPT ====================================================================
PROMPT DETAILED COLUMN CHECK FOR ALL KTP/CTI TABLES
PROMPT ====================================================================
PROMPT

-- Check if specific columns exist in each table
SELECT 
 c.table_name,
 c.column_name,
 c.data_type,
 CASE 
 WHEN c.table_name IS NOT NULL THEN 'EXISTS'
 ELSE 'MISSING'
 END AS status
FROM (
 -- Expected table.column combinations from your reference
 SELECT 'CHARGE_CONTRACT_CRITERIA' AS tbl, 'ENTITY' AS col FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_CRITERIA', 'BANK' FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_CRITERIA', 'ACCOUNT' FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_PROCESS', 'ENTITY' FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_PROCESS', 'BANK' FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_PROCESS', 'ACCOUNT' FROM dual UNION ALL
 SELECT 'CHARGE_MISSING_PROCESS', 'ENTITY' FROM dual UNION ALL
 SELECT 'CHARGE_MISSING_PROCESS', 'BANK' FROM dual UNION ALL
 SELECT 'CHARGE_MISSING_PROCESS', 'ACCOUNT' FROM dual UNION ALL
 SELECT 'MPM_FILE_BKD', 'ENTITY' FROM dual UNION ALL
 SELECT 'MPM_FILE_BKD', 'COUNTERPARTY' FROM dual UNION ALL
 SELECT 'MPM_FILE_BKD', 'ACCOUNT' FROM dual UNION ALL
 SELECT 'TRADE_REPOSITORY_BREAKDOWN', 'ENTITY' FROM dual UNION ALL
 SELECT 'VAL_CPTYRATING', 'COUNTERPARTY' FROM dual UNION ALL
 SELECT 'VAL_CURRENCY_ACCOUNT', 'ENTITY' FROM dual UNION ALL
 SELECT 'VAL_CURRENCY_ACCOUNT', 'COMPTE' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'ENTITE' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'DEPOSITAIRE' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'NUMERO_COMPTE' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'GROUPE_1' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'GROUPE_2' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'GROUPE_3' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'CORRESPONDANT' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT', 'CONTREPARTIE' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT', 'PORTEFEUILLE' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT', 'DEPOSITAIRE' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT', 'COMPTE' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT', 'TIERS_ENTITE' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP', 'BANQUE' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP', 'CONTREPARTIE' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP', 'CORRESPONDANT_1' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP', 'CORRESPONDANT_2' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP', 'TIERS_ENTITE' FROM dual UNION ALL
 SELECT 'VAL_THIRD_PARTY_LIMIT', 'ENTITE' FROM dual UNION ALL
 SELECT 'VAL_THIRD_PARTY_LIMIT', 'TIERS' FROM dual UNION ALL
 SELECT 'VAL_USER', 'DESCRIPTION' FROM dual
) expected
LEFT JOIN all_tab_columns c 
 ON UPPER(c.table_name) = expected.tbl 
 AND UPPER(c.column_name) = expected.col
ORDER BY expected.tbl, expected.col;

PROMPT
PROMPT ====================================================================
PROMPT QUICK SUMMARY: Which KTP/CTI tables need to be added?
PROMPT ====================================================================
PROMPT

-- Final summary
SELECT 
 t.table_name,
 CASE WHEN a.table_name IS NOT NULL THEN 'EXISTS - NEEDS ANONYMIZATION' 
 ELSE 'DOES NOT EXIST - SKIP' 
 END AS action_required
FROM (
 SELECT 'CHARGE_CONTRACT_CRITERIA' AS table_name FROM dual UNION ALL
 SELECT 'CHARGE_CONTRACT_PROCESS' FROM dual UNION ALL
 SELECT 'CHARGE_MISSING_PROCESS' FROM dual UNION ALL
 SELECT 'MPM_FILE_BKD' FROM dual UNION ALL
 SELECT 'TRADE_REPOSITORY_BREAKDOWN' FROM dual UNION ALL
 SELECT 'VAL_CPTYRATING' FROM dual UNION ALL
 SELECT 'VAL_CURRENCY_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SECURITY_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SSI_ACCOUNT' FROM dual UNION ALL
 SELECT 'VAL_SSI_CORRESP' FROM dual UNION ALL
 SELECT 'VAL_THIRD_PARTY_LIMIT' FROM dual UNION ALL
 SELECT 'VAL_USER' FROM dual
) t
LEFT JOIN all_tables a ON UPPER(a.table_name) = t.table_name
ORDER BY t.table_name;

EXIT;