-- ============================================================================
-- EPF/OPPAYMENTS Anonymization — Phase 7: Reference Data (REF_TIERS, REF_BANK_BRANCHE)
-- ============================================================================
-- PURPOSE: Anonymize reference/lookup tables that still contain real company
-- names and bank identifiers after the main anonymization phases.
--
-- TABLES:
-- 1. oppayments.REF_TIERS (~2499 rows) — Counterparty reference data
-- 2. oppayments.REF_BANK_BRANCHE — Bank/branch reference data
--
-- NOTES:
-- - These tables are INDEPENDENT from op.TIERS (different code format)
-- - PAYMENT FK fields do NOT reference these tables
-- - Used only in Admin UI (list/detail views, dropdowns)
-- - Safe to anonymize without cascading
-- - Idempotent: re-running will overwrite with new random values
--
-- CONNECT AS: OPPAYMENTS schema owner
-- DEPENDS ON: None (independent of other phases)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT PHASE 7: Reference Data Anonymization (REF_TIERS + REF_BANK_BRANCHE)
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- STEP 1: REF_TIERS — Anonymize description, addresses, user fields
-- ============================================================================
PROMPT [Step 1/4] Anonymizing REF_TIERS descriptions and addresses...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.REF_TIERS SET
 DESCRIPTION = 'TIER_' || REF_TIERS_ID,
 ADRESSE1 = CASE WHEN ADRESSE1 IS NOT NULL THEN 'ADDR1_' || REF_TIERS_ID END,
 ADRESSE2 = CASE WHEN ADRESSE2 IS NOT NULL THEN 'ADDR2_' || REF_TIERS_ID END,
 ADRESSE3 = CASE WHEN ADRESSE3 IS NOT NULL THEN 'ADDR3_' || REF_TIERS_ID END,
 POSTAL_CODE = CASE WHEN POSTAL_CODE IS NOT NULL THEN 'PC' || MOD(REF_TIERS_ID, 99999) END,
 TOWN = CASE WHEN TOWN IS NOT NULL THEN 'TOWN_' || REF_TIERS_ID END,
 CTRYSUBDVSN = CASE WHEN CTRYSUBDVSN IS NOT NULL THEN 'REG_' || REF_TIERS_ID END,
 USER_CREATION = 'SYSTEM',
 USER_LAST_MODIF = 'SYSTEM';

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 1] REF_TIERS descriptions/addresses: ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 2: REF_TIERS — Anonymize BIC components (if populated)
-- ============================================================================
PROMPT [Step 2/4] Anonymizing REF_TIERS BIC components...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.REF_TIERS SET
 BANK_CODE = CASE WHEN BANK_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('U', 4), 1, 4) END,
 ISO_COUNTRY_CODE = CASE WHEN ISO_COUNTRY_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('U', 2), 1, 2) END,
 LOCATION_CODE = CASE WHEN LOCATION_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('X', 2), 1, 2) END,
 BRANCH_CODE = CASE WHEN BRANCH_CODE IS NOT NULL AND BRANCH_CODE != 'XXX'
 THEN SUBSTR(DBMS_RANDOM.STRING('X', 3), 1, 3)
 WHEN BRANCH_CODE = 'XXX' THEN 'XXX' -- preserve head office marker
 END
 WHERE BANK_CODE IS NOT NULL
 OR ISO_COUNTRY_CODE IS NOT NULL
 OR LOCATION_CODE IS NOT NULL
 OR BRANCH_CODE IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 2] REF_TIERS BIC components: ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 3: REF_BANK_BRANCHE — Anonymize description, addresses, BIC, user fields
