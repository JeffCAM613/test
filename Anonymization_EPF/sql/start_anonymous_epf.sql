-- ============================================================================
-- EPF/OPPAYMENTS Anonymization - Orchestrator Script
-- ============================================================================
-- Unified entry point for all EPF anonymization operations.
-- Creates infrastructure, then runs anonymization phases in correct order.
--
-- Parameters:
-- &1 = BASENAME (Oracle SID/TNS name)
-- &2 = SYSPASS (SYS password)
-- &3 = OPPASS (OP password - kept for interface compatibility)
-- &4 = EPFPASS (OPPAYMENTS password)
-- &5 = TBSDATA (DATA tablespace name)
-- &6 = TBSINDEX (INDEX tablespace name)
--
-- Re-runnable: All CREATE statements use existence checks.
-- ============================================================================

define BASENAME = &1
define SYSPASS = &2
define OPPASS = &3
define EPFPASS = &4
define TBSDATA = &5
define TBSINDEX = &6

-- ============================================================================
-- PHASE A: Infrastructure (as SYS)
-- ============================================================================

conn sys/&SYSPASS@&BASENAME as sysdba;
set echo off;
set verify off;
set feedback off;
set timing off;
set serveroutput on size unlimited;
spool logs\anonyme_epf.log

-- Master run_id: persists across connect commands (sqlplus substitution variable)
COLUMN gen_run_id NEW_VALUE MASTER_RUN_ID NOPRINT
SELECT RAWTOHEX(SYS_GUID()) AS gen_run_id FROM dual;

VARIABLE v_phase_start VARCHAR2(30)

WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT ====================================================================
PROMPT PHASE A: Infrastructure Setup (SYS)
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/

-- A1. Create ref_tables_modif_epf (EPF audit mapping table)
DECLARE
 v_exists NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_exists FROM all_tables WHERE owner = 'ATRACE' AND table_name = 'REF_TABLES_MODIF_EPF';
 IF v_exists = 0 THEN
 EXECUTE IMMEDIATE 'CREATE TABLE atrace.ref_tables_modif_epf(
 table_name VARCHAR2(80),
 field_name VARCHAR2(40),
 old_value VARCHAR2(80),
 new_value VARCHAR2(80)
 ) TABLESPACE &TBSDATA';
 EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX atrace.ndx_epf_anno ON atrace.ref_tables_modif_epf(table_name, field_name, old_value, new_value)';
 DBMS_OUTPUT.PUT_LINE('Created atrace.ref_tables_modif_epf');
 ELSE
 DBMS_OUTPUT.PUT_LINE('atrace.ref_tables_modif_epf already exists - skipping');
 END IF;
END;
/

-- A2. Create epf_anonymization_map (BIC component mapping table)
DECLARE
 v_exists NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_exists FROM all_tables WHERE owner = 'ATRACE' AND table_name = 'EPF_ANONYMIZATION_MAP';
 IF v_exists = 0 THEN
 EXECUTE IMMEDIATE 'CREATE TABLE atrace.epf_anonymization_map (
 id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 component_type VARCHAR2(20) NOT NULL,
 original_value VARCHAR2(50) NOT NULL,
 anonymized_value VARCHAR2(50) NOT NULL,
 created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
 CONSTRAINT uk_anon_map UNIQUE(component_type, original_value)
 ) TABLESPACE &TBSDATA';
 EXECUTE IMMEDIATE 'CREATE INDEX atrace.idx_anon_map_lookup ON atrace.epf_anonymization_map(component_type, original_value)';
 EXECUTE IMMEDIATE 'CREATE INDEX atrace.idx_anon_map_reverse ON atrace.epf_anonymization_map(component_type, anonymized_value)';
 DBMS_OUTPUT.PUT_LINE('Created atrace.epf_anonymization_map');
 ELSE
 DBMS_OUTPUT.PUT_LINE('atrace.epf_anonymization_map already exists - skipping');
 END IF;
END;
/

