-- ============================================================================
-- Script 5: Anonymize Payment Amounts (Production - Fixed)
-- ============================================================================
-- Randomizes NOMINAL_1, syncs NOMINAL_2, recalculates bulk totals.
-- Simpler approach: uniform randomization (0.5x to 1.5x original).
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT Script 5: Anonymize Payment Amounts
PROMPT ====================================================================

-- Drop temp table if exists from prior failed run
BEGIN
 EXECUTE IMMEDIATE 'DROP TABLE temp_nominal_constraints';
 DBMS_OUTPUT.PUT_LINE('Dropped existing temp_nominal_constraints');
EXCEPTION
 WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE('temp_nominal_constraints did not exist (OK)');
END;
/

-- Create temp constraints table (preserves workflow threshold relationships)
CREATE GLOBAL TEMPORARY TABLE temp_nominal_constraints ON COMMIT PRESERVE ROWS
AS
SELECT DISTINCT c.meta_operator_id,
 o.code AS operator,
 TO_NUMBER(c.value) AS threshold_value
 FROM oppayments.workflow w
 INNER JOIN oppayments.meta_rule r ON r.meta_rule_id = w.meta_rule_id
 INNER JOIN oppayments.meta_condition c ON c.meta_rule_id = r.meta_rule_id
 INNER JOIN oppayments.meta_operator o ON o.meta_operator_id = c.meta_operator_id
 WHERE c.meta_column = 'NOMINAL_1'
 AND c.value IS NOT NULL;

-- Disable triggers
BEGIN
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_BE_INS_UPD_CONF_EXCH_AUDIT DISABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_BULK_PAYMENT DISABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_PAYMENT DISABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_PAYMENT_STATUS DISABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_TR_STATUS DISABLE';
 DBMS_OUTPUT.PUT_LINE('Triggers disabled');
EXCEPTION
 WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE('WARNING disabling triggers: ' || SQLERRM);
END;
/

PROMPT === Step 1: Randomize NOMINAL_1 ===
DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.payment p
 SET nominal_1 = ROUND(p.nominal_1 * (0.5 + DBMS_RANDOM.VALUE(0, 1)), 2)
 WHERE p.nominal_1 IS NOT NULL;
 v_count := SQL%ROWCOUNT;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('Step 1 DONE: ' || v_count || ' payment.nominal_1 values randomized');
END;
/

PROMPT === Step 2: Sync NOMINAL_2 = NOMINAL_1 ===
DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.payment
 SET nominal_2 = nominal_1
 WHERE nominal_1 IS NOT NULL;
 v_count := SQL%ROWCOUNT;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('Step 2 DONE: ' || v_count || ' payment.nominal_2 synced');
END;
/

PROMPT === Step 3: Recalculate bulk_payment.total_amount ===
DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.bulk_payment bp
 SET bp.total_amount = (
 SELECT COALESCE(SUM(p.nominal_1), 0)
 FROM oppayments.payment p
 WHERE p.bulk_payment_id = bp.bulk_payment_id
 )
 WHERE EXISTS (
 SELECT 1 FROM oppayments.payment p
 WHERE p.bulk_payment_id = bp.bulk_payment_id
 );
 v_count := SQL%ROWCOUNT;
 COMMIT;
 DBMS_OUTPUT.PUT_LINE('Step 3 DONE: ' || v_count || ' bulk_payment.total_amount recalculated');
END;
/

PROMPT === Step 4: Re-enable triggers ===
BEGIN
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_BE_INS_UPD_CONF_EXCH_AUDIT ENABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_BULK_PAYMENT ENABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_PAYMENT ENABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_PAYMENT_STATUS ENABLE';
 EXECUTE IMMEDIATE 'ALTER TRIGGER oppayments.ON_UPDATE_TR_STATUS ENABLE';
 DBMS_OUTPUT.PUT_LINE('Triggers re-enabled');
EXCEPTION
 WHEN OTHERS THEN
 DBMS_OUTPUT.PUT_LINE('WARNING re-enabling triggers: ' || SQLERRM);
END;
/

-- Cleanup
BEGIN
 EXECUTE IMMEDIATE 'DROP TABLE temp_nominal_constraints';
EXCEPTION
 WHEN OTHERS THEN NULL;
END;
/

PROMPT === Verification ===
SELECT COUNT(*) AS payments_with_amounts FROM oppayments.payment WHERE nominal_1 IS NOT NULL;
SELECT MIN(nominal_1) AS min_amount, MAX(nominal_1) AS max_amount, ROUND(AVG(nominal_1), 2) AS avg_amount FROM oppayments.payment WHERE nominal_1 IS NOT NULL;

PROMPT Script 5 COMPLETE.