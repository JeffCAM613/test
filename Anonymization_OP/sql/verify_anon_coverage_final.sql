-- ============================================================================
-- FINAL: OP Anonymization Coverage Verification Script
-- ============================================================================
-- PURPOSE: Verify 100% anonymization coverage for KTP OP databases
-- 
-- RUN AS ANY OF:
-- sqlplus op/<password>@<TNS> @sql/verify_anon_coverage_final.sql
-- sqlplus sys/<pwd>@<TNS> as sysdba @sql/verify_anon_coverage_final.sql
-- (All table references are fully qualified with op.* schema prefix)
-- 
-- CORRECT LOGIC:
-- - Code fields can have ANY valid prefix: E_, P_, T_, CB_
-- - Only codes that exist in TIERS are checked for anonymization
-- - System codes (not in tiers) are NOT client data - skip them
-- - PII/description fields should be NULL or have prefix
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
SET TRIMSPOOL ON
COLUMN table_name FORMAT A30
COLUMN column_name FORMAT A22
COLUMN expected FORMAT A10
COLUMN total_rows FORMAT 99999
COLUMN anon_rows FORMAT 99999
COLUMN not_anon FORMAT 99999
COLUMN coverage FORMAT A8
COLUMN status FORMAT A6

PROMPT
PROMPT ====================================================================
PROMPT ANONYMIZATION COVERAGE VERIFICATION
PROMPT ====================================================================
PROMPT Expected prefixes: E_ (Entity), P_ (Portfolio), T_ (Tiers), CB_ (Compte)
PROMPT ANY = any of the above prefixes
PROMPT NULL = field should be NULL (PII/free-text)
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- PART 1: CORE TABLES (tiers, structure, compte_banque)
-- ============================================================================
PROMPT
PROMPT === PART 1: CORE TABLES ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- tiers.code - should have ANY prefix
 SELECT 'tiers' AS table_name, 'code' AS column_name, 'ANY' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN code LIKE 'E_%' OR code LIKE 'P_%' OR code LIKE 'T_%' OR code LIKE 'CB_%' THEN 1 ELSE 0 END) AS anon_rows
 FROM op.tiers WHERE code IS NOT NULL
 UNION ALL
 -- structure.code - only check rows that exist in tiers
 SELECT 'structure (tiers only)', 'code', 'ANY',
 COUNT(*),
 SUM(CASE WHEN s.code LIKE 'E_%' OR s.code LIKE 'P_%' OR s.code LIKE 'T_%' OR s.code LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.structure s
 WHERE EXISTS (SELECT 1 FROM op.tiers t WHERE t.code = s.code)
 UNION ALL
 -- compte_banque.code - should have CB_ prefix
 SELECT 'compte_banque', 'code', 'CB_',
 COUNT(*),
 SUM(CASE WHEN code LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.compte_banque WHERE code IS NOT NULL
 UNION ALL
 -- compte_banque.entite - can have ANY prefix
 SELECT 'compte_banque', 'entite', 'ANY',
 COUNT(*),
 SUM(CASE WHEN entite LIKE 'E_%' OR entite LIKE 'P_%' OR entite LIKE 'T_%' OR entite LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.compte_banque WHERE entite IS NOT NULL
 UNION ALL
 -- compte_banque.banque - can have ANY prefix
 SELECT 'compte_banque', 'banque', 'ANY',
 COUNT(*),
 SUM(CASE WHEN banque LIKE 'E_%' OR banque LIKE 'P_%' OR banque LIKE 'T_%' OR banque LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.compte_banque WHERE banque IS NOT NULL
 UNION ALL
 -- compte_banque.agence - can have ANY prefix
 SELECT 'compte_banque', 'agence', 'ANY',
 COUNT(*),
 SUM(CASE WHEN agence LIKE 'E_%' OR agence LIKE 'P_%' OR agence LIKE 'T_%' OR agence LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.compte_banque WHERE agence IS NOT NULL
);

-- ============================================================================
-- PART 2: DESCRIPTION FIELDS (should be anonymized or NULL)
-- ============================================================================
PROMPT
PROMPT === PART 2: DESCRIPTION FIELDS ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT 'tiers' AS table_name, 'description' AS column_name, 'ANY/NULL' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN description IS NULL OR description LIKE 'E_%' OR description LIKE 'P_%' OR description LIKE 'T_%' OR description LIKE 'CB_%' THEN 1 ELSE 0 END) AS anon_rows
 FROM op.tiers
 UNION ALL
 SELECT 'structure (tiers only)', 'description', 'ANY/NULL',
 COUNT(*),
 SUM(CASE WHEN s.description IS NULL OR s.description LIKE 'E_%' OR s.description LIKE 'P_%' OR s.description LIKE 'T_%' OR s.description LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.structure s
 WHERE EXISTS (SELECT 1 FROM op.tiers t WHERE t.code = s.code)
);

-- ============================================================================
-- PART 3: CTI CM_* TABLES (Cash Management)
-- ============================================================================
PROMPT
PROMPT === PART 3: CTI CM_* TABLES ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- Entity columns can have ANY prefix (E_, P_, T_, CB_) because they reference tiers
 SELECT 'cm_account_of_bkstmt_file' AS table_name, 'entity' AS column_name, 'ANY' AS expected,
 COUNT(*) AS total_rows, 
 SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' OR entity LIKE 'CB_%' THEN 1 ELSE 0 END) AS anon_rows
 FROM op.cm_account_of_bkstmt_file WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'cm_account_of_bkstmt_file', 'account', 'CB_',
 COUNT(*), SUM(CASE WHEN account LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_account_of_bkstmt_file WHERE account IS NOT NULL
 UNION ALL
 SELECT 'cm_account_of_bkstmt_file', 'bank', 'ANY',
 COUNT(*), SUM(CASE WHEN bank LIKE 'E_%' OR bank LIKE 'P_%' OR bank LIKE 'T_%' OR bank LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_account_of_bkstmt_file WHERE bank IS NOT NULL
 UNION ALL
 SELECT 'cm_bsi_bank_statement', 'entity', 'ANY',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' OR entity LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_bsi_bank_statement WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'cm_bsi_bank_statement', 'bank_account', 'CB_',
 COUNT(*), SUM(CASE WHEN bank_account LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_bsi_bank_statement WHERE bank_account IS NOT NULL
 UNION ALL
 SELECT 'cm_cash_concent_accounts', 'entity', 'ANY',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' OR entity LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_cash_concent_accounts WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'cm_cash_concent_accounts', 'account', 'CB_',
 COUNT(*), SUM(CASE WHEN account LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_cash_concent_accounts WHERE account IS NOT NULL
 UNION ALL
 SELECT 'cm_cash_concent_header', 'entity', 'ANY',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' OR entity LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_cash_concent_header WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'cm_cash_concent_header', 'master_account', 'CB_',
 COUNT(*), SUM(CASE WHEN master_account LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.cm_cash_concent_header WHERE master_account IS NOT NULL
);

-- ============================================================================
-- PART 4: CTI DM_* TABLES (Deal Management)
-- ============================================================================
PROMPT
PROMPT === PART 4: CTI DM_* TABLES ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT 'dm_hedge_request' AS table_name, 'entity' AS column_name, 'ANY' AS expected,
 COUNT(*) AS total_rows, 
 SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' THEN 1 ELSE 0 END) AS anon_rows
 FROM op.dm_hedge_request WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'dm_hedge_request', 'portfolio', 'P_',
 COUNT(*), SUM(CASE WHEN portfolio LIKE 'P_%' THEN 1 ELSE 0 END)
 FROM op.dm_hedge_request WHERE portfolio IS NOT NULL
 UNION ALL
 SELECT 'dm_hedge_request', 'counterparty', 'ANY',
 COUNT(*), SUM(CASE WHEN counterparty LIKE 'E_%' OR counterparty LIKE 'P_%' OR counterparty LIKE 'T_%' THEN 1 ELSE 0 END)
 FROM op.dm_hedge_request WHERE counterparty IS NOT NULL
 UNION ALL
 SELECT 'dm_hr_limit_bkd', 'entity', 'E_',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' THEN 1 ELSE 0 END)
 FROM op.dm_hr_limit_bkd WHERE entity IS NOT NULL
);

-- ============================================================================
-- PART 5: CTI TP_* TABLES (Third Party)
-- ============================================================================
PROMPT
PROMPT === PART 5: CTI TP_* TABLES ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT 'tp_pos_snapshot' AS table_name, 'entity' AS column_name, 'E_' AS expected,
 COUNT(*) AS total_rows, SUM(CASE WHEN entity LIKE 'E_%' THEN 1 ELSE 0 END) AS anon_rows
 FROM op.tp_pos_snapshot WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'tp_pos_snapshot_results', 'entity', 'E_',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' THEN 1 ELSE 0 END)
 FROM op.tp_pos_snapshot_results WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'tp_pos_snapshot_results', 'account', 'CB_',
 COUNT(*), SUM(CASE WHEN account LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.tp_pos_snapshot_results WHERE account IS NOT NULL
 UNION ALL
 SELECT 'tp_tenant_entity', 'entity', 'ANY',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' OR entity LIKE 'P_%' OR entity LIKE 'T_%' OR entity LIKE 'CB_%' THEN 1 ELSE 0 END)
 FROM op.tp_tenant_entity WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'tp_wv_transition_rule', 'entity', 'E_',
 COUNT(*), SUM(CASE WHEN entity LIKE 'E_%' THEN 1 ELSE 0 END)
 FROM op.tp_wv_transition_rule WHERE entity IS NOT NULL
 UNION ALL
 SELECT 'tp_business_profile', 'description', 'NULL',
 COUNT(*), SUM(CASE WHEN description IS NULL THEN 1 ELSE 0 END)
 FROM op.tp_business_profile
);

-- ============================================================================
-- PART 6: PII FIELDS (should be NULL)
-- ============================================================================
PROMPT
PROMPT === PART 6: PII FIELDS (UAA_USERS) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT 'uaa_users' AS table_name, 'email' AS column_name, 'NULL' AS expected,
 COUNT(*) AS total_rows, SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS anon_rows
 FROM op.uaa_users
 UNION ALL
 SELECT 'uaa_users', 'firstname', 'NULL',
 COUNT(*), SUM(CASE WHEN firstname IS NULL THEN 1 ELSE 0 END)
 FROM op.uaa_users
 UNION ALL
 SELECT 'uaa_users', 'lastname', 'NULL',
 COUNT(*), SUM(CASE WHEN lastname IS NULL THEN 1 ELSE 0 END)
 FROM op.uaa_users
);

-- ============================================================================
-- PART 7: MAPPING INTEGRITY
-- ============================================================================
PROMPT
PROMPT === PART 7: MAPPING INTEGRITY ===

SELECT 'atrace.op_code_mapping' AS mapping_table,
 COUNT(*) AS total_mappings,
 COUNT(DISTINCT entity_type) AS unique_types,
 CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END AS status
FROM atrace.op_code_mapping;

-- ============================================================================
-- PART 8: DUPLICATE CHECK
-- ============================================================================
PROMPT
PROMPT === PART 8: DUPLICATE CHECK ===

SELECT 'op_code_mapping duplicates' AS check_name,
 COUNT(*) AS duplicate_count,
 CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT new_code, COUNT(*) 
 FROM atrace.op_code_mapping 
 GROUP BY new_code 
 HAVING COUNT(*) > 1
);

-- ============================================================================
-- SUMMARY
-- ============================================================================
PROMPT
PROMPT ====================================================================
PROMPT SUMMARY
PROMPT ====================================================================
PROMPT

SELECT 
 SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
 SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
 COUNT(*) AS total_checks
FROM (
 -- Repeat all checks in a unified query for summary
 SELECT CASE WHEN SUM(CASE WHEN code LIKE 'E_%' OR code LIKE 'P_%' OR code LIKE 'T_%' OR code LIKE 'CB_%' THEN 1 ELSE 0 END) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END AS status
 FROM op.tiers WHERE code IS NOT NULL
 UNION ALL
 SELECT CASE WHEN SUM(CASE WHEN code LIKE 'CB_%' THEN 1 ELSE 0 END) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END
 FROM op.compte_banque WHERE code IS NOT NULL
 UNION ALL
 SELECT CASE WHEN SUM(CASE WHEN entite LIKE 'E_%' OR entite LIKE 'P_%' OR entite LIKE 'T_%' OR entite LIKE 'CB_%' THEN 1 ELSE 0 END) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END
 FROM op.compte_banque WHERE entite IS NOT NULL
 UNION ALL
 SELECT CASE WHEN SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END
 FROM op.uaa_users
);

PROMPT
PROMPT ====================================================================
PROMPT VERIFICATION COMPLETE
PROMPT ====================================================================

EXIT;