-- A3. Create live log table
DECLARE
 v_exists NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_exists FROM all_tables WHERE owner = 'OPPAYMENTS' AND table_name = 'EPF_ANON_LOG';
 IF v_exists = 0 THEN
 EXECUTE IMMEDIATE q'[CREATE TABLE oppayments.epf_anon_log (
 log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 run_id RAW(16) NOT NULL,
 log_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
 module VARCHAR2(50) NOT NULL,
 operation VARCHAR2(50) NOT NULL,
 table_name VARCHAR2(128),
 rows_affected NUMBER DEFAULT 0,
 step_number NUMBER,
 status VARCHAR2(20) NOT NULL,
 message VARCHAR2(4000),
 error_code VARCHAR2(50),
 error_message VARCHAR2(4000),
 elapsed_seconds NUMBER(10,3),
 CONSTRAINT chk_anon_log_status CHECK (status IN ('SUCCESS', 'ERROR', 'WARNING', 'INFO'))
 )]';
 EXECUTE IMMEDIATE 'CREATE INDEX oppayments.idx_anon_log_run ON oppayments.epf_anon_log(run_id)';
 EXECUTE IMMEDIATE 'CREATE INDEX oppayments.idx_anon_log_ts ON oppayments.epf_anon_log(log_timestamp)';
 DBMS_OUTPUT.PUT_LINE('Created oppayments.epf_anon_log');
 ELSE
 DBMS_OUTPUT.PUT_LINE('oppayments.epf_anon_log already exists - skipping');
 END IF;
END;
/

-- A4. Create logging procedure (autonomous transaction - survives rollbacks)
CREATE OR REPLACE PROCEDURE atrace.log_anon_entry(
 p_run_id IN RAW,
 p_module IN VARCHAR2,
 p_operation IN VARCHAR2,
 p_table_name IN VARCHAR2 DEFAULT NULL,
 p_rows_affected IN NUMBER DEFAULT 0,
 p_step_number IN NUMBER DEFAULT NULL,
 p_status IN VARCHAR2,
 p_message IN VARCHAR2 DEFAULT NULL,
 p_error_code IN VARCHAR2 DEFAULT NULL,
 p_error_message IN VARCHAR2 DEFAULT NULL,
 p_elapsed_seconds IN NUMBER DEFAULT NULL
)
IS
 PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
 INSERT INTO oppayments.epf_anon_log (
 run_id, log_timestamp, module, operation, table_name,
 rows_affected, step_number, status,
 message, error_code, error_message, elapsed_seconds
 ) VALUES (
 p_run_id, SYSTIMESTAMP, p_module, p_operation, p_table_name,
 p_rows_affected, p_step_number, p_status,
 p_message, p_error_code, p_error_message, p_elapsed_seconds
 );
 COMMIT;
EXCEPTION
 WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE('WARNING: Failed to write log entry: ' || SQLERRM);
 ROLLBACK;
END log_anon_entry;
/

