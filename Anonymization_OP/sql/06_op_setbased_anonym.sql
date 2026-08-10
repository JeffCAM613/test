-- ============================================================================
-- OP Anonymization - Set-Based Code Rename
-- ============================================================================
-- PURPOSE: Replace the iterative pack_anonym procedure with set-based MERGE/UPDATE
--          operations that process ALL codes in a single pass per table/column.
--
-- PERFORMANCE: Expected 20-40 minutes (vs 11 hours with pack_anonym loops)
--
-- PREREQUISITES:
--   - Run as OP schema owner (connected as OP)
--   - atrace schema must exist (created by 01_manage_tblspace.sql)
--   - Triggers must be DISABLED before running (done by start_anonymous.sql)
--   - 05_op_performance_boost.sql should run BEFORE this (clears text fields)
--
-- PARAMETERS (passed from start_anonymous_v3.sql):
--   &1  = ORACLE_SID (unused, for reference)
--   &2  = EntC (Entite code rename y/n)
--   &3  = EntD (Entite desc y/n)
--   &4  = FoldC (Portefeuille code y/n)
--   &5  = FoldD (Portefeuille desc y/n)
--   &6  = TierC (Tiers code y/n)
--   &7  = TierD (Tiers desc y/n)
--   &8  = CpteC (Compte code y/n)
--   &9  = CpteD (Compte desc y/n)
--   &10 = TBSDATA tablespace name
--
-- All entity types are always processed regardless of flag values.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING OFF
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF

PROMPT
PROMPT ====================================================================
PROMPT  OP Set-Based Code Anonymization
PROMPT ====================================================================
PROMPT

-- ============================================================================
-- PHASE 1: Create Mapping Table
-- ============================================================================

PROMPT === Phase 1: Creating code mapping table ===

BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE atrace.op_code_mapping PURGE';
   DBMS_OUTPUT.PUT_LINE('Dropped existing op_code_mapping');
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('op_code_mapping did not exist (OK)');
END;
/

CREATE TABLE atrace.op_code_mapping (
   entity_type  VARCHAR2(20)  NOT NULL,  -- ENTITE, PORTEFEUILLE, TIERS, COMPTE
   old_code     VARCHAR2(22)  NOT NULL,
   new_code     VARCHAR2(22)  NOT NULL,
   CONSTRAINT pk_op_code_mapping PRIMARY KEY (entity_type, old_code)
) TABLESPACE &10;

CREATE INDEX atrace.idx_opcm_old ON atrace.op_code_mapping(old_code) TABLESPACE &10;

-- UNIQUE constraint on new_code to PREVENT duplicates (safety net)
CREATE UNIQUE INDEX atrace.idx_opcm_newcode_unique ON atrace.op_code_mapping(new_code) TABLESPACE &10;

PROMPT === Phase 1: Creating unique code generator procedure ===

-- Procedure to generate UNIQUE anonymized codes with retry on collision
CREATE OR REPLACE PROCEDURE op.generate_unique_mappings(
   p_entity_type  IN VARCHAR2,
   p_prefix       IN VARCHAR2,
   p_source_query IN VARCHAR2
) IS
   v_new_code     VARCHAR2(22);
   v_old_code     VARCHAR2(22);
   v_cnt          NUMBER := 0;
   v_retries      NUMBER;
   v_exists       NUMBER;
   v_max_retries  CONSTANT NUMBER := 100;
   
   TYPE t_codes IS TABLE OF VARCHAR2(22);
   v_codes t_codes;
   
   v_cursor SYS_REFCURSOR;
BEGIN
   -- Open dynamic cursor for source codes
   OPEN v_cursor FOR p_source_query;
   
   LOOP
      FETCH v_cursor INTO v_old_code;
      EXIT WHEN v_cursor%NOTFOUND;
      
      -- Generate unique code with retry loop
      v_retries := 0;
      LOOP
         -- Generate random 7-digit number with prefix
         v_new_code := p_prefix || LPAD(ABS(MOD(DBMS_RANDOM.RANDOM, 9999999)), 7, '0');
         
         -- Check if this new_code already exists in the mapping table
         SELECT COUNT(*) INTO v_exists 
           FROM atrace.op_code_mapping 
          WHERE new_code = v_new_code;
         
         EXIT WHEN v_exists = 0;  -- Found unique code
         
         v_retries := v_retries + 1;
         IF v_retries >= v_max_retries THEN
            RAISE_APPLICATION_ERROR(-20001, 
               'Failed to generate unique code after ' || v_max_retries || 
               ' retries for old_code=' || v_old_code);
         END IF;
      END LOOP;
      
      -- Insert the unique mapping
      INSERT INTO atrace.op_code_mapping (entity_type, old_code, new_code)
      VALUES (p_entity_type, v_old_code, v_new_code);
      
      v_cnt := v_cnt + 1;
      
      -- Commit every 1000 rows for large datasets
      IF MOD(v_cnt, 1000) = 0 THEN
         COMMIT;
      END IF;
   END LOOP;
   
   CLOSE v_cursor;
   COMMIT;
   
   DBMS_OUTPUT.PUT_LINE('  ' || p_entity_type || ' mappings: ' || v_cnt || ' (unique codes guaranteed)');
