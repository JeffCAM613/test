-- ============================================================================
-- EPF/OPPAYMENTS Anonymization - Iteration 1
-- Based on OP anonymization values from atrace.ref_tables_modif
-- ============================================================================
-- FEATURES:
-- - Batched UPDATEs (one per table instead of one per field)
-- - Per-step error handling with SAVEPOINT
-- - Live logging via atrace.log_anon_entry (autonomous transaction)
-- - Fully re-runnable (idempotent - already-anonymized rows won't re-match)
-- - All OPPAYMENTS triggers disabled during execution
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

-- Generate run_id for this execution (shared across all blocks)
VARIABLE g_run_id VARCHAR2(32)
BEGIN
 SELECT RAWTOHEX(SYS_GUID()) INTO :g_run_id FROM dual;
END;
/

-- ============================================================================
-- PRE-RUN SNAPSHOT: Show current state before any changes
-- ============================================================================
DECLARE
 v_pay NUMBER; v_bulk NUMBER; v_ent NUMBER; v_ben NUMBER; v_acct NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_pay FROM oppayments.payment;
 SELECT COUNT(*) INTO v_bulk FROM oppayments.bulk_payment;
 SELECT COUNT(CASE WHEN entity_code IS NOT NULL THEN 1 END) INTO v_ent FROM oppayments.payment;
 SELECT COUNT(CASE WHEN beneficiary_code IS NOT NULL THEN 1 END) INTO v_ben FROM oppayments.payment;
 SELECT COUNT(CASE WHEN entity_account_code IS NOT NULL THEN 1 END) INTO v_acct FROM oppayments.payment;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE('+================================================================+');
 DBMS_OUTPUT.PUT_LINE('| PRE-RUN STATE (before ITR1) |');
 DBMS_OUTPUT.PUT_LINE('+================================================================+');
 DBMS_OUTPUT.PUT_LINE('| payment rows: ' || LPAD(v_pay, 12) || ' |');
 DBMS_OUTPUT.PUT_LINE('| bulk_payment rows: ' || LPAD(v_bulk, 12) || ' |');
 DBMS_OUTPUT.PUT_LINE('| payment.entity_code: ' || LPAD(v_ent, 12) || ' (to be cascaded) |');
 DBMS_OUTPUT.PUT_LINE('| payment.beneficiary_code: ' || LPAD(v_ben, 12) || ' (to be cascaded) |');
 DBMS_OUTPUT.PUT_LINE('| payment.entity_acct_code: ' || LPAD(v_acct, 12) || ' (to be cascaded) |');
 DBMS_OUTPUT.PUT_LINE('+================================================================+');
 DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- STEP 0: Disable all OPPAYMENTS triggers
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER := 0;
BEGIN
 atrace.log_anon_entry(v_run_id, 'ORCHESTRATOR', 'RUN_START', p_status => 'INFO',
 p_message => 'EPF Anonymization Iteration 1 starting');

 FOR rec IN (SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED') LOOP
 EXECUTE IMMEDIATE 'ALTER TRIGGER ' || rec.trigger_name || ' DISABLE';
 v_count := v_count + 1;
 END LOOP;

 atrace.log_anon_entry(v_run_id, 'TRIGGERS', 'DISABLE', p_status => 'SUCCESS',
 p_step_number => 0, p_rows_affected => v_count,
 p_message => v_count || ' triggers disabled');
 DBMS_OUTPUT.PUT_LINE('Step 0: Disabled ' || v_count || ' OPPAYMENTS triggers');
EXCEPTION
 WHEN OTHERS THEN
 atrace.log_anon_entry(v_run_id, 'TRIGGERS', 'DISABLE', p_status => 'ERROR',
 p_step_number => 0, p_error_code => SQLCODE, p_error_message => SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 1: Anonymize PAYMENT table (all code fields in one UPDATE)
-- Maps: entity_code, beneficiary_code, portfolio_code, final_corresp_code,
-- interm_corresp_code, subsidiary_code from tiers.code
-- benef_account_code, entity_account_code, subsidiary_account_code from compte_banque.code
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step1_start;

 atrace.log_anon_entry(v_run_id, 'PAYMENT', 'PHASE_START', p_table_name => 'PAYMENT',
 p_step_number => 1, p_status => 'INFO', p_message => 'Anonymizing payment code fields');

 UPDATE oppayments.payment p
 SET
 entity_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.entity_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.entity_code),
 beneficiary_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.beneficiary_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.beneficiary_code),
 portfolio_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.portfolio_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.portfolio_code),
 final_corresp_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.final_corresp_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.final_corresp_code),
 interm_corresp_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.interm_corresp_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.interm_corresp_code),
 subsidiary_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.subsidiary_code AND a.table_name = 'tiers' AND a.field_name = 'code'), p.subsidiary_code),
 benef_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.benef_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), p.benef_account_code),
 entity_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.entity_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), p.entity_account_code),
 subsidiary_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = p.subsidiary_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), p.subsidiary_account_code)
 WHERE EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif a
 WHERE a.field_name = 'code'
 AND ((a.table_name = 'tiers' AND a.old_value IN (p.entity_code, p.beneficiary_code, p.portfolio_code, p.final_corresp_code, p.interm_corresp_code, p.subsidiary_code))
 OR (a.table_name = 'compte_banque' AND a.old_value IN (p.benef_account_code, p.entity_account_code, p.subsidiary_account_code)))
 );

 v_count := SQL%ROWCOUNT;

 -- Audit trail: log mappings applied to payment table
 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'payment', 'CODE (tiers)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'tiers' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'payment' AND e.field_name = 'CODE (tiers)' AND e.old_value = a.old_value);

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'payment', 'CODE (compte_banque)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'compte_banque' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'payment' AND e.field_name = 'CODE (compte_banque)' AND e.old_value = a.old_value);

 COMMIT;

 atrace.log_anon_entry(v_run_id, 'PAYMENT', 'ANONYMIZE', p_table_name => 'PAYMENT',
 p_step_number => 1, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' payment rows anonymized (9 code fields)',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 1: payment - ' || v_count || ' rows updated (9 code fields batched)');
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(' +-- PAYMENT CODE COVERAGE ------------------------------------+');
 -- Quick verification of entity_code
 DECLARE
 v_mapped NUMBER; v_unmapped NUMBER;
 BEGIN
 SELECT COUNT(CASE WHEN entity_code LIKE 'E_%' OR entity_code LIKE 'P_%' OR entity_code LIKE 'T_%' OR entity_code LIKE 'CB_%' THEN 1 END),
 COUNT(CASE WHEN entity_code NOT LIKE 'E_%' AND entity_code NOT LIKE 'P_%' AND entity_code NOT LIKE 'T_%' AND entity_code NOT LIKE 'CB_%' THEN 1 END)
 INTO v_mapped, v_unmapped
 FROM oppayments.payment WHERE entity_code IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' | entity_code Anonymized: ' || LPAD(v_mapped,9) || ' Original: ' || LPAD(v_unmapped,9) || ' |');
 END;
 DECLARE
 v_mapped NUMBER; v_unmapped NUMBER;
 BEGIN
 SELECT COUNT(CASE WHEN entity_account_code LIKE 'CB_%' THEN 1 END),
 COUNT(CASE WHEN entity_account_code NOT LIKE 'CB_%' THEN 1 END)
 INTO v_mapped, v_unmapped
 FROM oppayments.payment WHERE entity_account_code IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' | entity_acct_code Anonymized: ' || LPAD(v_mapped,9) || ' Original: ' || LPAD(v_unmapped,9) || ' |');
 END;
 DECLARE
 v_mapped NUMBER; v_unmapped NUMBER;
 BEGIN
 SELECT COUNT(CASE WHEN beneficiary_code LIKE 'E_%' OR beneficiary_code LIKE 'P_%' OR beneficiary_code LIKE 'T_%' THEN 1 END),
 COUNT(CASE WHEN beneficiary_code NOT LIKE 'E_%' AND beneficiary_code NOT LIKE 'P_%' AND beneficiary_code NOT LIKE 'T_%' THEN 1 END)
 INTO v_mapped, v_unmapped
 FROM oppayments.payment WHERE beneficiary_code IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' | beneficiary_code Anonymized: ' || LPAD(v_mapped,9) || ' Original: ' || LPAD(v_unmapped,9) || ' |');
 END;
 DBMS_OUTPUT.PUT_LINE(' +-------------------------------------------------------------+');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step1_start;
 atrace.log_anon_entry(v_run_id, 'PAYMENT', 'ERROR', p_table_name => 'PAYMENT',
 p_step_number => 1, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 1 (payment): ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 2: Anonymize BULK_PAYMENT table (all code fields in one UPDATE)
-- Maps: entity_code, entity_bank_code, portfolio_code from tiers.code
-- entity_account_code from compte_banque.code
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step2_start;

 atrace.log_anon_entry(v_run_id, 'BULK_PAYMENT', 'PHASE_START', p_table_name => 'BULK_PAYMENT',
 p_step_number => 2, p_status => 'INFO', p_message => 'Anonymizing bulk_payment code fields');

 UPDATE oppayments.bulk_payment b
 SET
 entity_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = b.entity_code AND a.table_name = 'tiers' AND a.field_name = 'code'), b.entity_code),
 entity_bank_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = b.entity_bank_code AND a.table_name = 'tiers' AND a.field_name = 'code'), b.entity_bank_code),
 portfolio_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = b.portfolio_code AND a.table_name = 'tiers' AND a.field_name = 'code'), b.portfolio_code),
 entity_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = b.entity_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), b.entity_account_code)
 WHERE EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif a
 WHERE a.field_name = 'code'
 AND ((a.table_name = 'tiers' AND a.old_value IN (b.entity_code, b.entity_bank_code, b.portfolio_code))
 OR (a.table_name = 'compte_banque' AND a.old_value = b.entity_account_code))
 );

 v_count := SQL%ROWCOUNT;

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'bulk_payment', 'CODE (tiers)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'tiers' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'bulk_payment' AND e.field_name = 'CODE (tiers)' AND e.old_value = a.old_value);

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'bulk_payment', 'CODE (compte_banque)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'compte_banque' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'bulk_payment' AND e.field_name = 'CODE (compte_banque)' AND e.old_value = a.old_value);

 COMMIT;

 atrace.log_anon_entry(v_run_id, 'BULK_PAYMENT', 'ANONYMIZE', p_table_name => 'BULK_PAYMENT',
 p_step_number => 2, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' bulk_payment rows anonymized (4 code fields)',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 2: bulk_payment - ' || v_count || ' rows updated (4 code fields batched)');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step2_start;
 atrace.log_anon_entry(v_run_id, 'BULK_PAYMENT', 'ERROR', p_table_name => 'BULK_PAYMENT',
 p_step_number => 2, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 2 (bulk_payment): ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 2B: Fix orphan portfolio_code values in BULK_PAYMENT
-- Some portfolio codes (SD, HPE, HEIWA, etc.) may not exist in OP tiers mapping
-- These are anonymized with P_<code>_ORPHAN prefix
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step2b_start;

 -- Update orphan portfolio_code values (not starting with P_ and not NULL)
 UPDATE oppayments.bulk_payment b
 SET portfolio_code = 'P_' || portfolio_code || '_ORPHAN'
 WHERE portfolio_code IS NOT NULL
 AND portfolio_code NOT LIKE 'P\_%' ESCAPE '\'
 AND NOT EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'tiers' AND a.field_name = 'code'
 AND a.old_value = b.portfolio_code
 );

 v_count := SQL%ROWCOUNT;

 IF v_count > 0 THEN
 -- Log the orphan mappings
 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT DISTINCT 'bulk_payment', 'PORTFOLIO_CODE (orphan)', 
 REPLACE(portfolio_code, 'P_', ''), -- Extract original code
 portfolio_code
 FROM oppayments.bulk_payment
 WHERE portfolio_code LIKE 'P\_%\_ORPHAN' ESCAPE '\'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'bulk_payment' 
 AND e.field_name = 'PORTFOLIO_CODE (orphan)'
 AND e.new_value = portfolio_code);
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('Step 2B: bulk_payment.portfolio_code - ' || v_count || ' orphan rows fixed (P_<code>_ORPHAN)');
 ELSE
 DBMS_OUTPUT.PUT_LINE('Step 2B: bulk_payment.portfolio_code - no orphans found');
 END IF;

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step2b_start;
 DBMS_OUTPUT.PUT_LINE('ERROR Step 2B (bulk_payment orphan fix): ' || SQLERRM);
 -- Non-fatal: continue even if this fails
