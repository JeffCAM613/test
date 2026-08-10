-- ============================================================================
-- EPF/OPPAYMENTS Anonymization — Phase 8: SWIFT Message Fields + Audit Trail
-- ============================================================================
-- PURPOSE: Anonymize sensitive data in SWIFT confirmation exchange tables
-- and audit trail that were not covered by the BIC scripts.
--
-- TABLES:
-- 1. oppayments.CONFIRMATION_EXCHANGE_DETAILS — key 83J (ordering customer name)
-- 2. oppayments.CONFIRMATION_EXCHANGE_INFO — key 83J (if present)
-- 3. oppayments.AUDIT_TRAIL — IP addresses, session IDs
--
-- CONTEXT:
-- The existing BIC scripts only anonymize keys 87A/BIC/82A/22C (bank BICs).
-- Key 83J = SWIFT field "Sender's Correspondent" which contains /NAME/<entity>
-- format with real company names. Found: 11,349 rows with "SONEPAR SAS".
--
-- CONNECT AS: OPPAYMENTS schema owner
-- DEPENDS ON: None (independent)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT PHASE 8: SWIFT Message Fields + Audit Trail Anonymization
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- STEP 1: CONFIRMATION_EXCHANGE_DETAILS — Anonymize key 83J (value_sender)
-- Format: /NAME/<company name> → /NAME/ENTITY_<rownum>
-- ============================================================================
PROMPT [Step 1/4] Anonymizing CONFIRMATION_EXCHANGE_DETAILS value_sender (key 83J)...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.CONFIRMATION_EXCHANGE_DETAILS SET
 VALUE_SENDER = '/NAME/ENTITY_' || ABS(MOD(ORA_HASH(ROWID), 9999999))
 WHERE KEY_SENDER = '83J'
 AND VALUE_SENDER IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 1] CONFIRMATION_EXCHANGE_DETAILS value_sender (83J): ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 2: CONFIRMATION_EXCHANGE_DETAILS — Anonymize key 83J (value_reciver)
-- ============================================================================
PROMPT [Step 2/4] Anonymizing CONFIRMATION_EXCHANGE_DETAILS value_reciver (key 83J)...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.CONFIRMATION_EXCHANGE_DETAILS SET
 VALUE_RECIVER = '/NAME/ENTITY_' || ABS(MOD(ORA_HASH(ROWID), 9999999))
 WHERE KEY_RECIVER = '83J'
 AND VALUE_RECIVER IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 2] CONFIRMATION_EXCHANGE_DETAILS value_reciver (83J): ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 3: CONFIRMATION_EXCHANGE_INFO — Anonymize key 83J (if present)
-- ============================================================================
PROMPT [Step 3/4] Anonymizing CONFIRMATION_EXCHANGE_INFO value (key 83J)...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.CONFIRMATION_EXCHANGE_INFO SET
 VALUE = '/NAME/ENTITY_' || ABS(MOD(ORA_HASH(ROWID), 9999999))
 WHERE KEY = '83J'
 AND VALUE IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 3] CONFIRMATION_EXCHANGE_INFO (83J): ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 4: AUDIT_TRAIL — Anonymize IP addresses
-- Internal IPs (10.x.x.x) can identify specific machines/users.
-- Replace with generic RFC5737 documentation range (192.0.2.x).
-- ============================================================================
PROMPT [Step 4/4] Anonymizing AUDIT_TRAIL remote_address...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.AUDIT_TRAIL SET
 REMOTE_ADDRESS = CASE WHEN REMOTE_ADDRESS IS NOT NULL
 THEN '192.0.2.' || (MOD(ABS(ORA_HASH(REMOTE_ADDRESS)), 254) + 1)
 END
 WHERE REMOTE_ADDRESS IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 4] AUDIT_TRAIL remote_address: ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PROMPT
PROMPT ====================================================================
PROMPT VERIFICATION
PROMPT ====================================================================
PROMPT

PROMPT [Verify] CONFIRMATION_EXCHANGE_DETAILS 83J (expect /NAME/ENTITY_ prefix):

SELECT KEY_SENDER, VALUE_SENDER, KEY_RECIVER, VALUE_RECIVER
FROM oppayments.CONFIRMATION_EXCHANGE_DETAILS
WHERE KEY_SENDER = '83J' AND ROWNUM <= 3;

PROMPT
PROMPT [Verify] AUDIT_TRAIL (expect 192.0.2.x addresses):

SELECT REMOTE_ADDRESS, SUBSTR(AUDIT_COMMENT, 1, 30) AS COMMENT_PREVIEW
FROM oppayments.AUDIT_TRAIL
WHERE REMOTE_ADDRESS IS NOT NULL AND ROWNUM <= 3;

PROMPT
PROMPT ====================================================================
PROMPT PHASE 8 COMPLETE
PROMPT ====================================================================
PROMPT