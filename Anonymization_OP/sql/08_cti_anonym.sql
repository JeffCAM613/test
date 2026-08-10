-- ============================================================================
-- CTI Anonymization Extension
-- ============================================================================
-- PURPOSE: Anonymize CTI-specific tables in OP schema that are NOT covered by
--          the standard OP anonymization (06_op_setbased_anonym.sql)
--
-- TABLES FROM CTI REFERENCE (34 tables):
--   cm_account_of_bkstmt_file, cm_archived_forecast, cm_bkstmt_file_config,
--   cm_bsi_bank_statement, cm_cash_concent_accounts, cm_cash_concent_header,
--   cm_deal_deal, cm_fli_flow, cm_flow_to_pay_rules, cm_foi_forecast,
--   cm_forecast, cm_payt_payment, cm_pooling_convention, cm_pooling_method,
--   cm_process, cms_file_bkd, cm_cms_exceptions, dm_hedge_request,
--   dm_hr_autovalid_bkd, dm_hr_ctrp_map, dm_hr_cutoff_bkd, dm_hr_limit_bkd,
--   dm_hr_ptf_bkd, dm_hr_quotation, tp_business_profile, tp_comm_entity_dim,
--   tp_contact, tp_data_profile_bankaccount, tp_data_profile_ctrp,
--   tp_data_profile_entity, tp_data_profile_ptf, tp_pos_snapshot,
--   tp_pos_snapshot_results, tp_tenant_entity, tp_users, tp_wv_mailing_rule,
--   tp_wv_transition_rule, uaa_users
--
-- PARAMETERS (passed from start_anonymous_v3.sql):
--   &1 = EntC  (Entite code rename y/n)
--   &2 = FoldC (Portefeuille code rename y/n)
--   &3 = TierC (Tiers/Counterparty code rename y/n)
--   &4 = CpteC (Compte/Bank Account code rename y/n)
--
-- PREREQUISITES:
--   - Run AFTER 06_op_setbased_anonym.sql (requires atrace.op_code_mapping)
--   - Run as OP schema owner
--   - Triggers must be DISABLED
--
-- VERIFIED: 2026-07-08
-- ============================================================================

-- Accept parameters
DEFINE p_EntC  = &1
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
PROMPT  CTI Tables Anonymization (34 tables from reference)
PROMPT ====================================================================
PROMPT  User selections: EntC=&p_EntC  FoldC=&p_FoldC  TierC=&p_TierC  CpteC=&p_CpteC
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- Verify mapping table exists
-- ============================================================================
DECLARE
   v_cnt NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_cnt FROM atrace.op_code_mapping;
   DBMS_OUTPUT.PUT_LINE('  Code mappings available: ' || v_cnt);
   IF v_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'ERROR: No code mappings found. Run 06_op_setbased_anonym.sql first!');
   END IF;
END;
/

-- ============================================================================
-- PHASE CTI-1: CM tables (Cash Management)
-- ============================================================================
PROMPT
PROMPT === Phase CTI-1: CM tables (Cash Management) ===

BEGIN
   -- 1. cm_account_of_bkstmt_file: entity(E), account(BA), bank(E,P,C)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_account_of_bkstmt_file', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_account_of_bkstmt_file', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_account_of_bkstmt_file', 'bank');
   END IF;

   -- 2. cm_archived_forecast: entity(E), bank(C)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_archived_forecast', 'entity');
   END IF;
   IF '&p_TierC' = 'y' THEN
      op.merge_codes('cm_archived_forecast', 'bank');
   END IF;

   -- 3. cm_bkstmt_file_config: collator(E,P,C), bank(E,P,C)
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_bkstmt_file_config', 'collator');
      op.merge_codes('cm_bkstmt_file_config', 'bank');
   END IF;

   -- 4. cm_bsi_bank_statement: entity(E), bank_account(BA)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_bsi_bank_statement', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_bsi_bank_statement', 'bank_account', p_entity_type => 'COMPTE');
   END IF;

   -- 5. cm_cash_concent_accounts: entity(E), account(BA), bank(E,P,C)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_cash_concent_accounts', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_cash_concent_accounts', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_cash_concent_accounts', 'bank');
   END IF;
END;
/