END;
/

PROMPT === Phase 1: Generating UNIQUE code mappings ===

-- Entite mappings (entities with flag_portefeuille = 'N')
BEGIN
   op.generate_unique_mappings(
      p_entity_type  => 'ENTITE',
      p_prefix       => 'E_',
      p_source_query => 'SELECT s.code FROM op.structure s JOIN op.tiers t ON t.code = s.code ' ||
                        'WHERE s.structure = ''Entite'' AND s.ecran = ''w_tiers'' AND t.flag_portefeuille = ''N'''
   );
END;
/

-- Portefeuille mappings (entities with flag_portefeuille = 'O')
BEGIN
   op.generate_unique_mappings(
      p_entity_type  => 'PORTEFEUILLE',
      p_prefix       => 'P_',
      p_source_query => 'SELECT s.code FROM op.structure s JOIN op.tiers t ON t.code = s.code ' ||
                        'WHERE s.structure = ''Entite'' AND s.ecran = ''w_tiers'' AND t.flag_portefeuille = ''O'''
   );
END;
/

-- Tiers mappings (counterparties from structure='Compte', ecran='w_tiers')
BEGIN
   op.generate_unique_mappings(
      p_entity_type  => 'TIERS',
      p_prefix       => 'T_',
      p_source_query => 'SELECT code FROM op.structure WHERE structure = ''Compte'' AND ecran = ''w_tiers'''
   );
END;
/

-- Compte (bank account) mappings
BEGIN
   op.generate_unique_mappings(
      p_entity_type  => 'COMPTE',
      p_prefix       => 'CB_',
      p_source_query => 'SELECT code FROM op.compte_banque'
   );
END;
/

-- Create a unified view of ALL mappings (any old_code -> new_code regardless of type)
-- This is needed because columns like 'entite' can contain Entity OR Portfolio codes
CREATE OR REPLACE VIEW atrace.v_op_all_mappings AS
SELECT old_code, new_code FROM atrace.op_code_mapping;

DECLARE
   v_total NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_total FROM atrace.op_code_mapping;
   DBMS_OUTPUT.PUT_LINE('  TOTAL mappings: ' || v_total);
END;
/

-- ============================================================================
-- PHASE 2: Set-Based Code Renames - SHARED tables
-- (These tables are updated for ALL entity types: Entite, Portefeuille, Tiers)
-- ============================================================================

PROMPT
PROMPT === Phase 2: Set-based code renames (shared tables) ===
PROMPT

