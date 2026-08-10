-- ============================================================================
-- FINAL: EPF/OPPAYMENTS Anonymization Coverage Verification Script
-- ============================================================================
-- PURPOSE: Verify 100% anonymization coverage for EPF databases
-- 
-- RUN AS ANY OF:
-- sqlplus oppayments/<password>@<TNS> @sql/verify_epf_anon_coverage_final.sql
-- sqlplus op/<password>@<TNS> @sql/verify_epf_anon_coverage_final.sql
-- sqlplus sys/<pwd>@<TNS> as sysdba @sql/verify_epf_anon_coverage_final.sql
-- (All table references are fully qualified with oppayments.*/atrace.* schema prefixes)
--
-- EXPECTED PATTERNS:
-- admin_user.code -> USR_XXXXXXX
-- admin_user.first_name -> FirstName_XXXXXXX
-- admin_user.last_name -> LastName_XXXXXXX
-- admin_user.email -> usr_XXXXXXX@example.com (or NULL)
-- admin_user.phone -> PHONE_XXXXXXX (or NULL)
-- payment.*_code -> E_/P_/T_/CB_ (from OP tiers/compte_banque)
-- payment.benef_desc -> BENEF_XXXXXXX (or NULL)
-- ref_tiers.description -> TIER_X
-- BIC components -> Random 4/2/2/3 char codes in epf_anonymization_map
-- payment_audit.user_id -> USR_XXXXXXX OR system user (INTERFACE, etc.)
-- ============================================================================

SET PAGESIZE 500
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
SET TRIMSPOOL ON
COLUMN table_name FORMAT A35
COLUMN column_name FORMAT A25
COLUMN expected FORMAT A20
COLUMN total_rows FORMAT 999999999
COLUMN anon_rows FORMAT 999999999
COLUMN not_anon FORMAT 999999999
COLUMN coverage FORMAT A8
COLUMN status FORMAT A6