-- 6. cm_cash_concent_header (many columns)
BEGIN
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_cash_concent_header', 'master_account', p_entity_type => 'COMPTE');
      op.merge_codes('cm_cash_concent_header', 'compte_tiers', p_entity_type => 'COMPTE');
      op.merge_codes('cm_cash_concent_header', 'compte_entite', p_entity_type => 'COMPTE');
      op.merge_codes('cm_cash_concent_header', 'compte_filiale', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_cash_concent_header', 'entity');
   END IF;
   IF '&p_TierC' = 'y' THEN
      op.merge_codes('cm_cash_concent_header', 'filiale');
      op.merge_codes('cm_cash_concent_header', 'intermediaire');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_cash_concent_header', 'portefeuille');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_cash_concent_header', 'contrepartie');
      op.merge_codes('cm_cash_concent_header', 'correspondant_1');
      op.merge_codes('cm_cash_concent_header', 'correspondant_2');
      op.merge_codes('cm_cash_concent_header', 'correspondant_3');
      op.merge_codes('cm_cash_concent_header', 'correspondant_4');
      op.merge_codes('cm_cash_concent_header', 'correspondant_5');
      op.merge_codes('cm_cash_concent_header', 'portefeuille_tiers');
      op.merge_codes('cm_cash_concent_header', 'depositaire');
      op.merge_codes('cm_cash_concent_header', 'depositaire_2');
      op.merge_codes('cm_cash_concent_header', 'emetteur');
      op.merge_codes('cm_cash_concent_header', 'correspondant_sender1');
      op.merge_codes('cm_cash_concent_header', 'correspondant_sender2');
      op.merge_codes('cm_cash_concent_header', 'correspondant_receiver1');
      op.merge_codes('cm_cash_concent_header', 'correspondant_receiver2');
   END IF;
END;
/

