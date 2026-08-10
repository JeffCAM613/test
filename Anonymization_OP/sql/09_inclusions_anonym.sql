-- ============================================================================
-- Custom Inclusions Anonymization
-- ============================================================================
-- PURPOSE: Process custom table/column inclusions from inclusions.csv
-- Allows future extensions WITHOUT modifying base scripts
--
-- PARAMETERS (passed from start_anonymous_v3.sql):
-- &1 = EntC (Entity code rename y/n)
-- &2 = FoldC (Portfolio code rename y/n)
-- &3 = TierC (Counterparty code rename y/n)
-- &4 = CpteC (Bank Account code rename y/n)
--
-- PREREQUISITES:
-- - Table atrace.anon_inclusions must be populated (by batch script)
-- - Run AFTER 06_op_setbased_anonym.sql (requires atrace.op_code_mapping)
-- - Run AFTER 07/08 scripts (this is for FUTURE extensions)
--
-- TYPE MAPPING (from inclusions.csv):
-- E = Entity only → only if EntC=y → op.merge_codes
-- P = Portfolio only → only if FoldC=y → op.merge_codes
-- C = Counterparty only → only if TierC=y → op.merge_codes
-- BA = Bank Account → only if CpteC=y → op.merge_codes with p_entity_type=>'COMPTE'
-- EPC = Mixed E/P/C → if ANY of EntC/FoldC/TierC=y → op.merge_codes
-- * = Free-text → ALWAYS → UPDATE SET column = NULL
--
-- HANDLING MISSING TABLES/COLUMNS:
-- - ORA-00942 (table doesn't exist) → SKIPPED
-- - ORA-00904 (column doesn't exist) → SKIPPED
--
-- VERSION: 1.0.0 (2026-08-07)
-- ============================================================================

-- Accept parameters
DEFINE p_EntC = &1
DEFINE p_FoldC = &2
DEFINE p_TierC = &3
DEFINE p_CpteC = &4

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT Custom Inclusions Anonymization (from inclusions.csv)
PROMPT ====================================================================
PROMPT User selections: EntC=&p_EntC FoldC=&p_FoldC TierC=&p_TierC CpteC=&p_CpteC
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- Create inclusions table if not exists (will be populated by batch script)
-- ============================================================================
DECLARE
 v_exists NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_exists 
 FROM all_tables 
 WHERE owner = 'ATRACE' AND table_name = 'ANON_INCLUSIONS';
 
 IF v_exists = 0 THEN
 EXECUTE IMMEDIATE '
 CREATE TABLE atrace.anon_inclusions (
 table_name VARCHAR2(128) NOT NULL,
 column_name VARCHAR2(128) NOT NULL,
 anon_type VARCHAR2(10) NOT NULL,
 notes VARCHAR2(500),
 processed VARCHAR2(1) DEFAULT ''N'',
 process_msg VARCHAR2(500),
 CONSTRAINT pk_anon_inclusions PRIMARY KEY (table_name, column_name)
 )';
 DBMS_OUTPUT.PUT_LINE(' Created table atrace.anon_inclusions');
 END IF;
END;
/

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON atrace.anon_inclusions TO op;

-- ============================================================================
-- Process inclusions
-- ============================================================================
DECLARE
 v_total NUMBER := 0;
 v_processed NUMBER := 0;
 v_skipped NUMBER := 0;
 v_errors NUMBER := 0;
 v_msg VARCHAR2(500);
 
 -- Config flags
 v_EntC VARCHAR2(1) := '&p_EntC';
 v_FoldC VARCHAR2(1) := '&p_FoldC';
 v_TierC VARCHAR2(1) := '&p_TierC';
 v_CpteC VARCHAR2(1) := '&p_CpteC';
 
 -- Cursor for inclusions
 CURSOR c_inclusions IS
 SELECT table_name, column_name, UPPER(anon_type) as anon_type, notes
 FROM atrace.anon_inclusions
 WHERE processed = 'N'
 ORDER BY table_name, column_name;
 
 -- Helper procedure: NULL a column (for free-text type *)
 PROCEDURE null_column(p_table VARCHAR2, p_column VARCHAR2, p_msg OUT VARCHAR2) IS
 v_sql VARCHAR2(4000);
 v_count NUMBER;
 BEGIN
 v_sql := 'UPDATE op.' || p_table || ' SET ' || p_column || ' = NULL WHERE ' || p_column || ' IS NOT NULL';
 EXECUTE IMMEDIATE v_sql;
 v_count := SQL%ROWCOUNT;
 COMMIT;
 IF v_count > 0 THEN
 p_msg := v_count || ' rows NULLed';
 ELSE
 p_msg := '0 rows (already NULL or empty)';
 END IF;
 EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -942 THEN
 p_msg := 'SKIPPED (table not found)';
 ELSIF SQLCODE = -904 THEN
 p_msg := 'SKIPPED (column not found)';
 ELSE
 p_msg := 'ERROR: ' || SQLERRM;
 RAISE;
 END IF;
 END;
 
 -- Helper function: Should process based on type and flags?
 FUNCTION should_process(p_type VARCHAR2) RETURN BOOLEAN IS
 BEGIN
 CASE p_type
 WHEN 'E' THEN RETURN v_EntC = 'y';
 WHEN 'P' THEN RETURN v_FoldC = 'y';
 WHEN 'C' THEN RETURN v_TierC = 'y';
 WHEN 'BA' THEN RETURN v_CpteC = 'y';
 WHEN 'EPC' THEN RETURN v_EntC = 'y' OR v_FoldC = 'y' OR v_TierC = 'y';
 WHEN '*' THEN RETURN TRUE; -- Always process free-text
 ELSE RETURN FALSE; -- Unknown type
 END CASE;
 END;
 
 -- Helper function: Get skip reason based on type
 FUNCTION get_skip_reason(p_type VARCHAR2) RETURN VARCHAR2 IS
 BEGIN
 CASE p_type
 WHEN 'E' THEN RETURN 'SKIPPED (EntC=n)';
 WHEN 'P' THEN RETURN 'SKIPPED (FoldC=n)';
 WHEN 'C' THEN RETURN 'SKIPPED (TierC=n)';
 WHEN 'BA' THEN RETURN 'SKIPPED (CpteC=n)';
 WHEN 'EPC' THEN RETURN 'SKIPPED (EntC/FoldC/TierC=n)';
 ELSE RETURN 'SKIPPED (unknown type: ' || p_type || ')';
 END CASE;
 END;

BEGIN
 -- Count total inclusions
 SELECT COUNT(*) INTO v_total FROM atrace.anon_inclusions WHERE processed = 'N';
 
 IF v_total = 0 THEN
 DBMS_OUTPUT.PUT_LINE(' No custom inclusions to process (inclusions.csv empty or all commented)');
 DBMS_OUTPUT.PUT_LINE(' To add custom inclusions, edit Anonymization_OP\inclusions.csv');
 RETURN;
 END IF;
 
 DBMS_OUTPUT.PUT_LINE(' Found ' || v_total || ' custom inclusion(s) to process');
 DBMS_OUTPUT.PUT_LINE('');
 -- Process each inclusion
 FOR rec IN c_inclusions LOOP
 BEGIN
 IF should_process(rec.anon_type) THEN
 -- Process based on type
 IF rec.anon_type = '*' THEN
 -- Free-text: NULL the column
 null_column(rec.table_name, rec.column_name, v_msg);
 ELSIF rec.anon_type = 'BA' THEN
 -- Bank Account: use COMPTE entity type
 op.merge_codes(rec.table_name, rec.column_name, p_entity_type => 'COMPTE');
 v_msg := 'Processed (BA)';
 ELSE
 -- E, P, C, EPC: standard merge
 op.merge_codes(rec.table_name, rec.column_name);
 v_msg := 'Processed (' || rec.anon_type || ')';
 END IF;
 v_processed := v_processed + 1;
 ELSE
 -- Skip based on config flags
 v_msg := get_skip_reason(rec.anon_type);
 v_skipped := v_skipped + 1;
 END IF;
 
 -- Update status
 UPDATE atrace.anon_inclusions 
 SET processed = 'Y', process_msg = v_msg
 WHERE table_name = rec.table_name AND column_name = rec.column_name;
 COMMIT;
 
 -- Output progress
 DBMS_OUTPUT.PUT_LINE(' ' || RPAD(rec.table_name || '.' || rec.column_name, 50) || v_msg);
 
 EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -942 THEN
 v_msg := 'SKIPPED (table not found)';
 ELSIF SQLCODE = -904 THEN
 v_msg := 'SKIPPED (column not found)';
 ELSE
 v_msg := 'ERROR: ' || SQLERRM;
 v_errors := v_errors + 1;
 END IF;
 
 UPDATE atrace.anon_inclusions 
 SET processed = 'Y', process_msg = v_msg
 WHERE table_name = rec.table_name AND column_name = rec.column_name;
 COMMIT;
 
 DBMS_OUTPUT.PUT_LINE(' ' || RPAD(rec.table_name || '.' || rec.column_name, 50) || v_msg);
 END;
 END LOOP;
 
 -- Summary
 DBMS_OUTPUT.PUT_LINE('');
 DBMS_OUTPUT.PUT_LINE(' === Custom Inclusions Summary ===');
 DBMS_OUTPUT.PUT_LINE(' Total: ' || v_total);
 DBMS_OUTPUT.PUT_LINE(' Processed: ' || v_processed);
 DBMS_OUTPUT.PUT_LINE(' Skipped: ' || v_skipped);
 IF v_errors > 0 THEN
 DBMS_OUTPUT.PUT_LINE(' Errors: ' || v_errors);
 END IF;
END;
/

PROMPT
PROMPT Custom inclusions processing complete.
PROMPT