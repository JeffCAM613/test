-- ============================================================================
-- EPF Anonymization - Phase 9: OP Schema BIC + BBAN Gap Fix
-- Target: op.TIERS (BIC fields) + op.COMPTE_BANQUE (BBAN/account fields)
-- Rows affected: ~267 TIERS + ~1192 COMPTE_BANQUE
-- ============================================================================
-- CONTEXT:
-- OP pack_anonym renamed CODE/DESCRIPTION but left BIC components and
-- bank account numbers untouched. This script closes that gap.
--
-- PREREQUISITES:
-- - Must be run AFTER Phase C (BIC scripts) so epf_anonymization_map exists
-- - Requires UPDATE privilege on op.TIERS and op.COMPTE_BANQUE
-- - Connect as: schema owner with grants, or SYS/DBA
--
-- APPROACH:
-- Step 1: Extend epf_anonymization_map with any new BIC values from op.TIERS
-- Step 2: Anonymize op.TIERS BIC fields using the map (consistent with EPF)
-- Step 3: Anonymize op.COMPTE_BANQUE account numbers (deterministic synthetic)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

VARIABLE g_run_id VARCHAR2(32)
BEGIN
 SELECT RAWTOHEX(SYS_GUID()) INTO :g_run_id FROM dual;
END;
/

-- ============================================================================
-- STEP 1: Extend epf_anonymization_map with new BANK_CODE values from op.TIERS
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER := 0;
 v_rand VARCHAR2(20);
 v_exists NUMBER;

 -- Generate random alpha string of given length
 FUNCTION random_alpha(p_len NUMBER) RETURN VARCHAR2 IS
 v_result VARCHAR2(20) := '';
 v_chars VARCHAR2(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 BEGIN
 FOR i IN 1..p_len LOOP
 v_result := v_result || SUBSTR(v_chars, TRUNC(DBMS_RANDOM.VALUE(1, 27)), 1);
 END LOOP;
 RETURN v_result;
 END;

 -- Generate random alphanumeric string
 FUNCTION random_alphanum(p_len NUMBER) RETURN VARCHAR2 IS
 v_result VARCHAR2(20) := '';
 v_chars VARCHAR2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 BEGIN
 FOR i IN 1..p_len LOOP
 v_result := v_result || SUBSTR(v_chars, TRUNC(DBMS_RANDOM.VALUE(1, 37)), 1);
 END LOOP;
 RETURN v_result;
 END;

BEGIN
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP1_START', p_status => 'INFO',
 p_step_number => 1, p_message => 'Extending BIC map with op.TIERS values');

 -- Insert missing BANK_CODE values (4 alpha chars) - with uniqueness check
 FOR rec IN (
 SELECT DISTINCT bank_code AS orig_val
 FROM op.tiers
 WHERE bank_code IS NOT NULL
 AND bank_code NOT IN (SELECT original_value FROM atrace.epf_anonymization_map WHERE component_type = 'BANK_CODE')
 ) LOOP
 LOOP
 v_rand := random_alpha(4);
 SELECT COUNT(*) INTO v_exists FROM atrace.epf_anonymization_map
 WHERE component_type = 'BANK_CODE' AND anonymized_value = v_rand;
 EXIT WHEN v_exists = 0;
 END LOOP;
 INSERT INTO atrace.epf_anonymization_map (component_type, original_value, anonymized_value)
 VALUES ('BANK_CODE', rec.orig_val, v_rand);
 v_count := v_count + 1;
 END LOOP;

 -- Insert missing COUNTRY_CODE values (2 alpha chars) - with uniqueness check
 FOR rec IN (
 SELECT DISTINCT iso_country_code AS orig_val
 FROM op.tiers
 WHERE iso_country_code IS NOT NULL
 AND iso_country_code NOT IN (SELECT original_value FROM atrace.epf_anonymization_map WHERE component_type = 'COUNTRY_CODE')
 ) LOOP
 LOOP
 v_rand := random_alpha(2);
 SELECT COUNT(*) INTO v_exists FROM atrace.epf_anonymization_map
 WHERE component_type = 'COUNTRY_CODE' AND anonymized_value = v_rand;
 EXIT WHEN v_exists = 0;
 END LOOP;
 INSERT INTO atrace.epf_anonymization_map (component_type, original_value, anonymized_value)
 VALUES ('COUNTRY_CODE', rec.orig_val, v_rand);
 v_count := v_count + 1;
 END LOOP;

 -- Insert missing LOCATION_CODE values (2 alphanumeric chars) - with uniqueness check
 FOR rec IN (
 SELECT DISTINCT location_code AS orig_val
 FROM op.tiers
 WHERE location_code IS NOT NULL
 AND location_code NOT IN (SELECT original_value FROM atrace.epf_anonymization_map WHERE component_type = 'LOCATION_CODE')
 ) LOOP
 LOOP
 v_rand := random_alphanum(2);
 SELECT COUNT(*) INTO v_exists FROM atrace.epf_anonymization_map
 WHERE component_type = 'LOCATION_CODE' AND anonymized_value = v_rand;
 EXIT WHEN v_exists = 0;
 END LOOP;
 INSERT INTO atrace.epf_anonymization_map (component_type, original_value, anonymized_value)
 VALUES ('LOCATION_CODE', rec.orig_val, v_rand);
 v_count := v_count + 1;
 END LOOP;

 -- Insert missing BRANCH_CODE values (3 alphanumeric, but 'XXX' always preserved) - with uniqueness check
 FOR rec IN (
 SELECT DISTINCT branch_code AS orig_val
 FROM op.tiers
 WHERE branch_code IS NOT NULL
 AND branch_code != 'XXX'
 AND branch_code NOT IN (SELECT original_value FROM atrace.epf_anonymization_map WHERE component_type = 'BRANCH_CODE')
 ) LOOP
 LOOP
 v_rand := random_alphanum(3);
 SELECT COUNT(*) INTO v_exists FROM atrace.epf_anonymization_map
 WHERE component_type = 'BRANCH_CODE' AND anonymized_value = v_rand;
 EXIT WHEN v_exists = 0;
 END LOOP;
 INSERT INTO atrace.epf_anonymization_map (component_type, original_value, anonymized_value)
 VALUES ('BRANCH_CODE', rec.orig_val, v_rand);
 v_count := v_count + 1;
 END LOOP;

 COMMIT;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP1_DONE', p_status => 'SUCCESS',
 p_step_number => 1, p_rows_affected => v_count,
 p_message => v_count || ' new BIC mappings inserted into epf_anonymization_map');
 DBMS_OUTPUT.PUT_LINE('Step 1: Inserted ' || v_count || ' new BIC map entries');
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP1_ERROR', p_status => 'ERROR',
 p_step_number => 1, p_error_code => SQLCODE, p_error_message => SQLERRM);
 RAISE;