-- cm_cash_concent_header free-text fields (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_cash_concent_header SET 
      description = NULL, groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
   WHERE description IS NOT NULL OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN
      DBMS_OUTPUT.PUT_LINE('  cm_cash_concent_header (description,groupe_1/2/3): ' || v_cnt || ' rows NULLed');
   END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_cash_concent_header: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 7. cm_deal_deal (many columns - largest CTI table)
BEGIN
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_deal_deal', 'compte_tiers', p_entity_type => 'COMPTE');
      op.merge_codes('cm_deal_deal', 'compte_entite', p_entity_type => 'COMPTE');
      op.merge_codes('cm_deal_deal', 'compte_filiale', p_entity_type => 'COMPTE');
      op.merge_codes('cm_deal_deal', 'compte_tiers_2', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_deal_deal', 'entity');
   END IF;
   IF '&p_TierC' = 'y' THEN
      op.merge_codes('cm_deal_deal', 'filiale');
      op.merge_codes('cm_deal_deal', 'intermediaire');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_deal_deal', 'portefeuille');
      op.merge_codes('cm_deal_deal', 'portefeuille_deposit');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_deal_deal', 'contrepartie');
      op.merge_codes('cm_deal_deal', 'correspondant_1');
      op.merge_codes('cm_deal_deal', 'correspondant_2');
      op.merge_codes('cm_deal_deal', 'correspondant_3');
      op.merge_codes('cm_deal_deal', 'correspondant_4');
      op.merge_codes('cm_deal_deal', 'correspondant_5');
      op.merge_codes('cm_deal_deal', 'correspondant_6');
      op.merge_codes('cm_deal_deal', 'correspondant_7');
      op.merge_codes('cm_deal_deal', 'correspondant_8');
      op.merge_codes('cm_deal_deal', 'correspondant_9');
      op.merge_codes('cm_deal_deal', 'correspondant_10');
      op.merge_codes('cm_deal_deal', 'portefeuille_tiers');
      op.merge_codes('cm_deal_deal', 'depositaire');
      op.merge_codes('cm_deal_deal', 'depositaire_2');
      op.merge_codes('cm_deal_deal', 'emetteur');
      op.merge_codes('cm_deal_deal', 'correspondant_sender1');
      op.merge_codes('cm_deal_deal', 'correspondant_sender2');
      op.merge_codes('cm_deal_deal', 'correspondant_receiver1');
      op.merge_codes('cm_deal_deal', 'correspondant_receiver2');
      op.merge_codes('cm_deal_deal', 'compensateur');
      op.merge_codes('cm_deal_deal', 'depositaire_bis');
      op.merge_codes('cm_deal_deal', 'depositaire_2_bis');
      op.merge_codes('cm_deal_deal', 'corresp_inter_sender1');
      op.merge_codes('cm_deal_deal', 'corresp_inter_sender2');
      op.merge_codes('cm_deal_deal', 'corresp_inter_receiver1');
      op.merge_codes('cm_deal_deal', 'corresp_inter_receiver2');
      op.merge_codes('cm_deal_deal', 'clearing_member');
   END IF;
END;
/

-- cm_deal_deal free-text fields (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_deal_deal SET 
      groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL,
      tiers_rib_banque = NULL, tiers_rib_guichet = NULL, tiers_rib_compte = NULL, tiers_rib_cle = NULL,
      tiers_iban_compte = NULL, tiers_iban_pays = NULL, tiers_iban_cle = NULL
   WHERE groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL
      OR tiers_rib_banque IS NOT NULL OR tiers_rib_guichet IS NOT NULL 
      OR tiers_rib_compte IS NOT NULL OR tiers_rib_cle IS NOT NULL
      OR tiers_iban_compte IS NOT NULL OR tiers_iban_pays IS NOT NULL OR tiers_iban_cle IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN
      DBMS_OUTPUT.PUT_LINE('  cm_deal_deal (groupe_*,tiers_rib_*,tiers_iban_*): ' || v_cnt || ' rows NULLed');
   END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_deal_deal: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 8. cm_fli_flow
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_fli_flow', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_fli_flow', 'portfolio');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_fli_flow', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_fli_flow', 'counterparty');
   END IF;
END;
/

-- cm_fli_flow free-text (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_fli_flow SET group1 = NULL, group2 = NULL, group3 = NULL
   WHERE group1 IS NOT NULL OR group2 IS NOT NULL OR group3 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  cm_fli_flow (group1/2/3): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_fli_flow: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 9. cm_flow_to_pay_rules: entity(E), bank(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_flow_to_pay_rules', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_flow_to_pay_rules', 'bank');
   END IF;
END;
/

-- 10. cm_foi_forecast: entity(E), bank(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_foi_forecast', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_foi_forecast', 'bank');
   END IF;
END;
/

-- 11. cm_forecast: entity(E), bank(E,P,C), branch(E,P,C), subsidiary_cpty(E,P,C), portfolio(P), corresp_*
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_forecast', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_forecast', 'portfolio');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_forecast', 'bank');
      op.merge_codes('cm_forecast', 'branch');
      op.merge_codes('cm_forecast', 'subsidiary_cpty');
      op.merge_codes('cm_forecast', 'corresp_receiver1');
      op.merge_codes('cm_forecast', 'corresp_receiver2');
      op.merge_codes('cm_forecast', 'corresp_sender1');
      op.merge_codes('cm_forecast', 'corresp_sender2');
   END IF;
END;
/

-- cm_forecast free-text (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_forecast SET group1 = NULL, group2 = NULL, group3 = NULL
   WHERE group1 IS NOT NULL OR group2 IS NOT NULL OR group3 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  cm_forecast (group1/2/3): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_forecast: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 12. cm_payt_payment (many columns)
BEGIN
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_payt_payment', 'portfolio');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('cm_payt_payment', 'cpty_account_code', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_payt_payment', 'corresp_receiver1');
      op.merge_codes('cm_payt_payment', 'corresp_receiver2');
      op.merge_codes('cm_payt_payment', 'corresp_sender1');
      op.merge_codes('cm_payt_payment', 'corresp_sender2');
   END IF;
END;
/

-- cm_payt_payment free-text (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_payt_payment SET 
      group1 = NULL, group2 = NULL, group3 = NULL,
      iban_key = NULL, bban_code = NULL,
      free_tiers_1 = NULL, free_tiers_2 = NULL, free_tiers_3 = NULL,
      groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
   WHERE group1 IS NOT NULL OR group2 IS NOT NULL OR group3 IS NOT NULL
      OR iban_key IS NOT NULL OR bban_code IS NOT NULL
      OR free_tiers_1 IS NOT NULL OR free_tiers_2 IS NOT NULL OR free_tiers_3 IS NOT NULL
      OR groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  cm_payt_payment (free-text fields): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_payt_payment: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 13. cm_pooling_convention: entity(E), counterparty(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_pooling_convention', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_pooling_convention', 'counterparty');
   END IF;
END;
/

-- cm_pooling_convention free-text (ALWAYS)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_pooling_convention SET value_1 = NULL, value_2 = NULL
   WHERE value_1 IS NOT NULL OR value_2 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  cm_pooling_convention (value_1/2): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_pooling_convention: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 14. cm_pooling_method: groupe_1/2/3 (free-text only)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.cm_pooling_method SET groupe_1 = NULL, groupe_2 = NULL, groupe_3 = NULL
   WHERE groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  cm_pooling_method (groupe_1/2/3): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  cm_pooling_method: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 15. cm_process: entity(E)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_process', 'entity');
   END IF;
END;
/

-- 16. cms_file_bkd: entity(E), counterparty(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cms_file_bkd', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cms_file_bkd', 'counterparty');
   END IF;
END;
/

-- 17. cm_cms_exceptions: entity(E), counterparty(E,P,C), portfolio(P), issuer(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('cm_cms_exceptions', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('cm_cms_exceptions', 'portfolio');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('cm_cms_exceptions', 'counterparty');
      op.merge_codes('cm_cms_exceptions', 'issuer');
   END IF;
END;
/

-- ============================================================================
-- PHASE CTI-2: DM tables (Deal Management / Hedging)
-- ============================================================================
PROMPT
PROMPT === Phase CTI-2: DM tables (Deal Management) ===

BEGIN
   -- 18. dm_hedge_request: entity(E), counterparty(E,P,C), portfolio(P)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('dm_hedge_request', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('dm_hedge_request', 'portfolio');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('dm_hedge_request', 'counterparty');
   END IF;

   -- 19. dm_hr_autovalid_bkd: entity(E)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('dm_hr_autovalid_bkd', 'entity');
   END IF;

   -- 20. dm_hr_ctrp_map: counterparty(E,P,C)
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('dm_hr_ctrp_map', 'counterparty');
   END IF;

   -- 21. dm_hr_cutoff_bkd: entity(E), counterparty(E,P,C), portfolio(P)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('dm_hr_cutoff_bkd', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('dm_hr_cutoff_bkd', 'portfolio');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('dm_hr_cutoff_bkd', 'counterparty');
   END IF;

   -- 22. dm_hr_limit_bkd: entity(E), portfolio(P)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('dm_hr_limit_bkd', 'entity');
   END IF;
   IF '&p_FoldC' = 'y' THEN
      op.merge_codes('dm_hr_limit_bkd', 'portfolio');
   END IF;

   -- 23. dm_hr_ptf_bkd: issuer(E,P,C), cts_counterparty(E,P,C)
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('dm_hr_ptf_bkd', 'issuer');
      op.merge_codes('dm_hr_ptf_bkd', 'cts_counterparty');
   END IF;

   -- 24. dm_hr_quotation: entity(E), account(BA), bank(E,P,C)
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('dm_hr_quotation', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('dm_hr_quotation', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('dm_hr_quotation', 'bank');
   END IF;
END;
/

-- dm_hr_quotation free-text (ALWAYS) - phone
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.dm_hr_quotation SET phone = NULL WHERE phone IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  dm_hr_quotation (phone): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  dm_hr_quotation: SKIPPED (table not found)');
   ELSIF SQLCODE = -904 THEN DBMS_OUTPUT.PUT_LINE('  dm_hr_quotation (phone): SKIPPED (column not found)');
   ELSE RAISE; END IF;
END;
/

-- ============================================================================
-- PHASE CTI-3: TP tables (Third Party / Contact Management)
-- ============================================================================
PROMPT
PROMPT === Phase CTI-3: TP tables (Third Party) ===

-- 25. tp_business_profile: description(*) only
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tp_business_profile SET description = NULL WHERE description IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  tp_business_profile (description): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  tp_business_profile: SKIPPED (table not found)');
   ELSE RAISE; END IF;
END;
/

-- 26. tp_comm_entity_dim: entity(E), account(BA), bank(E,P,C), phone(*), mobile(*), name(*), email(*)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_comm_entity_dim', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('tp_comm_entity_dim', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_comm_entity_dim', 'bank');
   END IF;
END;
/

DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tp_comm_entity_dim SET phone = NULL, mobile = NULL, name = NULL, email = NULL
   WHERE phone IS NOT NULL OR mobile IS NOT NULL OR name IS NOT NULL OR email IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  tp_comm_entity_dim (phone,mobile,name,email): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  tp_comm_entity_dim: SKIPPED (table not found)');
   ELSIF SQLCODE = -904 THEN DBMS_OUTPUT.PUT_LINE('  tp_comm_entity_dim (PII): SKIPPED (some columns not found)');
   ELSE RAISE; END IF;
END;
/

-- 27. tp_contact: entity(E), bank_account(BA)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_contact', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('tp_contact', 'bank_account', p_entity_type => 'COMPTE');
   END IF;
END;
/

-- 28. tp_data_profile_bankaccount: counterparty(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_data_profile_bankaccount', 'counterparty');
   END IF;
END;
/

-- 29. tp_data_profile_ctrp: entity(E)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_data_profile_ctrp', 'entity');
   END IF;
END;
/

-- 30. tp_data_profile_entity: portfolio(E) - note: column seems misnamed in reference
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_data_profile_entity', 'portfolio');
   END IF;
END;
/

-- 31. tp_data_profile_ptf: account(BA), bank(E,P,C)
BEGIN
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('tp_data_profile_ptf', 'account', p_entity_type => 'COMPTE');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_data_profile_ptf', 'bank');
   END IF;
END;
/

-- 32. tp_pos_snapshot: entity(E), account(BA)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_pos_snapshot', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('tp_pos_snapshot', 'account', p_entity_type => 'COMPTE');
   END IF;
END;
/

-- 33. tp_pos_snapshot_results: entity(E), account(BA), + PII fields
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_pos_snapshot_results', 'entity');
   END IF;
   IF '&p_CpteC' = 'y' THEN
      op.merge_codes('tp_pos_snapshot_results', 'account', p_entity_type => 'COMPTE');
   END IF;
END;
/

DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tp_pos_snapshot_results SET 
      description = NULL, firstname = NULL, lastname = NULL, email = NULL, phone_number = NULL
   WHERE description IS NOT NULL OR firstname IS NOT NULL OR lastname IS NOT NULL 
      OR email IS NOT NULL OR phone_number IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  tp_pos_snapshot_results (PII fields): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  tp_pos_snapshot_results: SKIPPED (table not found)');
   ELSIF SQLCODE = -904 THEN DBMS_OUTPUT.PUT_LINE('  tp_pos_snapshot_results (PII): SKIPPED (some columns not found)');
   ELSE RAISE; END IF;
END;
/

-- 34. tp_tenant_entity: entity(E)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_tenant_entity', 'entity');
   END IF;
END;
/

-- 35. tp_users: entity(E), counterparty(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_users', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_users', 'counterparty');
   END IF;
END;
/

-- 36. tp_wv_mailing_rule: entity(E), counterparty(E,P,C), + PII
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_wv_mailing_rule', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_wv_mailing_rule', 'counterparty');
   END IF;
END;
/

DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tp_wv_mailing_rule SET 
      description = NULL, firstname = NULL, lastname = NULL, email = NULL, phone_number = NULL
   WHERE description IS NOT NULL OR firstname IS NOT NULL OR lastname IS NOT NULL 
      OR email IS NOT NULL OR phone_number IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  tp_wv_mailing_rule (PII fields): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  tp_wv_mailing_rule: SKIPPED (table not found)');
   ELSIF SQLCODE = -904 THEN DBMS_OUTPUT.PUT_LINE('  tp_wv_mailing_rule (PII): SKIPPED (some columns not found)');
   ELSE RAISE; END IF;
END;
/

-- 37. tp_wv_transition_rule: entity(E), counterparty(E,P,C)
BEGIN
   IF '&p_EntC' = 'y' THEN
      op.merge_codes('tp_wv_transition_rule', 'entity');
   END IF;
   IF '&p_EntC' = 'y' OR '&p_FoldC' = 'y' OR '&p_TierC' = 'y' THEN
      op.merge_codes('tp_wv_transition_rule', 'counterparty');
   END IF;
END;
/

-- ============================================================================
-- PHASE CTI-4: UAA tables (User Authentication)
-- ============================================================================
PROMPT
PROMPT === Phase CTI-4: UAA tables ===

-- 38. uaa_users: PII fields only
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.uaa_users SET 
      description = NULL, firstname = NULL, lastname = NULL, email = NULL, phone_number = NULL
   WHERE description IS NOT NULL OR firstname IS NOT NULL OR lastname IS NOT NULL 
      OR email IS NOT NULL OR phone_number IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   IF v_cnt > 0 THEN DBMS_OUTPUT.PUT_LINE('  uaa_users (PII fields): ' || v_cnt || ' rows NULLed'); END IF;
EXCEPTION WHEN OTHERS THEN
   IF SQLCODE = -942 THEN DBMS_OUTPUT.PUT_LINE('  uaa_users: SKIPPED (table not found)');
   ELSIF SQLCODE = -904 THEN DBMS_OUTPUT.PUT_LINE('  uaa_users (PII): SKIPPED (some columns not found)');
   ELSE RAISE; END IF;
END;
/

PROMPT
PROMPT ====================================================================
PROMPT  CTI Tables Anonymization COMPLETE
PROMPT ====================================================================
