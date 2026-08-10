-- ============================================================================
-- OP Anonymization Performance Boost - Pre-clear Histo Tables
-- ============================================================================
-- PURPOSE: Dramatically reduce OP pack_anonym execution time by pre-clearing
-- text and extra fields in ALL histo tables ONCE in bulk, before the
-- procedure iterates through each entity/account individually.
--
-- PROBLEM: pack_anonym calls anonymous_tables() per entity/bank account.
-- Each call does full table scans on histo tables to blank fields.
-- With 2016 bank accounts × 12 histo tables × multiple fields,
-- this results in thousands of redundant full scans.
--
-- SOLUTION: Clear these fields once upfront. Subsequent pack_anonym calls
-- find 0 rows to update and skip instantly.
--
-- COLUMN MAP (verified from all_tab_columns on a reference instance):
-- TABLE DESCRIPTION LIBELLE GROUPE_1/2/3
-- ------------------------- ---------- ------- ------------
-- histo_reglement YES - YES
-- histo_operation YES - YES
-- histo_flux YES - YES
-- histo_livraison YES - YES
-- histo_compta YES - -
-- histo_compta_man YES - -
-- histo_mouvement YES YES -
-- histo_mouvement_intraday YES YES -
-- histo_facture YES - -
-- histo_matiere YES - -
-- histo_parapheur YES - -
-- histo_pricing_groupe YES - -
--
-- ESTIMATED SPEEDUP: 8-10 hours saved on typical instances.
-- SAFE TO RUN: These fields are always blanked by anonymization anyway.
--
-- RUN AS: OP schema owner (called by start_anonymous.sql)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT Phase 1: Pre-clearing histo tables (all fields)
PROMPT ====================================================================
PROMPT

-- Enable parallel DML for faster bulk updates
ALTER SESSION ENABLE PARALLEL DML;

-- ============================================================================
-- PART 1: Large tables with GROUPE columns (description + groupe_1/2/3)
-- These are the main bottleneck — millions of rows each
-- ============================================================================

PROMPT === [1/12] histo_reglement (description + groupe_1/2/3) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_reglement
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_reglement
 SET description = NULL, groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

PROMPT === [2/12] histo_operation (description + groupe_1/2/3) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_operation
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_operation
 SET description = NULL, groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

PROMPT === [3/12] histo_flux (description + groupe_1/2/3) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_flux
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_flux
 SET description = NULL, groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

PROMPT === [4/12] histo_livraison (description + groupe_1/2/3) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_livraison
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_livraison
 SET description = NULL, groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
 WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

-- ============================================================================
-- PART 2: Tables with LIBELLE (description + libelle, NO groupe)
-- ============================================================================

PROMPT === [5/12] histo_mouvement (description + libelle) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_mouvement
 WHERE description IS NOT NULL OR libelle IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_mouvement
 SET description = NULL, libelle = NULL
 WHERE description IS NOT NULL OR libelle IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

PROMPT === [6/12] histo_mouvement_intraday (description + libelle) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_mouvement_intraday
 WHERE description IS NOT NULL OR libelle IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_mouvement_intraday
 SET description = NULL, libelle = NULL
 WHERE description IS NOT NULL OR libelle IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/
-- ============================================================================
-- PART 3: Tables with DESCRIPTION only (no groupe, no libelle)
-- Using EXCEPTION handler so missing tables don't abort the script
-- ============================================================================

PROMPT === [7/12] histo_compta (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_compta WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE /*+ PARALLEL(4) */ op.histo_compta SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
END;
/

PROMPT === [8/12] histo_compta_man (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_compta_man WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE op.histo_compta_man SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
EXCEPTION WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE(' SKIPPED: ' || SQLERRM);
END;
/

PROMPT === [9/12] histo_facture (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_facture WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE op.histo_facture SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
EXCEPTION WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE(' SKIPPED: ' || SQLERRM);
END;
/

PROMPT === [10/12] histo_matiere (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_matiere WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE op.histo_matiere SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
EXCEPTION WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE(' SKIPPED: ' || SQLERRM);
END;
/

PROMPT === [11/12] histo_parapheur (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_parapheur WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE op.histo_parapheur SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
EXCEPTION WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE(' SKIPPED: ' || SQLERRM);
END;
/

PROMPT === [12/12] histo_pricing_groupe (description only) ===
DECLARE
 v_count NUMBER;
 v_start TIMESTAMP := SYSTIMESTAMP;
BEGIN
 SELECT COUNT(*) INTO v_count FROM op.histo_pricing_groupe WHERE description IS NOT NULL;
 DBMS_OUTPUT.PUT_LINE(' Rows to clear: ' || v_count);
 IF v_count > 0 THEN
 UPDATE op.histo_pricing_groupe SET description = NULL WHERE description IS NOT NULL;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(' DONE in ' || ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Already clear - skipping');
 END IF;
EXCEPTION WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE(' SKIPPED: ' || SQLERRM);
END;
/

-- Reset parallel
ALTER SESSION DISABLE PARALLEL DML;

PROMPT
PROMPT ====================================================================
PROMPT >> Phase 1 complete.
PROMPT ====================================================================