-- A5. Create BIC random generator functions
CREATE OR REPLACE FUNCTION atrace.generate_random_bank_code RETURN VARCHAR2 AS
 v_chars VARCHAR2(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 v_result VARCHAR2(4) := '';
 v_pos NUMBER;
BEGIN
 FOR i IN 1..4 LOOP
 v_pos := TRUNC(DBMS_RANDOM.VALUE(1, 27));
 v_result := v_result || SUBSTR(v_chars, v_pos, 1);
 END LOOP;
 RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION atrace.generate_random_country_code RETURN VARCHAR2 AS
 v_chars VARCHAR2(26) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 v_result VARCHAR2(2) := '';
 v_pos NUMBER;
BEGIN
 FOR i IN 1..2 LOOP
 v_pos := TRUNC(DBMS_RANDOM.VALUE(1, 27));
 v_result := v_result || SUBSTR(v_chars, v_pos, 1);
 END LOOP;
 RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION atrace.generate_random_location_code RETURN VARCHAR2 AS
 v_chars VARCHAR2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 v_result VARCHAR2(2) := '';
 v_pos NUMBER;
BEGIN
 FOR i IN 1..2 LOOP
 v_pos := TRUNC(DBMS_RANDOM.VALUE(1, 37));
 v_result := v_result || SUBSTR(v_chars, v_pos, 1);
 END LOOP;
 RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION atrace.generate_random_branch_code RETURN VARCHAR2 AS
 v_chars VARCHAR2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 v_result VARCHAR2(3) := '';
 v_pos NUMBER;
 BEGIN
 FOR i IN 1..3 LOOP
 v_pos := TRUNC(DBMS_RANDOM.VALUE(1, 37));
 v_result := v_result || SUBSTR(v_chars, v_pos, 1);
 END LOOP;
 RETURN v_result;
END;
/

-- A6. Performance index on OP mapping table (for itr1 correlated subquery lookups)
DECLARE
 v_exists NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_exists FROM all_indexes
 WHERE owner = 'ATRACE' AND index_name = 'IDX_REF_MODIF_LOOKUP';
 IF v_exists = 0 THEN
 EXECUTE IMMEDIATE 'CREATE INDEX atrace.idx_ref_modif_lookup ON atrace.ref_tables_modif(table_name, field_name, old_value)';
 DBMS_OUTPUT.PUT_LINE('Created performance index idx_ref_modif_lookup');
 ELSE
 DBMS_OUTPUT.PUT_LINE('idx_ref_modif_lookup already exists - skipping');
 END IF;
END;
/

-- A7. Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON atrace.ref_tables_modif_epf TO oppayments;
GRANT SELECT ON atrace.ref_tables_modif TO oppayments;
GRANT SELECT, INSERT, UPDATE, DELETE ON atrace.epf_anonymization_map TO oppayments;
GRANT EXECUTE ON atrace.log_anon_entry TO oppayments;
GRANT INSERT ON oppayments.epf_anon_log TO atrace;
GRANT EXECUTE ON atrace.generate_random_bank_code TO oppayments;
GRANT EXECUTE ON atrace.generate_random_country_code TO oppayments;
GRANT EXECUTE ON atrace.generate_random_location_code TO oppayments;
GRANT EXECUTE ON atrace.generate_random_branch_code TO oppayments;

DECLARE
 v_elapsed NUMBER;
BEGIN
 DBMS_OUTPUT.PUT_LINE('=== Infrastructure setup complete ===');
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase A complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase A complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- A8. Performance indexes for heavy operations
DECLARE
 v_created NUMBER := 0;
 v_skipped NUMBER := 0;
 TYPE t_ddl IS TABLE OF VARCHAR2(200);
 l_ddls t_ddl := t_ddl(
 'CREATE INDEX oppayments.idx_payment_user_id ON oppayments.payment(user_id) TABLESPACE &TBSDATA',
 'CREATE INDEX oppayments.idx_payment_audit_user_id ON oppayments.payment_audit(user_id) TABLESPACE &TBSDATA',
 'CREATE INDEX oppayments.idx_payment_entity_code ON oppayments.payment(entity_code) TABLESPACE &TBSDATA',
 'CREATE INDEX oppayments.idx_payment_benef_code ON oppayments.payment(beneficiary_code) TABLESPACE &TBSDATA',
 'CREATE INDEX oppayments.idx_bulk_payment_entity_code ON oppayments.bulk_payment(entity_code) TABLESPACE &TBSDATA'
 );
BEGIN
 FOR i IN 1..l_ddls.COUNT LOOP
 BEGIN
 EXECUTE IMMEDIATE l_ddls(i);
 v_created := v_created + 1;
 EXCEPTION
 WHEN OTHERS THEN v_skipped := v_skipped + 1;
 END;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE(' Performance indexes: ' || v_created || ' created, ' || v_skipped || ' already exist');
END;
/

-- A9. Orphan Code Detection & Synthetic Mapping Generation
-- EPF may reference codes that no longer exist in OP (deleted tiers, external imports).
-- These would be SKIPPED by ITR1's NVL pattern. We generate synthetic mappings
-- using OP's naming convention (E_, P_, T_, CB_ prefixes) to ensure 100% coverage.
PROMPT
PROMPT Detecting orphan codes in EPF (no OP mapping)...

DECLARE
 v_orphan_count NUMBER := 0;
 v_next_seq NUMBER;
 v_prefix VARCHAR2(5);
BEGIN
 -- Get the next available sequence numbers for each prefix
 -- (continue from where OP left off)

 -- Entity orphans (E_ prefix for entities, T_ for counterparties)
 FOR rec IN (
 SELECT DISTINCT p.entity_code AS orphan_code
 FROM oppayments.payment p
 WHERE p.entity_code IS NOT NULL
 AND p.entity_code NOT LIKE 'E_%'
 AND p.entity_code NOT LIKE 'P_%'
 AND p.entity_code NOT LIKE 'T_%'
 AND NOT EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif r
 WHERE r.table_name = 'tiers' AND r.field_name = 'code' AND r.old_value = p.entity_code
 )
 ) LOOP
 -- Determine prefix: check if it's an entity or counterparty in OP
 BEGIN
 SELECT CASE
 WHEN EXISTS (SELECT 1 FROM op.tiers t JOIN op.structure s ON s.code = t.code
 WHERE t.code = rec.orphan_code AND s.structure = 'Entite' AND t.flag_portefeuille = 'N')
 THEN 'E_'
 WHEN EXISTS (SELECT 1 FROM op.tiers t JOIN op.structure s ON s.code = t.code
 WHERE t.code = rec.orphan_code AND s.structure = 'Entite' AND t.flag_portefeuille = 'O')
 THEN 'P_'
 ELSE 'T_'
 END INTO v_prefix FROM dual;
 EXCEPTION WHEN OTHERS THEN v_prefix := 'T_'; -- Default to counterparty
 END;

 -- Get next sequence for this prefix
 SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(new_value, '\d+$'))), 0) + 1
 INTO v_next_seq
 FROM atrace.ref_tables_modif
 WHERE table_name = 'tiers' AND field_name = 'code' AND new_value LIKE v_prefix || '%';

 INSERT INTO atrace.ref_tables_modif (table_name, field_name, old_value, new_value)
 VALUES ('tiers', 'code', rec.orphan_code, v_prefix || LPAD(v_next_seq, 4, '0'));

 v_orphan_count := v_orphan_count + 1;
 END LOOP;

 -- Bank account orphans (CB_ prefix)
 FOR rec IN (
 SELECT DISTINCT p.entity_account_code AS orphan_code
 FROM oppayments.payment p
 WHERE p.entity_account_code IS NOT NULL
 AND p.entity_account_code NOT LIKE 'CB_%'
 AND NOT EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif r
 WHERE r.table_name = 'compte_banque' AND r.field_name = 'code' AND r.old_value = p.entity_account_code
 )
 ) LOOP
 SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(new_value, '\d+$'))), 0) + 1
 INTO v_next_seq
 FROM atrace.ref_tables_modif
 WHERE table_name = 'compte_banque' AND field_name = 'code' AND new_value LIKE 'CB_%';

 INSERT INTO atrace.ref_tables_modif (table_name, field_name, old_value, new_value)
 VALUES ('compte_banque', 'code', rec.orphan_code, 'CB_' || LPAD(v_next_seq, 4, '0'));

 v_orphan_count := v_orphan_count + 1;
 END LOOP;

 -- Beneficiary orphans (T_ prefix - counterparties by default)
 FOR rec IN (
 SELECT DISTINCT p.beneficiary_code AS orphan_code
 FROM oppayments.payment p
 WHERE p.beneficiary_code IS NOT NULL
 AND p.beneficiary_code NOT LIKE 'E_%'
 AND p.beneficiary_code NOT LIKE 'P_%'
 AND p.beneficiary_code NOT LIKE 'T_%'
 AND NOT EXISTS (
 SELECT 1 FROM atrace.ref_tables_modif r
 WHERE r.table_name = 'tiers' AND r.field_name = 'code' AND r.old_value = p.beneficiary_code
 )
 ) LOOP
 SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(new_value, '\d+$'))), 0) + 1
 INTO v_next_seq
 FROM atrace.ref_tables_modif
 WHERE table_name = 'tiers' AND field_name = 'code' AND new_value LIKE 'T_%';

 INSERT INTO atrace.ref_tables_modif (table_name, field_name, old_value, new_value)
 VALUES ('tiers', 'code', rec.orphan_code, 'T_' || LPAD(v_next_seq, 4, '0'));

 v_orphan_count := v_orphan_count + 1;
 END LOOP;

 COMMIT;

 IF v_orphan_count > 0 THEN
 DBMS_OUTPUT.PUT_LINE(' WARNING: ' || v_orphan_count || ' orphan codes found in EPF with no OP mapping.');
 DBMS_OUTPUT.PUT_LINE(' Synthetic mappings generated using OP naming convention (E_/P_/T_/CB_ + seq).');
 DBMS_OUTPUT.PUT_LINE(' These will now be picked up by ITR1 cascade.');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' No orphan codes detected - all EPF codes have OP mappings.');
 END IF;
