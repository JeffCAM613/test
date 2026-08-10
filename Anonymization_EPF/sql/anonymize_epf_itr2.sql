-- ============================================================================
-- EPF/OPPAYMENTS Anonymization - Iteration 2 (Production)
-- Independent anonymizations (not based on OP values)
-- ============================================================================
-- INTEGRATES: Phase 1 (admin_user), Phase 2 (approbation_group_users),
-- Phase 3 (user_setting.user_id), Phase 4 (user_creation/last_modif,
-- notification_user, payment_audit), Phase 5 (user_setting codes),
-- Phase 6A (addresses), Phase 6B (SWIFT components),
-- Phase 6C (SIRET/clearing), Phase 6D (invoice/transmission),
-- ITR2 Steps 2-3 (free-text fields)
--
-- FEATURES:
-- - Mapping-first approach (audit trail before changes)
-- - Batched UPDATEs for large tables (PAYMENT_AUDIT)
-- - Per-step SAVEPOINT with error handling
-- - Live logging via atrace.log_anon_entry (autonomous transaction)
-- - Fully re-runnable (idempotent)
-- - All 15+ tables with user references cascaded
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

-- Generate run_id for this execution
VARIABLE g_run_id_itr2 VARCHAR2(32)
BEGIN
 SELECT RAWTOHEX(SYS_GUID()) INTO :g_run_id_itr2 FROM dual;
END;
/

PROMPT
PROMPT ====================================================================
PROMPT ITR2 STARTING - EPF Independent Anonymization
PROMPT ====================================================================

-- ============================================================================
-- STEP 0: Disable all OPPAYMENTS triggers (prevent cascading side effects)
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id_itr2);
 v_count NUMBER := 0;
BEGIN
 FOR rec IN (SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED') LOOP
 EXECUTE IMMEDIATE 'ALTER TRIGGER ' || rec.trigger_name || ' DISABLE';
 v_count := v_count + 1;
 END LOOP;
 atrace.log_anon_entry(v_run_id, 'ITR2_TRIGGERS', 'DISABLE', p_status => 'SUCCESS',
 p_step_number => 0, p_rows_affected => v_count,
 p_message => v_count || ' triggers disabled for ITR2');
 DBMS_OUTPUT.PUT_LINE('Step 0: Disabled ' || v_count || ' OPPAYMENTS triggers');
EXCEPTION
 WHEN OTHERS THEN
 atrace.log_anon_entry(v_run_id, 'ITR2_TRIGGERS', 'DISABLE', p_status => 'ERROR',
 p_step_number => 0, p_error_code => SQLCODE, p_error_message => SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 1: Record admin_user CODE mappings (BEFORE any changes)
-- Creates deterministic mapping: old_code -> USR_0000001, USR_0000002, etc.
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id_itr2);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT itr2_step1;

 atrace.log_anon_entry(v_run_id, 'ITR2_ORCHESTRATOR', 'RUN_START', p_status => 'INFO',
 p_message => 'EPF Anonymization Iteration 2 starting');
 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'MAPPING', p_table_name => 'ADMIN_USER',
 p_step_number => 1, p_status => 'INFO', p_message => 'Recording admin_user code mappings');

 INSERT INTO atrace.ref_tables_modif_epf (table_name, field_name, old_value, new_value)
 SELECT 'admin_user', 'CODE', old_code, new_code
 FROM (
 SELECT code AS old_code,
 'USR_' || LPAD(ROW_NUMBER() OVER (ORDER BY DBMS_RANDOM.VALUE), 7, '0') AS new_code
 FROM oppayments.admin_user
 WHERE code NOT LIKE 'USR_%'
 ) mapping
 WHERE NOT EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'admin_user' AND e.field_name = 'CODE' AND e.old_value = mapping.old_code
 );

 v_count := SQL%ROWCOUNT;
 COMMIT;

 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'MAPPING', p_table_name => 'ADMIN_USER',
 p_step_number => 1, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' mappings recorded',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 1: ' || v_count || ' admin_user mappings recorded');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO itr2_step1;
 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'ERROR', p_table_name => 'ADMIN_USER',
 p_step_number => 1, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 1: ' || SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 2: Anonymize ADMIN_USER table (using recorded mapping)
-- Renames code, description, first_name, last_name, addr, email, phone, fax
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id_itr2);
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SAVEPOINT itr2_step2;

 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'ANONYMIZE', p_table_name => 'ADMIN_USER',
 p_step_number => 2, p_status => 'INFO', p_message => 'Applying admin_user anonymization');

 UPDATE oppayments.admin_user au
 SET (code, description, first_name, last_name, addr_line1, addr_line2,
 post_code, country, email, phone, fax) = (
 SELECT e.new_value,
 e.new_value,
 'FirstName_' || SUBSTR(e.new_value, 5),
 'LastName_' || SUBSTR(e.new_value, 5),
 CASE WHEN au.addr_line1 IS NOT NULL THEN 'Addr1_' || SUBSTR(e.new_value, 5) ELSE NULL END,
 CASE WHEN au.addr_line2 IS NOT NULL THEN 'Addr2_' || SUBSTR(e.new_value, 5) ELSE NULL END,
 CASE WHEN au.post_code IS NOT NULL THEN 'PC_' || SUBSTR(e.new_value, 5) ELSE NULL END,
 CASE WHEN au.country IS NOT NULL THEN 'CT' ELSE NULL END,
 CASE WHEN au.email IS NOT NULL THEN LOWER(e.new_value) || '@example.com' ELSE NULL END,
 CASE WHEN au.phone IS NOT NULL THEN 'PHONE_' || SUBSTR(e.new_value, 5) ELSE NULL END,
 CASE WHEN au.fax IS NOT NULL THEN 'FAX_' || SUBSTR(e.new_value, 5) ELSE NULL END
 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'admin_user' AND e.field_name = 'CODE' AND e.old_value = au.code
 )
 WHERE EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif_epf e
 WHERE e.table_name = 'admin_user' AND e.field_name = 'CODE' AND e.old_value = au.code
 );

 v_count := SQL%ROWCOUNT;
 COMMIT;

 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'ANONYMIZE', p_table_name => 'ADMIN_USER',
 p_step_number => 2, p_rows_affected => v_count, p_status => 'SUCCESS',
 p_message => v_count || ' admin_user rows anonymized',
 p_elapsed_seconds => EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)));
 DBMS_OUTPUT.PUT_LINE('Step 2: ' || v_count || ' admin_user rows anonymized');
 DBMS_OUTPUT.PUT_LINE(' +-- ADMIN_USER SAMPLE (first 3) ----+');
 FOR rec IN (SELECT code, description FROM oppayments.admin_user WHERE code LIKE 'USR_%' AND ROWNUM <= 3) LOOP
 DBMS_OUTPUT.PUT_LINE(' | ' || RPAD(rec.code, 15) || rec.description || ' |');
 END LOOP;
 DBMS_OUTPUT.PUT_LINE(' +------------------------------------+');

EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK TO itr2_step2;
 atrace.log_anon_entry(v_run_id, 'ADMIN_USER', 'ERROR', p_table_name => 'ADMIN_USER',
 p_step_number => 2, p_status => 'ERROR', p_error_code => SQLCODE, p_error_message => SQLERRM);
 DBMS_OUTPUT.PUT_LINE('ERROR Step 2: ' || SQLERRM);
 RAISE;
END;
/