-- ============================================================================
PROMPT [Step 3/4] Anonymizing REF_BANK_BRANCHE...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.REF_BANK_BRANCHE SET
 DESCRIPTION = 'BANK_' || REF_BANK_BRANCHE_ID,
 ADRESSE1 = CASE WHEN ADRESSE1 IS NOT NULL THEN 'ADDR1_' || REF_BANK_BRANCHE_ID END,
 ADRESSE2 = CASE WHEN ADRESSE2 IS NOT NULL THEN 'ADDR2_' || REF_BANK_BRANCHE_ID END,
 ADRESSE3 = CASE WHEN ADRESSE3 IS NOT NULL THEN 'ADDR3_' || REF_BANK_BRANCHE_ID END,
 POSTAL_CODE = CASE WHEN POSTAL_CODE IS NOT NULL THEN 'PC' || MOD(REF_BANK_BRANCHE_ID, 99999) END,
 TOWN = CASE WHEN TOWN IS NOT NULL THEN 'TOWN_' || REF_BANK_BRANCHE_ID END,
 CTRYSUBDVSN = CASE WHEN CTRYSUBDVSN IS NOT NULL THEN 'REG_' || REF_BANK_BRANCHE_ID END,
 BANK_CODE = CASE WHEN BANK_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('U', 4), 1, 4) END,
 ISO_COUNTRY_CODE = CASE WHEN ISO_COUNTRY_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('U', 2), 1, 2) END,
 LOCATION_CODE = CASE WHEN LOCATION_CODE IS NOT NULL
 THEN SUBSTR(DBMS_RANDOM.STRING('X', 2), 1, 2) END,
 BRANCHE_CODE = CASE WHEN BRANCHE_CODE IS NOT NULL AND BRANCHE_CODE != 'XXX'
 THEN SUBSTR(DBMS_RANDOM.STRING('X', 3), 1, 3)
 WHEN BRANCHE_CODE = 'XXX' THEN 'XXX'
 END,
 CLEAR_CODE_PREFIX = CASE WHEN CLEAR_CODE_PREFIX IS NOT NULL THEN 'CLR_' || REF_BANK_BRANCHE_ID END,
 CLEAR_CODE_BANK_ID = CASE WHEN CLEAR_CODE_BANK_ID IS NOT NULL THEN 'BID_' || REF_BANK_BRANCHE_ID END,
 USER_CREATION = 'SYSTEM',
 USER_LAST_MODIF = 'SYSTEM';

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 3] REF_BANK_BRANCHE: ' || v_count || ' rows updated');
 COMMIT;
END;
/

-- ============================================================================
-- STEP 4: REF_BANK_BRANCHE — Update CODE to match new BIC (for consistency)
-- CODE is typically the full BIC (e.g., BNPAFRPPXXX). After anonymizing BIC
-- components, CODE would be stale. Update it to reflect the new values.
-- ============================================================================
PROMPT [Step 4/4] Updating REF_BANK_BRANCHE CODE to match anonymized BIC...

DECLARE
 v_count NUMBER;
BEGIN
 UPDATE oppayments.REF_BANK_BRANCHE SET
 CODE = NVL(BANK_CODE, 'XXXX')
 || NVL(ISO_COUNTRY_CODE, 'XX')
 || NVL(LOCATION_CODE, 'XX')
 || NVL(BRANCHE_CODE, 'XXX')
 WHERE BANK_CODE IS NOT NULL;

 v_count := SQL%ROWCOUNT;
 DBMS_OUTPUT.PUT_LINE('[Step 4] REF_BANK_BRANCHE CODE updated: ' || v_count || ' rows');
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

PROMPT [Verify] REF_TIERS sample (expect TIER_ prefix, no real names):

SELECT CODE, DESCRIPTION, ADRESSE1, TOWN, BANK_CODE || ISO_COUNTRY_CODE || LOCATION_CODE || BRANCH_CODE AS BIC
FROM oppayments.REF_TIERS
WHERE ROWNUM <= 5;

PROMPT
PROMPT [Verify] REF_BANK_BRANCHE sample (expect BANK_ prefix, no real names):

SELECT CODE, DESCRIPTION, BANK_CODE, ISO_COUNTRY_CODE, LOCATION_CODE, BRANCHE_CODE
FROM oppayments.REF_BANK_BRANCHE
WHERE ROWNUM <= 5;

PROMPT
PROMPT ====================================================================
PROMPT PHASE 7 COMPLETE
PROMPT ====================================================================
PROMPT