END;
/

-- ============================================================================
-- STEP 3: Anonymize ADMIN_TEMPLATE table (all code fields in one UPDATE)
-- Maps: entity_code, beneficiary_code, portfolio_code, final_corresp_code,
-- interm_corresp_code, subsidiary_code from tiers.code
-- benef_account_code, entity_account_code, subsidiary_account_code from compte_banque.code
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step3_start;

 atrace.log_anon_entry(v_run_id, 'ADMIN_TEMPLATE', 'PHASE_START', p_table_name => 'ADMIN_TEMPLATE',
 p_step_number => 3, p_status => 'INFO', p_message => 'Anonymizing admin_template code fields');

 UPDATE oppayments.admin_template ad
 SET
 entity_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.entity_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.entity_code),
 beneficiary_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.beneficiary_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.beneficiary_code),
 portfolio_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.portfolio_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.portfolio_code),
 final_corresp_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.final_corresp_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.final_corresp_code),
 interm_corresp_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.interm_corresp_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.interm_corresp_code),
 subsidiary_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.subsidiary_code AND a.table_name = 'tiers' AND a.field_name = 'code'), ad.subsidiary_code),
 benef_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.benef_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), ad.benef_account_code),
 entity_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.entity_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), ad.entity_account_code),
 subsidiary_account_code = NVL((SELECT a.new_value FROM atrace.ref_tables_modif a WHERE a.old_value = ad.subsidiary_account_code AND a.table_name = 'compte_banque' AND a.field_name = 'code'), ad.subsidiary_account_code)
 WHERE EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif a
 WHERE a.field_name = 'code'
 AND ((a.table_name = 'tiers' AND a.old_value IN (ad.entity_code, ad.beneficiary_code, ad.portfolio_code, ad.final_corresp_code, ad.interm_corresp_code, ad.subsidiary_code))
 OR (a.table_name = 'compte_banque' AND a.old_value IN (ad.benef_account_code, ad.entity_account_code, ad.subsidiary_account_code)))
 );

 v_count := SQL%ROWCOUNT;

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'admin_template', 'CODE (tiers)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'tiers' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'admin_template' AND e.field_name = 'CODE (tiers)' AND e.old_value = a.old_value);

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'admin_template', 'CODE (compte_banque)', a.old_value, a.new_value
 FROM atrace.ref_tables_modif a
 WHERE a.table_name = 'compte_banque' AND a.field_name = 'code'
 AND NOT EXISTS (SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'admin_template' AND e.field_name = 'CODE (compte_banque)' AND e.old_value = a.old_value);

 COMMIT;

 atrace.log_anon_entry(v_run_id, 'ADMIN_TEMPLATE', 'ANONYMIZE', p_table_name => 'ADMIN_TEMPLATE',
 p_step_number => 3, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' admin_template rows anonymized (9 code fields)',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 3: admin_template - ' || v_count || ' rows updated (9 code fields batched)');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step3_start;
 atrace.log_anon_entry(v_run_id, 'ADMIN_TEMPLATE', 'ERROR', p_table_name => 'ADMIN_TEMPLATE',
 p_step_number => 3, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 3 (admin_template): ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 4: Anonymize META_CONDITION (comma-separated code lists in workflow rules)
-- Uses MERGE with CROSS JOIN LATERAL to parse, replace, and reassemble CSV values
-- Covers: ENTITY_CODE, BENEFICIARY_CODE, ENTITY_ACCOUNT_CODE, BENEF_ACCOUNT_CODE
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER := 0;
 v_step_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step4_start;

 atrace.log_anon_entry(v_run_id, 'META_CONDITION', 'PHASE_START', p_table_name => 'META_CONDITION',
 p_step_number => 4, p_status => 'INFO', p_message => 'Anonymizing meta_condition workflow rules');

 -- 4a. ENTITY_CODE
 MERGE INTO oppayments.meta_condition mc
 USING (
 SELECT mc2.meta_condition_id,
 LISTAGG('''' || new_code || '''', ',') WITHIN GROUP (ORDER BY idx) AS new_value
 FROM oppayments.meta_condition mc2
 CROSS JOIN LATERAL (
 SELECT REGEXP_SUBSTR(mc2.value, '[^,]+', 1, LEVEL) AS item, LEVEL AS idx
 FROM dual
 CONNECT BY LEVEL <= REGEXP_COUNT(mc2.value, ',') + 1
 ) split
 CROSS JOIN LATERAL (
 SELECT REGEXP_REPLACE(TRIM(BOTH ' ' FROM REPLACE(split.item, '''', '')), '\.$', '') AS code FROM dual
 ) norm
 LEFT JOIN atrace.ref_tables_modif a
 ON a.old_value = norm.code AND a.table_name = 'tiers' AND a.field_name = 'code'
 CROSS JOIN LATERAL (
 SELECT COALESCE(a.new_value, norm.code) AS new_code FROM dual
 ) replaced
 WHERE mc2.meta_column = 'ENTITY_CODE'
 GROUP BY mc2.meta_condition_id
 ) src ON (mc.meta_condition_id = src.meta_condition_id)
 WHEN MATCHED THEN UPDATE SET mc.value = src.new_value;
 v_step_count := SQL%ROWCOUNT;
 v_count := v_count + v_step_count;
 DBMS_OUTPUT.PUT_LINE(' - meta_condition ENTITY_CODE: ' || v_step_count || ' rows');

 -- 4b. BENEFICIARY_CODE
 MERGE INTO oppayments.meta_condition mc
 USING (
 SELECT mc2.meta_condition_id,
 LISTAGG('''' || new_code || '''', ',') WITHIN GROUP (ORDER BY idx) AS new_value
 FROM oppayments.meta_condition mc2
 CROSS JOIN LATERAL (
 SELECT REGEXP_SUBSTR(mc2.value, '[^,]+', 1, LEVEL) AS item, LEVEL AS idx
 FROM dual
 CONNECT BY LEVEL <= REGEXP_COUNT(mc2.value, ',') + 1
 ) split
 CROSS JOIN LATERAL (
 SELECT REGEXP_REPLACE(TRIM(BOTH ' ' FROM REPLACE(split.item, '''', '')), '\.$', '') AS code FROM dual
 ) norm
 LEFT JOIN atrace.ref_tables_modif a
 ON a.old_value = norm.code AND a.table_name = 'tiers' AND a.field_name = 'code'
 CROSS JOIN LATERAL (
 SELECT COALESCE(a.new_value, norm.code) AS new_code FROM dual
 ) replaced
 WHERE mc2.meta_column = 'BENEFICIARY_CODE'
 GROUP BY mc2.meta_condition_id
 ) src ON (mc.meta_condition_id = src.meta_condition_id)
 WHEN MATCHED THEN UPDATE SET mc.value = src.new_value;
 v_step_count := SQL%ROWCOUNT;
 v_count := v_count + v_step_count;
 DBMS_OUTPUT.PUT_LINE(' - meta_condition BENEFICIARY_CODE: ' || v_step_count || ' rows');

 -- 4c. ENTITY_ACCOUNT_CODE
 MERGE INTO oppayments.meta_condition mc
 USING (
 SELECT mc2.meta_condition_id,
 LISTAGG('''' || new_code || '''', ',') WITHIN GROUP (ORDER BY idx) AS new_value
 FROM oppayments.meta_condition mc2
 CROSS JOIN LATERAL (
 SELECT REGEXP_SUBSTR(mc2.value, '[^,]+', 1, LEVEL) AS item, LEVEL AS idx
 FROM dual
 CONNECT BY LEVEL <= REGEXP_COUNT(mc2.value, ',') + 1
 ) split
 CROSS JOIN LATERAL (
 SELECT REGEXP_REPLACE(TRIM(BOTH ' ' FROM REPLACE(split.item, '''', '')), '\.$', '') AS code FROM dual
 ) norm
 LEFT JOIN atrace.ref_tables_modif a
 ON a.old_value = norm.code AND a.table_name = 'compte_banque' AND a.field_name = 'code'
 CROSS JOIN LATERAL (
 SELECT COALESCE(a.new_value, norm.code) AS new_code FROM dual
 ) replaced
 WHERE mc2.meta_column = 'ENTITY_ACCOUNT_CODE'
 GROUP BY mc2.meta_condition_id
 ) src ON (mc.meta_condition_id = src.meta_condition_id)
 WHEN MATCHED THEN UPDATE SET mc.value = src.new_value;
 v_step_count := SQL%ROWCOUNT;
 v_count := v_count + v_step_count;
 DBMS_OUTPUT.PUT_LINE(' - meta_condition ENTITY_ACCOUNT_CODE: ' || v_step_count || ' rows');

 -- 4d. BENEF_ACCOUNT_CODE
 MERGE INTO oppayments.meta_condition mc
 USING (
 SELECT mc2.meta_condition_id,
 LISTAGG('''' || new_code || '''', ',') WITHIN GROUP (ORDER BY idx) AS new_value
 FROM oppayments.meta_condition mc2
 CROSS JOIN LATERAL (
 SELECT REGEXP_SUBSTR(mc2.value, '[^,]+', 1, LEVEL) AS item, LEVEL AS idx
 FROM dual
 CONNECT BY LEVEL <= REGEXP_COUNT(mc2.value, ',') + 1
 ) split
 CROSS JOIN LATERAL (
 SELECT REGEXP_REPLACE(TRIM(BOTH ' ' FROM REPLACE(split.item, '''', '')), '\.$', '') AS code FROM dual
 ) norm
 LEFT JOIN atrace.ref_tables_modif a
 ON a.old_value = norm.code AND a.table_name = 'compte_banque' AND a.field_name = 'code'
 CROSS JOIN LATERAL (
 SELECT COALESCE(a.new_value, norm.code) AS new_code FROM dual
 ) replaced
 WHERE mc2.meta_column = 'BENEF_ACCOUNT_CODE'
 GROUP BY mc2.meta_condition_id
 ) src ON (mc.meta_condition_id = src.meta_condition_id)
 WHEN MATCHED THEN UPDATE SET mc.value = src.new_value;
 v_step_count := SQL%ROWCOUNT;
 v_count := v_count + v_step_count;
 DBMS_OUTPUT.PUT_LINE(' - meta_condition BENEF_ACCOUNT_CODE: ' || v_step_count || ' rows');

 COMMIT;

 atrace.log_anon_entry(v_run_id, 'META_CONDITION', 'ANONYMIZE', p_table_name => 'META_CONDITION',
 p_step_number => 4, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' meta_condition rows anonymized (4 column types)',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 4: meta_condition - ' || v_count || ' total rows updated');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step4_start;
 atrace.log_anon_entry(v_run_id, 'META_CONDITION', 'ERROR', p_table_name => 'META_CONDITION',
 p_step_number => 4, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 4 (meta_condition): ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 5: Clear sensitive file/message content (cleanup)
-- Sets binary/text content to NULL. Idempotent (NULL to NULL is no-op).
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER := 0;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT step5_start;

 atrace.log_anon_entry(v_run_id, 'CLEANUP', 'PHASE_START',
 p_step_number => 5, p_status => 'INFO', p_message => 'Clearing sensitive file content');

 UPDATE oppayments.file_integration SET file_content = NULL WHERE file_content IS NOT NULL;
 v_count := v_count + SQL%ROWCOUNT;

 UPDATE oppayments.file_integration SET content_to_sign = NULL WHERE content_to_sign IS NOT NULL;
 v_count := v_count + SQL%ROWCOUNT;

 UPDATE oppayments.import_audit_error SET message = NULL WHERE message IS NOT NULL;
 v_count := v_count + SQL%ROWCOUNT;

 UPDATE oppayments.import_audit_messages SET message = NULL WHERE message IS NOT NULL;
 v_count := v_count + SQL%ROWCOUNT;

 COMMIT;

 atrace.log_anon_entry(v_run_id, 'CLEANUP', 'ANONYMIZE',
 p_step_number => 5, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' rows cleared (file_content, messages)',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 5: cleanup - ' || v_count || ' rows cleared');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO step5_start;
 atrace.log_anon_entry(v_run_id, 'CLEANUP', 'ERROR',
 p_step_number => 5, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 5 (cleanup): ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 6: Re-enable all OPPAYMENTS triggers
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER := 0;
BEGIN
 FOR rec IN (SELECT trigger_name FROM user_triggers WHERE status = 'DISABLED') LOOP
 BEGIN
 EXECUTE IMMEDIATE 'ALTER TRIGGER ' || rec.trigger_name || ' ENABLE';
 v_count := v_count + 1;
 EXCEPTION
 WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE('WARNING: Could not enable trigger ' || rec.trigger_name || ': ' || SQLERRM);
 END;
 END LOOP;

 atrace.log_anon_entry(v_run_id, 'TRIGGERS', 'ENABLE', p_status => 'SUCCESS',
 p_step_number => 6, p_rows_affected => v_count,
 p_message => v_count || ' triggers re-enabled');

 atrace.log_anon_entry(v_run_id, 'ITR1', 'PHASE_END', p_status => 'SUCCESS',
 p_message => 'Phase B (code cascade) completed');
 DBMS_OUTPUT.PUT_LINE('Step 6: Re-enabled ' || v_count || ' OPPAYMENTS triggers');
 DBMS_OUTPUT.PUT_LINE('========================================');
 DBMS_OUTPUT.PUT_LINE('EPF Anonymization Iteration 1 COMPLETE');
 DBMS_OUTPUT.PUT_LINE('========================================');
EXCEPTION
 WHEN OTHERS THEN
 atrace.log_anon_entry(v_run_id, 'TRIGGERS', 'ENABLE', p_status => 'ERROR',
 p_step_number => 6, p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 6 (trigger enable): ' || SQLERRM);
 RAISE;
END;
/