END;
/
-- ============================================================================
-- STEP 2: Anonymize op.TIERS BIC fields using epf_anonymization_map
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
BEGIN
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP2_START', p_status => 'INFO',
 p_step_number => 2, p_message => 'Anonymizing op.TIERS BIC components');

 UPDATE op.tiers t
 SET bank_code = NVL((SELECT m.anonymized_value FROM atrace.epf_anonymization_map m
 WHERE m.component_type = 'BANK_CODE' AND m.original_value = t.bank_code),
 t.bank_code),
 iso_country_code = NVL((SELECT m.anonymized_value FROM atrace.epf_anonymization_map m
 WHERE m.component_type = 'COUNTRY_CODE' AND m.original_value = t.iso_country_code),
 t.iso_country_code),
 location_code = NVL((SELECT m.anonymized_value FROM atrace.epf_anonymization_map m
 WHERE m.component_type = 'LOCATION_CODE' AND m.original_value = t.location_code),
 t.location_code),
 branch_code = CASE
 WHEN t.branch_code = 'XXX' THEN 'XXX' -- head office preserved
 ELSE NVL((SELECT m.anonymized_value FROM atrace.epf_anonymization_map m
 WHERE m.component_type = 'BRANCH_CODE' AND m.original_value = t.branch_code),
 t.branch_code)
 END
 WHERE bank_code IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 COMMIT;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP2_DONE', p_status => 'SUCCESS',
 p_step_number => 2, p_rows_affected => v_count,
 p_message => v_count || ' op.TIERS rows: BIC anonymized');
 DBMS_OUTPUT.PUT_LINE('Step 2: Anonymized BIC on ' || v_count || ' op.TIERS rows');
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP2_ERROR', p_status => 'ERROR',
 p_step_number => 2, p_error_code => SQLCODE, p_error_message => SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 3: Anonymize op.COMPTE_BANQUE account numbers
-- Uses deterministic hashing so results are reproducible
-- ============================================================================
DECLARE
 v_run_id RAW(16) := HEXTORAW(:g_run_id);
 v_count NUMBER;
BEGIN
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP3_START', p_status => 'INFO',
 p_step_number => 3, p_message => 'Anonymizing op.COMPTE_BANQUE BBAN/account fields');

 UPDATE op.compte_banque
 SET numero_banque = LPAD(MOD(ORA_HASH(code, 1), 90000) + 10000, 5, '0'),
 numero_guichet = LPAD(MOD(ORA_HASH(code, 2), 90000) + 10000, 5, '0'),
 numero_compte = LPAD(MOD(ORA_HASH(code, 3), 99999999999), 11, '0'),
 numero_cle = LPAD(MOD(ORA_HASH(code, 4), 100), 2, '0'),
 -- Reconstruct CODE_BBAN from new parts
 code_bban = LPAD(MOD(ORA_HASH(code, 1), 90000) + 10000, 5, '0')
 || LPAD(MOD(ORA_HASH(code, 2), 90000) + 10000, 5, '0')
 || LPAD(MOD(ORA_HASH(code, 3), 99999999999), 11, '0')
 || LPAD(MOD(ORA_HASH(code, 4), 100), 2, '0'),
 cle_iban = LPAD(MOD(ORA_HASH(code, 5), 100), 2, '0'),
 swift_tag25 = NULL
 WHERE code_bban IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 COMMIT;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP3_DONE', p_status => 'SUCCESS',
 p_step_number => 3, p_rows_affected => v_count,
 p_message => v_count || ' op.COMPTE_BANQUE rows: BBAN/account anonymized');
 DBMS_OUTPUT.PUT_LINE('Step 3: Anonymized BBAN on ' || v_count || ' op.COMPTE_BANQUE rows');
EXCEPTION
 WHEN OTHERS THEN
 ROLLBACK;
 atrace.log_anon_entry(v_run_id, 'PHASE9', 'STEP3_ERROR', p_status => 'ERROR',
 p_step_number => 3, p_error_code => SQLCODE, p_error_message => SQLERRM);
 RAISE;
END;
/

-- ============================================================================
-- STEP 4: Verify results
-- ============================================================================
PROMPT === Verification: op.TIERS BIC (should show random codes, not real ones) ===
SELECT code, bank_code, iso_country_code, location_code, branch_code
FROM op.tiers WHERE code = 'E_9406895';

PROMPT === Verification: op.COMPTE_BANQUE (should show synthetic account numbers) ===
SELECT code, numero_banque, numero_guichet, numero_compte, numero_cle, code_bban, cle_iban
FROM op.compte_banque WHERE code = 'CB_3724922';

PROMPT === Phase 9 complete ===