PROMPT
PROMPT ====================================================================
PROMPT EPF ANONYMIZATION COVERAGE VERIFICATION
PROMPT ====================================================================
PROMPT Run on: any KTP EPF instance
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- PART 1: ADMIN_USER - User account anonymization
-- ============================================================================
PROMPT
PROMPT === PART 1: ADMIN_USER (User Accounts) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- admin_user.code -> USR_
 SELECT 'admin_user' AS table_name, 'code' AS column_name, 'USR_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN code LIKE 'USR\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.first_name -> FirstName_
 SELECT 'admin_user', 'first_name', 'FirstName_',
 COUNT(*),
 SUM(CASE WHEN first_name LIKE 'FirstName\_%' ESCAPE '\' OR first_name IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.last_name -> LastName_
 SELECT 'admin_user', 'last_name', 'LastName_',
 COUNT(*),
 SUM(CASE WHEN last_name LIKE 'LastName\_%' ESCAPE '\' OR last_name IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.email -> usr_@example.com or NULL
 SELECT 'admin_user', 'email', 'usr_@example.com/NULL',
 COUNT(*),
 SUM(CASE WHEN email LIKE 'usr\_%@example.com' ESCAPE '\' OR email IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.phone -> PHONE_ or NULL
 SELECT 'admin_user', 'phone', 'PHONE_/NULL',
 COUNT(*),
 SUM(CASE WHEN phone LIKE 'PHONE\_%' ESCAPE '\' OR phone IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.addr_line1 -> Addr1_ or NULL (anonymized or nullified)
 SELECT 'admin_user', 'addr_line1', 'Addr1_/NULL',
 COUNT(*),
 SUM(CASE WHEN addr_line1 LIKE 'Addr1\_%' ESCAPE '\' OR addr_line1 IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.user_creation -> USR_ or BATCH (system user)
 SELECT 'admin_user', 'user_creation', 'USR_/BATCH/NULL',
 COUNT(*),
 SUM(CASE WHEN user_creation LIKE 'USR\_%' ESCAPE '\' OR user_creation = 'BATCH' OR user_creation IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
 UNION ALL
 -- admin_user.user_last_modif -> USR_ or BATCH (system user)
 SELECT 'admin_user', 'user_last_modif', 'USR_/BATCH/NULL',
 COUNT(*),
 SUM(CASE WHEN user_last_modif LIKE 'USR\_%' ESCAPE '\' OR user_last_modif = 'BATCH' OR user_last_modif IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.admin_user
);

-- ============================================================================
-- PART 2: PAYMENT - Code fields (cascaded from OP)
-- ============================================================================
PROMPT
PROMPT === PART 2: PAYMENT (Code Fields) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 CASE WHEN total_rows = 0 THEN 'N/A' ELSE ROUND(anon_rows * 100.0 / total_rows, 0) || '%' END AS coverage,
 CASE WHEN total_rows = 0 THEN 'N/A' WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- entity_code -> E_/P_/T_
 SELECT 'payment' AS table_name, 'entity_code' AS column_name, 'E_/P_/T_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN entity_code LIKE 'E\_%' ESCAPE '\' OR entity_code LIKE 'P\_%' ESCAPE '\' OR entity_code LIKE 'T\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.payment WHERE entity_code IS NOT NULL
 UNION ALL
 -- beneficiary_code -> E_/P_/T_
 SELECT 'payment', 'beneficiary_code', 'E_/P_/T_',
 COUNT(*),
 SUM(CASE WHEN beneficiary_code LIKE 'E\_%' ESCAPE '\' OR beneficiary_code LIKE 'P\_%' ESCAPE '\' OR beneficiary_code LIKE 'T\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE beneficiary_code IS NOT NULL
 UNION ALL
 -- portfolio_code -> P_
 SELECT 'payment', 'portfolio_code', 'P_',
 COUNT(*),
 SUM(CASE WHEN portfolio_code LIKE 'P\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE portfolio_code IS NOT NULL
 UNION ALL
 -- entity_account_code -> CB_
 SELECT 'payment', 'entity_account_code', 'CB_',
 COUNT(*),
 SUM(CASE WHEN entity_account_code LIKE 'CB\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE entity_account_code IS NOT NULL
 UNION ALL
 -- benef_account_code -> CB_
 SELECT 'payment', 'benef_account_code', 'CB_',
 COUNT(*),
 SUM(CASE WHEN benef_account_code LIKE 'CB\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE benef_account_code IS NOT NULL
 UNION ALL
 -- subsidiary_code -> E_/P_/T_
 SELECT 'payment', 'subsidiary_code', 'E_/P_/T_/NULL',
 COUNT(*),
 SUM(CASE WHEN subsidiary_code LIKE 'E\_%' ESCAPE '\' OR subsidiary_code LIKE 'P\_%' ESCAPE '\' OR subsidiary_code LIKE 'T\_%' ESCAPE '\' OR subsidiary_code IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE subsidiary_code IS NOT NULL
 UNION ALL
 -- final_corresp_code -> E_/P_/T_
 SELECT 'payment', 'final_corresp_code', 'E_/P_/T_/NULL',
 COUNT(*),
 SUM(CASE WHEN final_corresp_code LIKE 'E\_%' ESCAPE '\' OR final_corresp_code LIKE 'P\_%' ESCAPE '\' OR final_corresp_code LIKE 'T\_%' ESCAPE '\' OR final_corresp_code IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE final_corresp_code IS NOT NULL
 UNION ALL
 -- interm_corresp_code -> E_/P_/T_
 SELECT 'payment', 'interm_corresp_code', 'E_/P_/T_/NULL',
 COUNT(*),
 SUM(CASE WHEN interm_corresp_code LIKE 'E\_%' ESCAPE '\' OR interm_corresp_code LIKE 'P\_%' ESCAPE '\' OR interm_corresp_code LIKE 'T\_%' ESCAPE '\' OR interm_corresp_code IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE interm_corresp_code IS NOT NULL
);

-- ============================================================================
-- PART 3: PAYMENT - Free-text fields (descriptions, addresses)
-- ============================================================================
PROMPT
PROMPT === PART 3: PAYMENT (Free-Text Fields) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 CASE WHEN total_rows = 0 THEN 'N/A' ELSE ROUND(anon_rows * 100.0 / total_rows, 0) || '%' END AS coverage,
 CASE WHEN total_rows = 0 THEN 'N/A' WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- benef_description -> BENEF_
 SELECT 'payment' AS table_name, 'benef_description' AS column_name, 'BENEF_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN benef_description LIKE 'BENEF\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.payment WHERE benef_description IS NOT NULL
 UNION ALL
 -- final_corresp_description -> FC_
 SELECT 'payment', 'final_corresp_description', 'FC_',
 COUNT(*),
 SUM(CASE WHEN final_corresp_description LIKE 'FC\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE final_corresp_description IS NOT NULL
 UNION ALL
 -- interm_corresp_description -> IC_
 SELECT 'payment', 'interm_corresp_description', 'IC_',
 COUNT(*),
 SUM(CASE WHEN interm_corresp_description LIKE 'IC\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE interm_corresp_description IS NOT NULL
 UNION ALL
 -- benef_bank_description -> BBANK_
 SELECT 'payment', 'benef_bank_description', 'BBANK_',
 COUNT(*),
 SUM(CASE WHEN benef_bank_description LIKE 'BBANK\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE benef_bank_description IS NOT NULL
 UNION ALL
 -- payment_short_comment -> COMMENT_ or NULL
 SELECT 'payment', 'payment_short_comment', 'COMMENT_/NULL',
 COUNT(*),
 SUM(CASE WHEN payment_short_comment LIKE 'COMMENT\_%' ESCAPE '\' OR payment_short_comment IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.payment WHERE payment_short_comment IS NOT NULL
);

-- ============================================================================
-- PART 4: BULK_PAYMENT - Code fields
-- Note: portfolio_code may have legacy/orphan codes anonymized as P_<code>_ORPHAN
-- ============================================================================
PROMPT
PROMPT === PART 4: BULK_PAYMENT (Code Fields) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 CASE WHEN total_rows = 0 THEN 'N/A' ELSE ROUND(anon_rows * 100.0 / total_rows, 0) || '%' END AS coverage,
 CASE 
 WHEN total_rows = 0 THEN 'N/A'
 WHEN anon_rows = total_rows THEN 'PASS' 
 ELSE 'FAIL' 
 END AS status
FROM (
 -- entity_code -> E_/P_/T_
 SELECT 'bulk_payment' AS table_name, 'entity_code' AS column_name, 'E_/P_/T_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN entity_code LIKE 'E\_%' ESCAPE '\' OR entity_code LIKE 'P\_%' ESCAPE '\' OR entity_code LIKE 'T\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.bulk_payment WHERE entity_code IS NOT NULL
 UNION ALL
 -- entity_account_code -> CB_
 SELECT 'bulk_payment', 'entity_account_code', 'CB_',
 COUNT(*),
 SUM(CASE WHEN entity_account_code LIKE 'CB\_%' ESCAPE '\' THEN 1 ELSE 0 END)
 FROM oppayments.bulk_payment WHERE entity_account_code IS NOT NULL
 UNION ALL
 -- portfolio_code -> P_ (including P_*_ORPHAN for legacy codes)
 SELECT 'bulk_payment', 'portfolio_code', 'P_/P_*_ORPHAN/NULL',
 COUNT(*),
 SUM(CASE WHEN portfolio_code LIKE 'P\_%' ESCAPE '\' OR portfolio_code IS NULL THEN 1 ELSE 0 END)
 FROM oppayments.bulk_payment WHERE portfolio_code IS NOT NULL
);

-- ============================================================================
-- PART 5: APPROBATION - User cascades
-- ============================================================================
PROMPT
PROMPT === PART 5: USER CASCADES (approbation) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 CASE WHEN total_rows = 0 THEN 'N/A' ELSE ROUND(anon_rows * 100.0 / total_rows, 0) || '%' END AS coverage,
 CASE WHEN total_rows = 0 THEN 'N/A' WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- approbation_group_users.user_id -> USR_
 SELECT 'approbation_group_users' AS table_name, 'user_id' AS column_name, 'USR_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN user_id LIKE 'USR\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.approbation_group_users WHERE user_id IS NOT NULL
);

-- ============================================================================
-- PART 6: PAYMENT_AUDIT - User IDs (system users are expected)
-- ============================================================================
PROMPT
PROMPT === PART 6: PAYMENT_AUDIT (User IDs) ===
PROMPT Note: System users (INTERFACE, AFB160LCR, Swift Agt, PAIN*, etc.) are NOT anonymized - expected.

SELECT 'payment_audit' AS table_name, 'user_id' AS column_name,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN user_id LIKE 'USR\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS usr_anon,
 SUM(CASE WHEN user_id NOT LIKE 'USR\_%' ESCAPE '\' 
 AND EXISTS (SELECT 1 FROM oppayments.admin_user au WHERE au.code = payment_audit.user_id) THEN 1 ELSE 0 END) AS admin_leaked,
 SUM(CASE WHEN user_id NOT LIKE 'USR\_%' ESCAPE '\' 
 AND NOT EXISTS (SELECT 1 FROM oppayments.admin_user au WHERE au.code = payment_audit.user_id) THEN 1 ELSE 0 END) AS system_users,
 CASE 
 WHEN SUM(CASE WHEN user_id NOT LIKE 'USR\_%' ESCAPE '\' 
 AND EXISTS (SELECT 1 FROM oppayments.admin_user au WHERE au.code = payment_audit.user_id) THEN 1 ELSE 0 END) = 0 
 THEN 'PASS' ELSE 'FAIL' 
 END AS status
FROM oppayments.payment_audit WHERE user_id IS NOT NULL;

-- ============================================================================
-- PART 7: REF_TIERS - Reference data
-- ============================================================================
PROMPT
PROMPT === PART 7: REF_TIERS (Reference Data) ===

SELECT table_name, column_name, expected, total_rows, anon_rows, 
 total_rows - anon_rows AS not_anon,
 ROUND(anon_rows * 100.0 / NULLIF(total_rows,0), 0) || '%' AS coverage,
 CASE WHEN anon_rows = total_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 -- ref_tiers.description -> TIER_
 SELECT 'ref_tiers' AS table_name, 'description' AS column_name, 'TIER_' AS expected,
 COUNT(*) AS total_rows,
 SUM(CASE WHEN description LIKE 'TIER\_%' ESCAPE '\' OR description LIKE 'REF\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS anon_rows
 FROM oppayments.ref_tiers WHERE description IS NOT NULL
);

-- ============================================================================
-- PART 8: BIC Component Mappings (summary)
-- ============================================================================
PROMPT
PROMPT === PART 8: BIC COMPONENT MAPPINGS ===

SELECT component_type, COUNT(*) AS mappings,
 CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END AS status
FROM atrace.epf_anonymization_map
GROUP BY component_type
ORDER BY component_type;

-- ============================================================================
-- PART 9: Mapping Integrity Checks
-- ============================================================================
PROMPT
PROMPT === PART 9: MAPPING INTEGRITY ===

SELECT 'atrace.ref_tables_modif_epf' AS mapping_table,
 COUNT(*) AS total_mappings,
 COUNT(DISTINCT table_name || '.' || field_name) AS unique_columns,
 CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END AS status
FROM atrace.ref_tables_modif_epf;

SELECT 'atrace.epf_anonymization_map' AS mapping_table,
 COUNT(*) AS total_mappings,
 COUNT(DISTINCT component_type) AS unique_types,
 CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'WARN' END AS status
FROM atrace.epf_anonymization_map;

-- ============================================================================
-- PART 10: Duplicate new_code check (should be 0)
-- ============================================================================
PROMPT
PROMPT === PART 10: DUPLICATE CHECK ===

SELECT 'ref_tables_modif_epf duplicates' AS check_name,
 COUNT(*) AS duplicate_count,
 CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT new_value, COUNT(*) 
 FROM atrace.ref_tables_modif_epf 
 WHERE field_name = 'CODE'
 GROUP BY new_value 
 HAVING COUNT(*) > 1
);

-- Note: Same-type duplicates should NOT occur with uniqueness-checked generation
-- If duplicates appear, indicates a bug in gen_unique_bic function
SELECT 'epf_anonymization_map (same-type)' AS check_name,
 COUNT(*) AS duplicate_count,
 CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
 SELECT component_type, anonymized_value, COUNT(*) 
 FROM atrace.epf_anonymization_map 
 GROUP BY component_type, anonymized_value 
 HAVING COUNT(*) > 1
);

-- ============================================================================
-- SUMMARY
-- ============================================================================
PROMPT
PROMPT ====================================================================
PROMPT EXPECTED RESULTS:
PROMPT ====================================================================
PROMPT PART 1 (admin_user): All 100% PASS
PROMPT PART 2 (payment codes): All 100% PASS
PROMPT PART 3 (free-text): All 100% PASS (or N/A if no data)
PROMPT PART 4 (bulk_payment): All 100% PASS (orphans get P_*_ORPHAN)
PROMPT PART 5 (user cascades): All 100% PASS
PROMPT PART 6 (payment_audit): admin_leaked = 0 (system_users expected)
PROMPT PART 7 (ref_tiers): 100% PASS
PROMPT PART 8 (BIC): All PASS (mappings > 0)
PROMPT PART 9 (mapping): Total mappings > 0
PROMPT PART 10 (duplicates): Both = 0 PASS (duplicates now prevented)
PROMPT ====================================================================
PROMPT

EXIT;