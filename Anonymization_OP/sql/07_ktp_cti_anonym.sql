-- ============================================================================
-- KTP/CTI Anonymization Extension
-- ============================================================================
-- PURPOSE: Anonymize KTP/CTI-specific tables that are NOT covered by
-- the standard OP anonymization (06_op_setbased_anonym.sql)
--
-- TABLES FROM REFERENCE (12 tables):
-- 1. charge_contract_criteria (entity, bank, account)
-- 2. charge_contract_process (entity, bank, account)
-- 3. charge_contract_process (entity, bank, account)
-- 4. mpm_file_bkd (entity, counterparty, account)
-- 5. trade_repository_breakdown (entity)
-- 6. val_cptyrating (counterparty) - NOTE: different from ctpyrating!
-- 7. val_currency_account (entity, compte)
-- 8. val_security_account (entite, depositaire, numero_compte, groupe_1/2/3, correspondant, contrepartie)
-- 9. val_ssi_account (portefeuille, depositaire, compte, tiers_entite)
-- 10. val_ssi_corresp (banque, contrepartie, correspondant_1/2, tiers_entite)
-- 11. val_third_party_limit (entite, tiers)
-- 12. val_user (description)
--
-- PARAMETERS (passed from start_anonymous_v3.sql):
-- &1 = EntC (Entite code rename y/n)
-- &2 = FoldC (Portefeuille code rename y/n)
-- &3 = TierC (Tiers/Counterparty code rename y/n)
-- &4 = CpteC (Compte/Bank Account code rename y/n)
--
-- TYPE MAPPING:
-- E = Entity only → only if EntC=y
-- P = Portfolio only → only if FoldC=y
-- C = Counterparty only → only if TierC=y
-- BA = Bank Account only → only if CpteC=y
-- E,P,C = Mixed → if ANY of EntC/FoldC/TierC=y
-- * = Free-text → ALWAYS anonymize (NULL it)
--
-- HANDLING MISSING TABLES/COLUMNS:
-- - Tables/columns that don't exist on this instance are SKIPPED (no error)
-- - This allows same script to run on all KTP/CTI instances
--
-- PREREQUISITES:
-- - Run AFTER 06_op_setbased_anonym.sql (requires atrace.op_code_mapping)
-- - Run as OP schema owner
-- - Triggers must be DISABLED
--
-- VERIFIED: 2026-07-07 against multiple KTP/CTI OP databases (Oracle 19c)
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
PROMPT KTP/CTI Tables Anonymization (12 tables from reference)
PROMPT ====================================================================
PROMPT User selections: EntC=&p_EntC FoldC=&p_FoldC TierC=&p_TierC CpteC=&p_CpteC
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- Verify mapping table exists (created by 06_op_setbased_anonym.sql)
-- ============================================================================
DECLARE
 v_cnt NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_cnt FROM atrace.op_code_mapping;
 DBMS_OUTPUT.PUT_LINE(' Code mappings available: ' || v_cnt);
 IF v_cnt = 0 THEN
 RAISE_APPLICATION_ERROR(-20001, 'ERROR: No code mappings found. Run 06_op_setbased_anonym.sql first!');
 END IF;
END;
/

-- ============================================================================
-- PHASE KTP-1: Charge tables (3 tables, 9 columns)
-- Types: entity=E, bank=E/P/C, account=BA
-- ============================================================================
PROMPT
PROMPT === Phase KTP-1: Charge tables ===