END;
/

WHENEVER SQLERROR CONTINUE
-- ============================================================================
-- PHASE B: Code-based Anonymization (as OPPAYMENTS)
-- ============================================================================

set termout off
connect oppayments/&EPFPASS@&BASENAME
set termout on
set echo off;
set verify off;
set feedback off;
set timing off;
set serveroutput on size unlimited;

-- Log run start
INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'RUN_START', 'INFO', 'EPF Anonymization starting (Phases B-G)');
COMMIT;

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase B: Code-based Anonymization');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE B: Code-based Anonymization (OPPAYMENTS)
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/

@sql\anonymize_epf_itr1.sql

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase B complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase B complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase B complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- PHASE C: BIC/SWIFT Component Anonymization (as OPPAYMENTS)
-- ============================================================================

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase C: BIC/SWIFT Component Anonymization');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE C: BIC/SWIFT Component Anonymization
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/

DECLARE
 v_count NUMBER := 0;
BEGIN
 FOR rec IN (SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED') LOOP
 EXECUTE IMMEDIATE 'ALTER TRIGGER ' || rec.trigger_name || ' DISABLE';
 v_count := v_count + 1;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Phase C: Disabled ' || v_count || ' triggers');
END;
/

@sql\bic\1_Anonymize_Bank_Codes.sql
@sql\bic\2_Anonymize_Country_Codes.sql
@sql\bic\3_Anonymize_Location_Codes.sql
@sql\bic\4_Anonymize_Branch_Codes.sql
@sql\bic\5_Anonymize_payment_amounts.sql

DECLARE
 v_count NUMBER := 0;
BEGIN
 FOR rec IN (SELECT trigger_name FROM user_triggers WHERE status = 'DISABLED') LOOP
 BEGIN
 EXECUTE IMMEDIATE 'ALTER TRIGGER ' || rec.trigger_name || ' ENABLE';
 v_count := v_count + 1;
 EXCEPTION WHEN OTHERS THEN NULL;
 END;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Phase C: Re-enabled ' || v_count || ' triggers');
END;
/

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase C complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase C complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase C complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- PHASE D: Independent Anonymization (admin_user, user cascades, free-text,
-- addresses, SWIFT components, SIRET, clearing, invoices)
-- ============================================================================

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase D: Independent Anonymization (19 steps)');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE D: Independent Anonymization (ITR2 - 19 steps)
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/
@sql\anonymize_epf_itr2.sql

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase D complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase D complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase D complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- PHASE E: Reference Data Anonymization (REF_TIERS + REF_BANK_BRANCHE)
-- ============================================================================

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase E: Reference Data Anonymization');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE E: Reference Data Anonymization (REF_TIERS + REF_BANK_BRANCHE)
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/
@sql\anonymize_epf_phase7_refdata.sql

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase E complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase E complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase E complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- PHASE F: SWIFT Message Fields + Audit Trail
-- ============================================================================

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase F: SWIFT Message Fields + Audit Trail');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE F: SWIFT Message Fields + Audit Trail
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/
@sql\anonymize_epf_phase8_swift_audit.sql

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase F complete');
COMMIT;
DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase F complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase F complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- PHASE G: OP Schema BIC + BBAN Gap Fix (requires SYS)
-- ============================================================================

set termout off
connect sys/&SYSPASS@&BASENAME as sysdba;
set termout on
set echo off;
set verify off;
set feedback off;
set timing off;
set serveroutput on size unlimited;

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase G: OP Schema BIC + BBAN Gap Fix');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE G: OP Schema BIC + BBAN Gap Fix
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/
@sql\anonymize_epf_phase9_op_bic_bban.sql

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase G complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase G complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase G complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- Reconnect as OPPAYMENTS for final verification and completion signal
set termout off
connect oppayments/&EPFPASS@&BASENAME
set termout on
set echo off;
set verify off;
set feedback off;
set timing off;
set serveroutput on size unlimited;

-- ============================================================================
-- PHASE H: Password Reset + Hashcode Recalculation
-- ============================================================================

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_START', 'INFO', 'Phase H: Password Reset + Hashcode Recalculation');
COMMIT;

PROMPT
PROMPT ====================================================================
PROMPT PHASE H: Password Reset + Hashcode Recalculation
PROMPT ====================================================================
BEGIN :v_phase_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'); END;
/

DECLARE
 vDataHashCode VARCHAR2(128);
 v_user_count NUMBER := 0;
 CURSOR all_userIds IS SELECT user_id FROM oppayments.admin_user;
BEGIN
 -- Reset all user passwords to 'EPF' and unlock accounts
 UPDATE oppayments.admin_user au
 SET au.password = oppayments.epf_utils.BCRYPT_ENCRYPT('EPF'),
 au.allow_to_validate = 0,
 au.allow_to_sign = 0,
 au.connexion_hit = 0,
 au.locked = 0,
 au.expired_date = SYSDATE + 365;
 COMMIT;

 -- Recalculate hashcode for every user (required for login validation)
 FOR curentUserId IN all_userIds LOOP
 vDataHashCode := oppayments.epf_utils.GetDataHashCode(curentUserId.user_id, 'USER_ID', 'ADMIN_USER');
 UPDATE oppayments.admin_user ua
 SET ua.hashcode = vDataHashCode
 WHERE ua.user_id = curentUserId.user_id;
 COMMIT;
 v_user_count := v_user_count + 1;
 END LOOP;

 DBMS_OUTPUT.PUT_LINE(' Password reset to "EPF" for ' || v_user_count || ' users');
 DBMS_OUTPUT.PUT_LINE(' Hashcodes recalculated for all users');
 DBMS_OUTPUT.PUT_LINE(' All accounts unlocked, expiry extended +365 days');
END;
/

INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'PHASE_END', 'SUCCESS', 'Phase H complete');
COMMIT;

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(SUBSTR(:v_phase_start,1,19), 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 IF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' >> Phase H complete (' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's)');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' >> Phase H complete (' || v_elapsed || 's)');
 END IF;