-- Helper: generic UPDATE procedure for code renames
-- Updates table.column = new_code WHERE table.column = old_code
-- Uses correlated UPDATE (MERGE can't update columns in its ON clause - ORA-38104)
-- Owned by OP (current user) to avoid cross-schema privilege issues
--
-- p_entity_type: Optional filter on atrace.op_code_mapping.entity_type.
--   Use 'COMPTE' for fields that reference compte_banque.code to avoid
--   collision with tiers codes that share the same old_code value.
--   Leave NULL for entity/tiers/portfolio references (no collision risk).
CREATE OR REPLACE PROCEDURE op.merge_codes(
   p_table       IN VARCHAR2,
   p_column      IN VARCHAR2,
   p_hint        IN VARCHAR2 DEFAULT NULL,
   p_entity_type IN VARCHAR2 DEFAULT NULL
) AS
   v_sql   VARCHAR2(4000);
   v_count NUMBER;
   v_start TIMESTAMP := SYSTIMESTAMP;
   v_type_filter VARCHAR2(200);
BEGIN
   -- Build optional entity_type filter clause
   IF p_entity_type IS NOT NULL THEN
      v_type_filter := ' AND m.entity_type = ''' || p_entity_type || '''';
   ELSE
      v_type_filter := '';
   END IF;

   v_sql := 'UPDATE ' || CASE WHEN p_hint IS NOT NULL THEN '/*+ ' || p_hint || ' */ ' ELSE '' END ||
            'op.' || p_table || ' t SET t.' || p_column ||
            ' = (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.old_code = t.' || p_column ||
            v_type_filter || ' AND ROWNUM = 1) WHERE t.' || p_column ||
            ' IN (SELECT old_code FROM atrace.op_code_mapping' ||
            CASE WHEN p_entity_type IS NOT NULL THEN ' WHERE entity_type = ''' || p_entity_type || '''' ELSE '' END || ')';
   EXECUTE IMMEDIATE v_sql;
   v_count := SQL%ROWCOUNT;
   COMMIT;
   IF v_count > 0 THEN
      DBMS_OUTPUT.PUT_LINE('  ' || RPAD(p_table || '.' || p_column, 45) || v_count || ' rows (' ||
         ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start)), 1) || 's)');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      -- Table or column may not exist on this instance
      IF SQLCODE = -942 OR SQLCODE = -904 THEN
         DBMS_OUTPUT.PUT_LINE('  ' || RPAD(p_table || '.' || p_column, 45) || 'SKIPPED (not found)');
      ELSE
         DBMS_OUTPUT.PUT_LINE('  ERROR ' || p_table || '.' || p_column || ': ' || SQLERRM);
         RAISE;
      END IF;
END;
/

-- ============================================================================
-- PHASE 2A: Core reference tables (small, fast)
-- ============================================================================
PROMPT --- Core reference tables ---

BEGIN
   -- structure
   merge_codes('structure', 'code');
   merge_codes('structure', 'pere');

   -- tiers (main entity table)
   merge_codes('tiers', 'code');
   merge_codes('tiers', 'entite_pere');
   merge_codes('tiers', 'entite_fifo');
   merge_codes('tiers', 'tiers_conso');
   merge_codes('tiers', 'tiers_federateur');
   merge_codes('tiers', 'tiers_conso2');
   merge_codes('tiers', 'tiers_conso3');

   -- compte_banque (use entity_type filter to avoid collision with tiers codes)
   merge_codes('compte_banque', 'code', p_entity_type => 'COMPTE');
   merge_codes('compte_banque', 'code_bban', p_entity_type => 'COMPTE');
   merge_codes('compte_banque', 'agence');
   merge_codes('compte_banque', 'banque');
   merge_codes('compte_banque', 'entite');
   merge_codes('compte_banque', 'portefeuille_defaut');
   merge_codes('compte_banque', 'compte_previs_glob', p_entity_type => 'COMPTE');
END;
/

-- NOTE: compte_banque.groupe_1/2/3 overwrite is handled in Phase 3C
-- (after code renames complete, so we can match on new_code)

-- ============================================================================
-- PHASE 2B: Parameter/config tables (small)
-- ============================================================================
PROMPT --- Parameter/config tables ---

BEGIN
   merge_codes('param_marge_titre', 'entite');
   merge_codes('ccp_breakdown', 'clearing_member');
   merge_codes('clearing_member_breakdown', 'clearing_member');
   merge_codes('budget_filtre', 'entite');
   merge_codes('budget_regle', 'entite');
   merge_codes('compte_devise', 'entite');
   merge_codes('compte_devise', 'compte', p_entity_type => 'COMPTE');
   merge_codes('compte_filiale', 'filiale');
   merge_codes('compte_filiale', 'entite');
   merge_codes('compte_filiale', 'compte', p_entity_type => 'COMPTE');
   merge_codes('compte_regle', 'contrepartie');
   merge_codes('compte_regle', 'entite');
   merge_codes('compte_regle', 'portefeuille');
   merge_codes('compte_regle', 'depositaire');
   merge_codes('compte_regle', 'compte', p_entity_type => 'COMPTE');
   merge_codes('compte_regle_bqe', 'correspondant');
   merge_codes('compte_regle_bqe', 'contrepartie');
   merge_codes('compte_regle_bqe', 'portefeuille');
   merge_codes('compte_regle_bqe', 'depositaire');
   merge_codes('compte_regle_bqe', 'entite');
   merge_codes('compte_regle_bqe', 'compte', p_entity_type => 'COMPTE');
   merge_codes('compte_regle_liv', 'contrepartie');
   merge_codes('compte_regle_liv', 'entite');
   merge_codes('compte_regle_liv', 'portefeuille');
   merge_codes('compte_regle_liv', 'depositaire');
   merge_codes('compte_regle_liv', 'compte', p_entity_type => 'COMPTE');
   merge_codes('compte_titre', 'depositaire');
   merge_codes('compte_titre', 'entite');
   merge_codes('contrat', 'emetteur');
   merge_codes('contrat_cadre', 'entite');
   merge_codes('contrat_cadre', 'federateur');
   merge_codes('contrat_cadre', 'compte_echelle', p_entity_type => 'COMPTE');
   merge_codes('contrat_instrument', 'entite');
   merge_codes('contrat_instrument', 'federateur');
   merge_codes('ctpyrating', 'counterparty');
   merge_codes('deposit_fils', 'portefeuille');
   merge_codes('deposit_fils', 'portefeuille_pere');
   merge_codes('deposit_pere', 'portefeuille');
   merge_codes('deposit_pere', 'portefeuille_depo');
   merge_codes('echelle', 'entite_mere');
   merge_codes('echelle', 'portefeuille_mere');
   merge_codes('echelle', 'compte_reglement', p_entity_type => 'COMPTE');
   merge_codes('echelle_condition', 'code');
   merge_codes('echelle_cond_date', 'condition');
   merge_codes('echelle_compte', 'compte', p_entity_type => 'COMPTE');
   merge_codes('echelle_marge', 'condition');
   merge_codes('fifo_solde_depo', 'compensateur');
   merge_codes('fifo_solde_depo', 'depositaire');
   merge_codes('fifo_solde_depo', 'portefeuille');
   merge_codes('frais_gestion', 'portefeuille');
   merge_codes('groupe_detail', 'portefeuille');
   merge_codes('groupe_provision', 'entite');
   merge_codes('decouvert_compte', 'compte', p_entity_type => 'COMPTE');
   merge_codes('marge_compte_de', 'contrepartie');
   merge_codes('marge_regle', 'contrepartie');
   merge_codes('marge_regle', 'entite');
   merge_codes('param_arrete', 'entite');
   merge_codes('param_bafi_cpt', 'entite');
   merge_codes('param_clonage', 'por_maitre');
   merge_codes('param_clonage', 'por_clone');
   merge_codes('param_cpta_reg_gen', 'portefeuille');
   merge_codes('param_cpta_reg_gen', 'compte_ana', p_entity_type => 'COMPTE');
   merge_codes('param_cpta_reg_ven', 'banque');
   merge_codes('param_cpta_reg_ven', 'entite');
   merge_codes('param_cpta_reg_ven', 'portefeuille');
   merge_codes('param_cpta_reg_ven', 'compte', p_entity_type => 'COMPTE');
   merge_codes('param_date', 'portefeuille');
   merge_codes('param_date', 'contrepartie');
   merge_codes('param_effet_paye', 'compte', p_entity_type => 'COMPTE');
   merge_codes('param_effet_recu', 'compte', p_entity_type => 'COMPTE');
   merge_codes('param_fiche_val_detail', 'code');
   merge_codes('param_garanti_taux', 'assureur');
   merge_codes('param_net_reg', 'compte_comp', p_entity_type => 'COMPTE');
   merge_codes('param_net_reg', 'compte_pivot', p_entity_type => 'COMPTE');
   merge_codes('param_ope_bloc', 'portefeuille_pere');
   merge_codes('param_ope_bloc', 'portefeuille_fils');
   merge_codes('param_parapheur_det', 'filiale');
   merge_codes('param_rappro_stock', 'depositaire');
   merge_codes('param_sign_user', 'filiale');
   merge_codes('photo', 'entite');
   merge_codes('photo_budget', 'entite');
   merge_codes('photo_flux', 'entite');
   merge_codes('prevision_param', 'entite');
   merge_codes('prevision_param', 'compte', p_entity_type => 'COMPTE');
   merge_codes('regle_rappro_auto', 'banque');
   merge_codes('regle_rappro_auto', 'entite');
   merge_codes('regle_rappro_auto', 'compte', p_entity_type => 'COMPTE');
   merge_codes('reglement_decalage', 'banque');
   merge_codes('reglement_decalage', 'compte', p_entity_type => 'COMPTE');
   merge_codes('reglement_flux', 'entite');
   merge_codes('reglement_flux', 'tiers');
   merge_codes('reglement_flux', 'compte', p_entity_type => 'COMPTE');
   merge_codes('reglement_regle', 'banque');
   merge_codes('reglement_regle', 'compte', p_entity_type => 'COMPTE');
   merge_codes('spread_breakdown', 'portfolio');
   merge_codes('spread_breakdown', 'entity');
   merge_codes('spread_breakdown', 'issuer');
   merge_codes('stress_results', 'portefeuille');
   merge_codes('tiers_compteur', 'tiers');
   merge_codes('tiers_foyer', 'foyer');
   merge_codes('tiers_foyer', 'foyer_appartenance');
   merge_codes('tiers_limite', 'tiers');
   merge_codes('tiers_limite', 'entite');
   merge_codes('titre', 'emetteur');
   merge_codes('titre', 'bafi_garant');
   merge_codes('titre', 'depositaire');
   merge_codes('titre', 'domiciliataire');
   merge_codes('val_bank_account', 'code', p_entity_type => 'COMPTE');
   merge_codes('val_affilied_code', 'code_ref');
   merge_codes('val_third_party', 'adresse1');
   merge_codes('val_third_party', 'code');
   merge_codes('val_third_party', 'tiers_conso');
   merge_codes('val_table_security', 'code');
   merge_codes('valo_ccy_volat_rule', 'portfolio');
   merge_codes('valo_ccy_volat_rule', 'entity');
   merge_codes('valo_regle', 'portefeuille');
   merge_codes('valo_regle', 'entite');
   merge_codes('ventiler_contrat_cadre', 'entite');
   merge_codes('ventiler_contrat_cadre', 'tiers');
   merge_codes('ventiler_corresp', 'banque');
   merge_codes('ventiler_corresp', 'contrepartie');
   merge_codes('ventiler_corresp', 'correspondant_1');
   merge_codes('ventiler_corresp', 'correspondant_2');
   merge_codes('ventiler_corresp_bqe', 'tiers_entite');
   merge_codes('ventiler_corresp_bqe', 'contrepartie');
   merge_codes('ventiler_corresp_bqe', 'correspondant_1');
   merge_codes('ventiler_corresp_bqe', 'correspondant_2');
   merge_codes('ventiler_corresp_bqe', 'banque');
   merge_codes('ventiler_portef', 'contrepartie');
   merge_codes('ventiler_portef', 'portefeuille');
   merge_codes('ventiler_reg_liv', 'depositaire');
   merge_codes('ventiler_reg_liv', 'contrepartie');
   merge_codes('ventiler_reg_liv', 'portefeuille');
   merge_codes('vue_affilie_tiers', 'code_ref');
   merge_codes('vue_affilie_compte', 'code_ref');
   merge_codes('ventiler_compte', 'valeur_1');
   merge_codes('ventiler_compte', 'valeur_2');
   merge_codes('ventiler_compte', 'valeur_3');
   merge_codes('ventiler_compte', 'valeur_4');
   merge_codes('virement_compte', 'compte', p_entity_type => 'COMPTE');
END;
/

-- ============================================================================
-- PHASE 2C: Histo tables (large - use PARALLEL hint)
-- These are the biggest tables (millions of rows)
-- ============================================================================
PROMPT --- Large histo tables (parallel) ---

BEGIN
   -- histo_budget
   merge_codes('histo_budget', 'entite');

   -- histo_compta (3.7M rows)
   merge_codes('histo_compta', 'tiers', 'PARALLEL(4)');
   merge_codes('histo_compta', 'entite', 'PARALLEL(4)');
   merge_codes('histo_compta', 'portefeuille', 'PARALLEL(4)');

   -- histo_compta_solde
   merge_codes('histo_compta_solde', 'entite');

   -- histo_courtage
   merge_codes('histo_courtage', 'tiers');

   -- histo_couverture
   merge_codes('histo_couverture', 'tiers_deposit');
   merge_codes('histo_couverture', 'tiers_reception');

   -- histo_deposit
   merge_codes('histo_deposit', 'depositaire');
   merge_codes('histo_deposit', 'portefeuille');

   -- histo_detenteur
   merge_codes('histo_detenteur', 'ancien_detenteur');
   merge_codes('histo_detenteur', 'nouveau_detenteur');

   -- histo_effet
   merge_codes('histo_effet', 'compte', p_entity_type => 'COMPTE');
   merge_codes('histo_effet', 'compte_effet', p_entity_type => 'COMPTE');

   -- histo_evenement
   merge_codes('histo_evenement', 'entite');
   merge_codes('histo_evenement', 'contrepartie');
   merge_codes('histo_evenement', 'depositaire');
   merge_codes('histo_evenement', 'entity_corresp1');
   merge_codes('histo_evenement', 'entity_corresp2');

   -- histo_facture
   merge_codes('histo_facture', 'entite');
   merge_codes('histo_facture', 'tiers');

   -- histo_fifo_solde
   merge_codes('histo_fifo_solde', 'portefeuille');
   merge_codes('histo_fifo_solde', 'compensateur');

   -- histo_fiscalite
   merge_codes('histo_fiscalite', 'entite');
   merge_codes('histo_fiscalite', 'foyer');
   merge_codes('histo_fiscalite', 'compte_fiscal', p_entity_type => 'COMPTE');

   -- histo_flux
   merge_codes('histo_flux', 'entite', 'PARALLEL(4)');
   merge_codes('histo_flux', 'portefeuille', 'PARALLEL(4)');
   merge_codes('histo_flux', 'tiers', 'PARALLEL(4)');
   merge_codes('histo_flux', 'groupe_1', 'PARALLEL(4)');
   merge_codes('histo_flux', 'groupe_2', 'PARALLEL(4)');
   merge_codes('histo_flux', 'groupe_3', 'PARALLEL(4)');

   -- histo_limite_tr
   merge_codes('histo_limite_tr', 'entite');
   merge_codes('histo_limite_tr', 'tiers');

   -- histo_ligne
   merge_codes('histo_ligne', 'compte', p_entity_type => 'COMPTE');

   -- histo_liv_solde
   merge_codes('histo_liv_solde', 'entite');

   -- histo_livraison
   merge_codes('histo_livraison', 'entite', 'PARALLEL(4)');
   merge_codes('histo_livraison', 'tiers', 'PARALLEL(4)');
   merge_codes('histo_livraison', 'portefeuille', 'PARALLEL(4)');
   merge_codes('histo_livraison', 'groupe_1', 'PARALLEL(4)');
   merge_codes('histo_livraison', 'groupe_2', 'PARALLEL(4)');
   merge_codes('histo_livraison', 'groupe_3', 'PARALLEL(4)');

   -- histo_matiere
   merge_codes('histo_matiere', 'entite');
   merge_codes('histo_matiere', 'tiers');
   merge_codes('histo_matiere', 'portefeuille');

   -- histo_mouv_solde
   merge_codes('histo_mouv_solde', 'compte', p_entity_type => 'COMPTE');

   -- histo_mouv_titre_solde
   merge_codes('histo_mouv_titre_solde', 'compensateur');

   -- histo_mouvement (2.3M rows)
   merge_codes('histo_mouvement', 'entite', 'PARALLEL(4)');
   merge_codes('histo_mouvement', 'compte', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_mouvement', 'compte_contrepartie', 'PARALLEL(4)', 'COMPTE');

   -- histo_operation (1.3M rows)
   merge_codes('histo_operation', 'clearing_member', 'PARALLEL(4)');
   merge_codes('histo_operation', 'entite', 'PARALLEL(4)');
   merge_codes('histo_operation', 'contrepartie', 'PARALLEL(4)');
   merge_codes('histo_operation', 'compensateur', 'PARALLEL(4)');
   merge_codes('histo_operation', 'filiale', 'PARALLEL(4)');
   merge_codes('histo_operation', 'intermediaire', 'PARALLEL(4)');
   merge_codes('histo_operation', 'portefeuille', 'PARALLEL(4)');
   merge_codes('histo_operation', 'portefeuille_tiers', 'PARALLEL(4)');
   merge_codes('histo_operation', 'depositaire', 'PARALLEL(4)');
   merge_codes('histo_operation', 'depositaire_2', 'PARALLEL(4)');
   merge_codes('histo_operation', 'emetteur', 'PARALLEL(4)');
   merge_codes('histo_operation', 'corresp_receiver1', 'PARALLEL(4)');
   merge_codes('histo_operation', 'corresp_receiver2', 'PARALLEL(4)');
   merge_codes('histo_operation', 'corresp_sender1', 'PARALLEL(4)');
   merge_codes('histo_operation', 'corresp_sender2', 'PARALLEL(4)');
   merge_codes('histo_operation', 'portefeuille_deposit', 'PARALLEL(4)');
   merge_codes('histo_operation', 'tiers_domicile', 'PARALLEL(4)');
   merge_codes('histo_operation', 'compte_entite', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'compte_tiers', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'compte_filiale', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'compte_tiers_2', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'compte_entite_2', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'tiers_iban_compte', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_operation', 'groupe_1', 'PARALLEL(4)');
   merge_codes('histo_operation', 'groupe_2', 'PARALLEL(4)');
   merge_codes('histo_operation', 'groupe_3', 'PARALLEL(4)');

   -- histo_parapheur
   merge_codes('histo_parapheur', 'filiale');

   -- histo_parapheur_det
   merge_codes('histo_parapheur_det', 'filiale');

   -- histo_position_tr
   merge_codes('histo_position_tr', 'entite');

   -- histo_prevision
   merge_codes('histo_prevision', 'compte', p_entity_type => 'COMPTE');

   -- histo_pricing_detail
   merge_codes('histo_pricing_detail', 'entite');
   merge_codes('histo_pricing_detail', 'portefeuille');
   merge_codes('histo_pricing_detail', 'portefeuille_tiers');

   -- histo_reg_conso
   merge_codes('histo_reg_conso', 'compte', p_entity_type => 'COMPTE');

   -- histo_reg_releve
   merge_codes('histo_reg_releve', 'entite');
   merge_codes('histo_reg_releve', 'compte', p_entity_type => 'COMPTE');

   -- histo_reg_solde
   merge_codes('histo_reg_solde', 'entite');
   merge_codes('histo_reg_solde', 'portefeuille');
   merge_codes('histo_reg_solde', 'compte', p_entity_type => 'COMPTE');

   -- histo_reglement (3.2M rows)
   merge_codes('histo_reglement', 'entite', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'tiers', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'corresp_receiver1', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'corresp_receiver2', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'corresp_sender1', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'corresp_sender2', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'portefeuille', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'compte', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_reglement', 'cpty_account', 'PARALLEL(4)', 'COMPTE');
   merge_codes('histo_reglement', 'groupe_1', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'groupe_2', 'PARALLEL(4)');
   merge_codes('histo_reglement', 'groupe_3', 'PARALLEL(4)');

   -- histo_titre_solde
   merge_codes('histo_titre_solde', 'compensateur');
   merge_codes('histo_titre_solde', 'portefeuille');
END;
/

-- ============================================================================
-- PHASE 2D: Import tables
-- ============================================================================
PROMPT --- Import tables ---

BEGIN
   -- import_evenement
   merge_codes('import_evenement', 'contrepartie');
   merge_codes('import_evenement', 'entite');
   merge_codes('import_evenement', 'cpty_account', p_entity_type => 'COMPTE');
   merge_codes('import_evenement', 'entity_account', p_entity_type => 'COMPTE');
   merge_codes('import_evenement', 'cpty_corresp1');
   merge_codes('import_evenement', 'cpty_corresp2');
   merge_codes('import_evenement', 'entity_corresp1');
   merge_codes('import_evenement', 'entity_corresp2');

   -- import_operation
   merge_codes('import_operation', 'clearing_member');
   merge_codes('import_operation', 'entite');
   merge_codes('import_operation', 'contrepartie');
   merge_codes('import_operation', 'compensateur');
   merge_codes('import_operation', 'filiale');
   merge_codes('import_operation', 'intermediaire');
   merge_codes('import_operation', 'portefeuille');
   merge_codes('import_operation', 'portefeuille_tiers');
   merge_codes('import_operation', 'depositaire');
   merge_codes('import_operation', 'depositaire_2');
   merge_codes('import_operation', 'emetteur');
   merge_codes('import_operation', 'corresp_receiver1');
   merge_codes('import_operation', 'corresp_receiver2');
   merge_codes('import_operation', 'corresp_sender1');
   merge_codes('import_operation', 'corresp_sender2');
   merge_codes('import_operation', 'portefeuille_deposit');
   merge_codes('import_operation', 'tiers_domicile');
   merge_codes('import_operation', 'compte_entite', p_entity_type => 'COMPTE');
   merge_codes('import_operation', 'compte_tiers', p_entity_type => 'COMPTE');
   merge_codes('import_operation', 'compte_filiale', p_entity_type => 'COMPTE');
   merge_codes('import_operation', 'compte_tiers_2', p_entity_type => 'COMPTE');
   merge_codes('import_operation', 'groupe_1');
   merge_codes('import_operation', 'groupe_2');
   merge_codes('import_operation', 'groupe_3');
END;
/

-- ============================================================================
-- PHASE 2E: ZBA tables
-- ============================================================================
PROMPT --- ZBA tables ---

BEGIN
   merge_codes('zba_breakdown', 'centralizer_account', p_entity_type => 'COMPTE');
   merge_codes('zba_payment_breakdown', 'entity');
   merge_codes('zba_payment_breakdown', 'portfolio');
   merge_codes('zba_payment_breakdown', 'mirrored_entity');
   merge_codes('zba_payment_breakdown', 'mirrored_portfolio');
   merge_codes('zba_payment_breakdown', 'centralizer_account', p_entity_type => 'COMPTE');
   merge_codes('zba_payment_breakdown', 'current_account', p_entity_type => 'COMPTE');
   merge_codes('zba_payment_breakdown', 'mirrored_current_account', p_entity_type => 'COMPTE');
   merge_codes('zba_transfer_breakdown', 'entity');
   merge_codes('zba_transfer_breakdown', 'portfolio');
   merge_codes('zba_transfer_breakdown', 'counterparty');
   merge_codes('zba_transfer_breakdown', 'centralizer_account', p_entity_type => 'COMPTE');
   merge_codes('zba_transfer_breakdown', 'counterparty_account', p_entity_type => 'COMPTE');
   merge_codes('zba_transfer_breakdown', 'entity_account', p_entity_type => 'COMPTE');
END;
/

-- ============================================================================
-- PHASE 2F: Free-text field blanking (tiers_libelle, description on import/histo)
-- These were handled inside pack_anonym loop in v2 but are NOT in perf boost
-- ============================================================================
PROMPT --- Free-text field blanking ---

DECLARE v_cnt NUMBER;
BEGIN
   -- histo_operation.tiers_libelle (free-text counterparty name - PII risk)
   UPDATE /*+ PARALLEL(4) */ op.histo_operation SET tiers_libelle = NULL WHERE tiers_libelle IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  histo_operation.tiers_libelle: ' || v_cnt || ' rows NULLed');
END;
/

DECLARE v_cnt NUMBER;
BEGIN
   -- import_operation.description (free-text - may contain real entity names)
   UPDATE op.import_operation SET description = NULL WHERE description IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  import_operation.description: ' || v_cnt || ' rows NULLed');
END;
/

DECLARE v_cnt NUMBER;
BEGIN
   -- import_operation.tiers_libelle (free-text counterparty name - PII risk)
   UPDATE op.import_operation SET tiers_libelle = NULL WHERE tiers_libelle IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  import_operation.tiers_libelle: ' || v_cnt || ' rows NULLed');
END;
/

-- ============================================================================
-- PHASE 3: Description and Address Blanking
-- (These are per-entity fields that get set to the new code value)
-- ============================================================================
PROMPT
PROMPT === Phase 3: Description and address anonymization ===

-- structure.description = new_code (where code was renamed)
DECLARE v_cnt NUMBER;
BEGIN
   MERGE INTO op.structure t
   USING atrace.op_code_mapping m ON (m.new_code = t.code)
   WHEN MATCHED THEN UPDATE SET t.description = m.new_code;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  structure.description: ' || v_cnt || ' rows');
END;
/

-- tiers.description = new_code
DECLARE v_cnt NUMBER;
BEGIN
   MERGE INTO op.tiers t
   USING atrace.op_code_mapping m ON (m.new_code = t.code)
   WHEN MATCHED THEN UPDATE SET t.description = m.new_code;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  tiers.description: ' || v_cnt || ' rows');
END;
/

-- tiers.adresse1-5 = new_code (only where not null)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tiers t SET
      adresse1 = CASE WHEN adresse1 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      adresse2 = CASE WHEN adresse2 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      adresse3 = CASE WHEN adresse3 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      adresse4 = CASE WHEN adresse4 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      adresse5 = CASE WHEN adresse5 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.new_code = t.code AND ROWNUM = 1) ELSE NULL END
   WHERE t.code IN (SELECT new_code FROM atrace.op_code_mapping)
     AND (adresse1 IS NOT NULL OR adresse2 IS NOT NULL OR adresse3 IS NOT NULL
          OR adresse4 IS NOT NULL OR adresse5 IS NOT NULL);
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  tiers.adresse1-5: ' || v_cnt || ' rows');
END;
/

-- ============================================================================
-- PHASE 3B: Extra tiers fields (config Ent1-5, Fold1-5, Tier1-5)
-- v2 pack_anonym overwrites these per-entity fields with the new code value.
-- We replicate by joining to the mapping table.
-- ============================================================================
PROMPT --- Extra tiers fields (PII: telephone, fax, email, etc.) ---

-- Entite extra fields: telephone, fax, email_adress, nom_pp, prenom_pp
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tiers t SET
      telephone    = CASE WHEN telephone    IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'ENTITE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      fax          = CASE WHEN fax          IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'ENTITE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      email_adress = CASE WHEN email_adress IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'ENTITE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      nom_pp       = CASE WHEN nom_pp       IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'ENTITE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      prenom_pp    = CASE WHEN prenom_pp    IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'ENTITE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END
   WHERE t.code IN (SELECT new_code FROM atrace.op_code_mapping WHERE entity_type = 'ENTITE')
     AND (telephone IS NOT NULL OR fax IS NOT NULL OR email_adress IS NOT NULL
          OR nom_pp IS NOT NULL OR prenom_pp IS NOT NULL);
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  tiers (ENTITE) telephone/fax/email/nom_pp/prenom_pp: ' || v_cnt || ' rows');
END;
/

-- Portefeuille extra fields: groupe_1, groupe_2, groupe_3, flag_pp, dpt_naissance
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tiers t SET
      groupe_1      = CASE WHEN groupe_1      IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'PORTEFEUILLE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      groupe_2      = CASE WHEN groupe_2      IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'PORTEFEUILLE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      groupe_3      = CASE WHEN groupe_3      IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'PORTEFEUILLE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      flag_pp       = CASE WHEN flag_pp       IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'PORTEFEUILLE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      dpt_naissance = CASE WHEN dpt_naissance IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'PORTEFEUILLE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END
   WHERE t.code IN (SELECT new_code FROM atrace.op_code_mapping WHERE entity_type = 'PORTEFEUILLE')
     AND (groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL
          OR flag_pp IS NOT NULL OR dpt_naissance IS NOT NULL);
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  tiers (PORTEFEUILLE) groupe_1/2/3/flag_pp/dpt_naissance: ' || v_cnt || ' rows');
END;
/

-- Tiers (counterparty) extra fields: sector, seniority, telex, type_interne
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.tiers t SET
      sector       = CASE WHEN sector       IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'TIERS' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      seniority    = CASE WHEN seniority    IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'TIERS' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      telex        = CASE WHEN telex        IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'TIERS' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      type_interne = CASE WHEN type_interne IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'TIERS' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END
   WHERE t.code IN (SELECT new_code FROM atrace.op_code_mapping WHERE entity_type = 'TIERS')
     AND (sector IS NOT NULL OR seniority IS NOT NULL OR telex IS NOT NULL OR type_interne IS NOT NULL);
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  tiers (TIERS) sector/seniority/telex/type_interne: ' || v_cnt || ' rows');
END;
/

-- ============================================================================
-- PHASE 3C: Extra compte_banque fields (config Cpte1-3: groupe_1/2/3)
-- v2 overwrites these with the new code per bank account
-- ============================================================================
PROMPT --- Extra compte_banque fields (groupe_1/2/3) ---

DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.compte_banque t SET
      groupe_1 = CASE WHEN groupe_1 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'COMPTE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      groupe_2 = CASE WHEN groupe_2 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'COMPTE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END,
      groupe_3 = CASE WHEN groupe_3 IS NOT NULL THEN (SELECT m.new_code FROM atrace.op_code_mapping m WHERE m.entity_type = 'COMPTE' AND m.new_code = t.code AND ROWNUM = 1) ELSE NULL END
   WHERE t.code IN (SELECT new_code FROM atrace.op_code_mapping WHERE entity_type = 'COMPTE')
     AND (groupe_1 IS NOT NULL OR groupe_2 IS NOT NULL OR groupe_3 IS NOT NULL);
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  compte_banque.groupe_1/2/3: ' || v_cnt || ' rows');
END;
/

-- compte_banque.description = new_code
DECLARE v_cnt NUMBER;
BEGIN
   MERGE INTO op.compte_banque t
   USING atrace.op_code_mapping m ON (m.new_code = t.code AND m.entity_type = 'COMPTE')
   WHEN MATCHED THEN UPDATE SET t.description = m.new_code;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  compte_banque.description: ' || v_cnt || ' rows');
END;
/

-- utilisateur.description = NULL (bulk)
DECLARE v_cnt NUMBER;
BEGIN
   UPDATE op.utilisateur SET description = NULL WHERE description IS NOT NULL;
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  utilisateur.description: ' || v_cnt || ' rows set NULL');
END;
/

-- ============================================================================
-- PHASE 4: Record mappings in atrace.ref_tables_modif (for compatibility)
-- ============================================================================
PROMPT
PROMPT === Phase 4: Recording mappings in ref_tables_modif ===

DECLARE v_cnt NUMBER;
BEGIN
   INSERT INTO atrace.ref_tables_modif (old_value, new_value, table_name, field_name)
   SELECT m.old_code, m.new_code,
          CASE m.entity_type
             WHEN 'ENTITE' THEN 'tiers'
             WHEN 'PORTEFEUILLE' THEN 'tiers'
             WHEN 'TIERS' THEN 'tiers'
             WHEN 'COMPTE' THEN 'compte_banque'
          END,
          'code'
     FROM atrace.op_code_mapping m
    WHERE NOT EXISTS (
       SELECT 1 FROM atrace.ref_tables_modif r
        WHERE r.old_value = m.old_code
          AND r.field_name = 'code'
    );
   v_cnt := SQL%ROWCOUNT;
   COMMIT;
   DBMS_OUTPUT.PUT_LINE('  ref_tables_modif: ' || v_cnt || ' mappings recorded');
END;
/

-- ============================================================================
-- PHASE 5: Cleanup
-- ============================================================================
PROMPT
PROMPT === Phase 5: Cleanup ===

-- NOTE: merge_codes procedure is now dropped in Phase 4 (04drop_anon_triggers.sql)
-- after KTP/CTI phases complete. Do NOT drop it here.
-- DROP PROCEDURE op.merge_codes;

PROMPT
PROMPT ====================================================================
PROMPT  OP Set-Based Anonymization COMPLETE
PROMPT ====================================================================
PROMPT