BEGIN
 -- 1. charge_contract_criteria
 -- entity (E) - only if EntC=y
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('charge_contract_criteria', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_criteria.entity: SKIPPED (EntC=n)');
 END IF;
 
 -- bank (E,P,C) - if any of EntC/FoldC/TierC=y
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('charge_contract_criteria', 'bank');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_criteria.bank: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
 
 -- account (BA) - only if CpteC=y
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('charge_contract_criteria', 'account', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_criteria.account: SKIPPED (CpteC=n)');
 END IF;

 -- 2. charge_contract_process
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('charge_contract_process', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_process.entity: SKIPPED (EntC=n)');
 END IF;
 
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('charge_contract_process', 'bank');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_process.bank: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
 
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('charge_contract_process', 'account', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_contract_process.account: SKIPPED (CpteC=n)');
 END IF;

 -- 3. charge_missing_process
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('charge_missing_process', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_missing_process.entity: SKIPPED (EntC=n)');
 END IF;
 
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('charge_missing_process', 'bank');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_missing_process.bank: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
 
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('charge_missing_process', 'account', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' charge_missing_process.account: SKIPPED (CpteC=n)');
 END IF;
END;
/

-- ============================================================================
-- PHASE KTP-2: MPM and Trade Repository tables (2 tables, 4 columns)
-- ============================================================================
PROMPT
PROMPT === Phase KTP-2: MPM and Trade Repository tables ===

BEGIN
 -- 4. mpm_file_bkd: entity(E), counterparty(E,P,C), account(BA)
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('mpm_file_bkd', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' mpm_file_bkd.entity: SKIPPED (EntC=n)');
 END IF;
 
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('mpm_file_bkd', 'counterparty');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' mpm_file_bkd.counterparty: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
 
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('mpm_file_bkd', 'account', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' mpm_file_bkd.account: SKIPPED (CpteC=n)');
 END IF;

 -- 5. trade_repository_breakdown: entity(E)
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('trade_repository_breakdown', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' trade_repository_breakdown.entity: SKIPPED (EntC=n)');
 END IF;
END;
/
-- ============================================================================
-- PHASE KTP-3: VAL tables (7 tables)
-- ============================================================================
PROMPT
PROMPT === Phase KTP-3: VAL tables ===

BEGIN
 -- 6. val_cptyrating: counterparty(E,P,C)
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('val_cptyrating', 'counterparty');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_cptyrating.counterparty: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;

 -- 7. val_currency_account: entity(E), compte(BA)
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('val_currency_account', 'entity');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_currency_account.entity: SKIPPED (EntC=n)');
 END IF;
 
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('val_currency_account', 'compte', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_currency_account.compte: SKIPPED (CpteC=n)');
 END IF;

 -- 8. val_security_account: entite(E), depositaire(E,P,C), correspondant(E,P,C), contrepartie(E,P,C)
 IF '&p_EntC' = 'y' THEN
 op.merge_codes('val_security_account', 'entite');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_security_account.entite: SKIPPED (EntC=n)');
 END IF;
 
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('val_security_account', 'depositaire');
 op.merge_codes('val_security_account', 'correspondant');
 op.merge_codes('val_security_account', 'contrepartie');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_security_account.depositaire: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_security_account.correspondant: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_security_account.contrepartie: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
 -- Note: numero_compte, groupe_1/2/3 are free-text (*) - handled below (ALWAYS)
END;
/

-- Blank free-text fields in val_security_account (numero_compte, groupe_1/2/3)
-- Type: * (free-text) - ALWAYS anonymize regardless of flags
DECLARE v_cnt NUMBER;
BEGIN
 UPDATE op.val_security_account SET 
 numero_compte = NULL,
 groupe_1 = NULL,
 groupe_2 = NULL,
 groupe_3 = NULL
 WHERE numero_compte IS NOT NULL 
 OR groupe_1 IS NOT NULL 
 OR groupe_2 IS NOT NULL 
 OR groupe_3 IS NOT NULL;
 v_cnt := SQL%ROWCOUNT;
 COMMIT;
 IF v_cnt > 0 THEN
 DBMS_OUTPUT.PUT_LINE(' val_security_account (numero_compte, groupe_1/2/3): ' || v_cnt || ' rows NULLed');
 END IF;
EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -942 THEN
 DBMS_OUTPUT.PUT_LINE(' val_security_account: SKIPPED (table not found)');
 ELSE
 RAISE;
 END IF;
END;
/

BEGIN
 -- 9. val_ssi_account: portefeuille(P), depositaire(BA), compte(BA), tiers_entite(E,P,C)
 IF '&p_FoldC' = 'y' THEN
 op.merge_codes('val_ssi_account', 'portefeuille');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_ssi_account.portefeuille: SKIPPED (FoldC=n)');
 END IF;
 
 IF '&p_CpteC' = 'y' THEN
 op.merge_codes('val_ssi_account', 'depositaire');
 op.merge_codes('val_ssi_account', 'compte', p_entity_type => 'COMPTE');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_ssi_account.depositaire: SKIPPED (CpteC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_ssi_account.compte: SKIPPED (CpteC=n)');
 END IF;
 
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('val_ssi_account', 'tiers_entite');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_ssi_account.tiers_entite: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;

 -- 10. val_ssi_corresp: all columns are E,P,C type
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('val_ssi_corresp', 'banque');
 op.merge_codes('val_ssi_corresp', 'contrepartie');
 op.merge_codes('val_ssi_corresp', 'correspondant_1');
 op.merge_codes('val_ssi_corresp', 'correspondant_2');
 op.merge_codes('val_ssi_corresp', 'tiers_entite');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_ssi_corresp.banque: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_ssi_corresp.contrepartie: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_ssi_corresp.correspondant_1: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_ssi_corresp.correspondant_2: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_ssi_corresp.tiers_entite: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;

 -- 11. val_third_party_limit: entite(E,P,C), tiers(E,P,C)
 IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
 op.merge_codes('val_third_party_limit', 'entite');
 op.merge_codes('val_third_party_limit', 'tiers');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' val_third_party_limit.entite: SKIPPED (EntC/FoldC/TierC=n)');
 DBMS_OUTPUT.PUT_LINE(' val_third_party_limit.tiers: SKIPPED (EntC/FoldC/TierC=n)');
 END IF;
END;
/

-- ============================================================================
-- PHASE KTP-4: val_user description (free-text - ALWAYS NULL it)
-- Type: * (free-text) - ALWAYS anonymize regardless of flags
-- ============================================================================
PROMPT
PROMPT === Phase KTP-4: val_user description ===

-- 12. val_user
DECLARE v_cnt NUMBER;
BEGIN
 UPDATE op.val_user SET description = NULL WHERE description IS NOT NULL;
 v_cnt := SQL%ROWCOUNT;
 COMMIT;
 IF v_cnt > 0 THEN
 DBMS_OUTPUT.PUT_LINE(' val_user.description: ' || v_cnt || ' rows NULLed');
 END IF;
EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -942 THEN
 DBMS_OUTPUT.PUT_LINE(' val_user: SKIPPED (table not found)');
 ELSE
 RAISE;
 END IF;
END;
/

PROMPT
PROMPT ====================================================================
PROMPT KTP/CTI Tables Anonymization COMPLETE
PROMPT ====================================================================