END;
/

-- ============================================================================
-- CLEANUP + VERIFICATION
-- ============================================================================

DECLARE
 v_dropped NUMBER := 0;
 v_skipped NUMBER := 0;
 TYPE t_idx IS TABLE OF VARCHAR2(60);
 l_indexes t_idx := t_idx(
 'oppayments.idx_payment_user_id',
 'oppayments.idx_payment_audit_user_id',
 'oppayments.idx_payment_entity_code',
 'oppayments.idx_payment_benef_code',
 'oppayments.idx_bulk_payment_entity_code'
 );
BEGIN
 FOR i IN 1..l_indexes.COUNT LOOP
 BEGIN
 EXECUTE IMMEDIATE 'DROP INDEX ' || l_indexes(i);
 v_dropped := v_dropped + 1;
 EXCEPTION
 WHEN OTHERS THEN v_skipped := v_skipped + 1;
 END;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE(' Performance indexes cleaned up: ' || v_dropped || ' dropped, ' || v_skipped || ' already absent');
END;
/

-- Final verification summary
PROMPT
PROMPT ====================================================================
PROMPT FINAL VERIFICATION SUMMARY
PROMPT ====================================================================
DECLARE
 v_total NUMBER;
 v_anon NUMBER;
BEGIN
 -- Admin User
 SELECT COUNT(*), COUNT(CASE WHEN code LIKE 'USR_%' THEN 1 END) INTO v_total, v_anon FROM oppayments.admin_user;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' ADMIN_USER');
 DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
 DBMS_OUTPUT.PUT_LINE(' Anonymized (USR_): ' || LPAD(v_anon, 10) || ' (' || ROUND(v_anon*100/NULLIF(v_total,0),1) || '%)');
 DBMS_OUTPUT.PUT_LINE(' Original: ' || LPAD(v_total - v_anon, 10));
 DBMS_OUTPUT.PUT_LINE(' Total: ' || LPAD(v_total, 10));

 -- Payment entity_code
 SELECT COUNT(*), COUNT(CASE WHEN entity_code LIKE 'E_%' OR entity_code LIKE 'P_%' OR entity_code LIKE 'T_%' THEN 1 END)
 INTO v_total, v_anon FROM oppayments.payment WHERE entity_code IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' PAYMENT.ENTITY_CODE (OP cascade)');
 DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
 DBMS_OUTPUT.PUT_LINE(' Anonymized (E_/P_/T_): ' || LPAD(v_anon, 10) || ' (' || ROUND(v_anon*100/NULLIF(v_total,0),1) || '%)');
 DBMS_OUTPUT.PUT_LINE(' Not mapped: ' || LPAD(v_total - v_anon, 10));

 -- Payment user_id
 SELECT COUNT(*),
 COUNT(CASE WHEN user_id LIKE 'USR_%' THEN 1 END)
 INTO v_total, v_anon FROM oppayments.payment WHERE user_id IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' PAYMENT.USER_ID');
 DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
 DBMS_OUTPUT.PUT_LINE(' Anonymized (USR_): ' || LPAD(v_anon, 10) || ' (' || ROUND(v_anon*100/NULLIF(v_total,0),1) || '%)');
 DBMS_OUTPUT.PUT_LINE(' System/Batch codes: ' || LPAD(v_total - v_anon, 10) || ' (expected - not personal data)');
 -- Payment free-text
 SELECT COUNT(*),
 COUNT(CASE WHEN benef_description LIKE 'BENEF_%' THEN 1 END)
 INTO v_total, v_anon FROM oppayments.payment WHERE benef_description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' PAYMENT.BENEF_DESCRIPTION (free-text)');
 DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
 DBMS_OUTPUT.PUT_LINE(' Anonymized (BENEF_): ' || LPAD(v_anon, 10) || ' (' || ROUND(v_anon*100/NULLIF(v_total,0),1) || '%)');
 DBMS_OUTPUT.PUT_LINE(' Original: ' || LPAD(v_total - v_anon, 10));

 -- Payment Audit user_id
 SELECT COUNT(*),
 COUNT(CASE WHEN user_id LIKE 'USR_%' THEN 1 END)
 INTO v_total, v_anon FROM oppayments.payment_audit WHERE user_id IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' PAYMENT_AUDIT.USER_ID');
 DBMS_OUTPUT.PUT_LINE(RPAD('-',70,'-'));
 DBMS_OUTPUT.PUT_LINE(' Anonymized (USR_): ' || LPAD(v_anon, 10) || ' (' || ROUND(v_anon*100/NULLIF(v_total,0),1) || '%)');
 DBMS_OUTPUT.PUT_LINE(' System/Batch codes: ' || LPAD(v_total - v_anon, 10));

 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
 DBMS_OUTPUT.PUT_LINE(' EPF ANONYMIZATION COMPLETE');
 DBMS_OUTPUT.PUT_LINE(RPAD('=',70,'='));
END;
/

-- Signal completion to the live monitor
INSERT INTO oppayments.epf_anon_log (run_id, module, operation, status, message)
VALUES (HEXTORAW('&MASTER_RUN_ID'), 'EPF_ORCHESTRATOR', 'ALL_COMPLETE', 'SUCCESS', 'All EPF anonymization phases (B-G) completed');
COMMIT;

SELECT 'EPF Anonymization completed at ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS completion FROM dual;

set echo off;
spool off;