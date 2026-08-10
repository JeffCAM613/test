create or replace package op.pack_anonym as
function version return varchar2;
pragma restrict_references(version,WNDS);

procedure disable_enable_all_triggers(DIR varchar2);
pragma restrict_references(disable_enable_all_triggers,WNDS);

procedure anonymous_tables(ENTIT varchar2, DESCRIPT varchar2, PECRAN varchar2, 
				EntC varchar2,EntD varchar2,Ent1 varchar2,Ent2 varchar2,Ent3 varchar2,Ent4 varchar2,Ent5 varchar2,
 				FoldC varchar2,FoldD varchar2,Fold1 varchar2,Fold2 varchar2,Fold3 varchar2,Fold4 varchar2,Fold5 varchar2,    
				TierC varchar2,TierD varchar2,Tier1 varchar2,Tier2 varchar2,Tier3 varchar2,Tier4 varchar2,Tier5 varchar2,
				CpteC varchar2,CpteD varchar2,Cpte1 varchar2,Cpte2 varchar2,Cpte3 varchar2,Cpte4 varchar2,Cpte5 varchar2);
pragma restrict_references(anonymous_tables,TRUST);

end;
/

create or replace package body op.pack_anonym as
function version return varchar2 is
begin
return 'Version: 3.1 February 2021';
end version;

procedure disable_enable_all_triggers(DIR varchar2) as

D_CODE varchar2(128);
A_EXEC varchar2(30) := 'alter trigger op.';
D_EXEC varchar2(20) := ' disable';
E_EXEC varchar2(20) := ' enable';
F_EXEC varchar2(120);
COMPTE number := 0;

cursor f_triggers is
select object_name from dba_objects where owner='OP' and object_type='TRIGGER';

begin
open f_triggers;
LOOP

fetch f_triggers into D_CODE;
if f_triggers%NOTFOUND then
        exit;
END IF;
COMPTE := COMPTE +1;
F_EXEC := A_EXEC||D_CODE;
if DIR = 'D' then
    F_EXEC := F_EXEC||D_EXEC;
else
    F_EXEC := F_EXEC||E_EXEC;
end if;
execute immediate F_EXEC;
END LOOP;
dbms_output.put_line('Nbr triggers offline = '||COMPTE);
close f_triggers;
END;

PROCEDURE ANONYMOUS_TABLES(ENTIT varchar2, DESCRIPT varchar2, PECRAN varchar2, 
				EntC varchar2,EntD varchar2,Ent1 varchar2,Ent2 varchar2,Ent3 varchar2,Ent4 varchar2,Ent5 varchar2,
				FoldC varchar2,FoldD varchar2,Fold1 varchar2,Fold2 varchar2,Fold3 varchar2,Fold4 varchar2,Fold5 varchar2,        
				TierC varchar2,TierD varchar2,Tier1 varchar2,Tier2 varchar2,Tier3 varchar2,Tier4 varchar2,Tier5 varchar2,
				CpteC varchar2,CpteD varchar2,Cpte1 varchar2,Cpte2 varchar2,Cpte3 varchar2,Cpte4 varchar2,Cpte5 varchar2) as

SCODE varchar2(22);
COLN varchar2(20);
COLNPENS varchar2(20);
TMP varchar2(20);
REQ1 varchar2(200);
COMPTE number := 0;
RESTE number := 0;

cursor s_structure is
select code from op.structure where structure='Compte' and ecran='w_tiers' and ENTIT='Tiers'
UNION 
select code from op.compte_banque where ENTIT='Compte'
UNION 
select s.code from op.structure s, op.tiers t where s.code = t.code and t.flag_portefeuille = 'N' and s.structure='Entite' and s.ecran='w_tiers' and ENTIT='Entite'
UNION 
select s.code from op.structure s, op.tiers t where s.code = t.code and t.flag_portefeuille = 'O' and s.structure='Entite' and s.ecran='w_tiers' and ENTIT='Portefeuille';

begin

open s_structure;
COLN := DESCRIPT;
COLNPENS := DESCRIPT;

LOOP
fetch s_structure into SCODE;
if s_structure%NOTFOUND then
        exit;
END IF;

COMPTE := COMPTE + 1;

TMP := abs(mod(dbms_random.random,9999999));
COLN := COLN||TMP;

TMP := abs(mod(dbms_random.random,9999999));
COLNPENS := COLNPENS||TMP;


IF ENTIT = 'Entite' and PECRAN = 'w_tiers' THEN 

  IF EntD='y' THEN  
  REQ1 := 'update op.structure set description=:1 where code=:2 and structure=:3 and ecran=:4';
  execute immediate REQ1 using COLN,SCODE, ENTIT, PECRAN;
  REQ1 := 'update op.tiers set description=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse1 = :1 WHERE adresse1 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse2 = :1 WHERE adresse2 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse3 = :1 WHERE adresse3 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse4 = :1 WHERE adresse4 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse5 = :1 WHERE adresse5 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Ent1<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Ent1||'=:1 where code=:2 and ' ||Ent1||' is not null' ;
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Ent2<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Ent2||'=:1 where code=:2 and ' ||Ent2||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Ent3<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Ent3||'=:1 where code=:2 and ' ||Ent3||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Ent4<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Ent4||'=:1 where code=:2 and ' ||Ent4||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Ent5<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Ent5||'=:1 where code=:2 and ' ||Ent5||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;

	IF EntC='y' THEN 

		REQ1 := 'update op.structure set code=:1 where code=:2 and structure=:3 and ecran=:4';
		execute immediate REQ1 using COLN,SCODE, ENTIT, PECRAN;
		REQ1 := 'update op.tiers set code=:1 where code=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.param_marge_titre set entite=:1 where entite= :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.structure set pere=:1 where pere=:2 and structure=:3';
		execute immediate REQ1 using COLN,SCODE,ENTIT;

		REQ1 := 'UPDATE op.ccp_breakdown set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.clearing_member_breakdown set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.budget_filtre set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.budget_regle set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_banque set agence=:1 where agence=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set banque=:1 where banque=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set portefeuille_defaut=:1 where portefeuille_defaut=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_devise set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_filiale set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_filiale set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle_bqe set correspondant=:1 where correspondant=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle_liv set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.compte_titre SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.compte_titre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat SET emetteur = :1 WHERE  emetteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat_cadre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.contrat_cadre SET federateur = :1 WHERE  federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat_instrument SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.contrat_instrument SET federateur = :1 WHERE  federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ctpyrating SET counterparty = :1 WHERE  counterparty = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.deposit_fils SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.deposit_fils SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.deposit_pere SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.deposit_pere SET portefeuille_depo = :1 WHERE  portefeuille_depo = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle SET entite_mere = :1 WHERE  entite_mere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.echelle SET portefeuille_mere = :1 WHERE  portefeuille_mere = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_condition SET code = :1 WHERE  code = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_cond_date SET condition = :1 WHERE  condition = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_marge SET condition = :1 WHERE  condition = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.fifo_solde_depo SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'UPDATE op.fifo_solde_depo SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.fifo_solde_depo SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.frais_gestion SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.groupe_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.groupe_provision SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_budget SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_compta set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_compta set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_compta set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_compta_solde set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_courtage SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_couverture SET tiers_deposit = :1 WHERE  tiers_deposit = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_couverture SET tiers_reception = :1 WHERE  tiers_reception = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_deposit SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_deposit SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_detenteur SET ancien_detenteur = :1 WHERE  ancien_detenteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_detenteur SET nouveau_detenteur = :1 WHERE  nouveau_detenteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_evenement set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set entity_corresp1=:1 where entity_corresp1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set entity_corresp2=:1 where entity_corresp2=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_facture SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_facture SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_fifo_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_fifo_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;

		REQ1 := 'UPDATE op.histo_fiscalite SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_fiscalite SET foyer = :1 WHERE  foyer = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_flux set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_limite_tr SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_limite_tr SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_liv_solde SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_livraison SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_livraison SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_livraison SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_matiere SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_matiere SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_matiere SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_mouv_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;

		REQ1 := 'UPDATE op.histo_mouvement SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_operation set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set compensateur=:1 where compensateur=:2';
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'update op.histo_operation set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set intermediaire=:1 where intermediaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set depositaire_2=:1 where depositaire_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set emetteur=:1 where emetteur=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set tiers_domicile=:1 where tiers_domicile=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'update op.histo_operation set tiers_libelle=null where tiers_libelle is not null';
		execute immediate REQ1;
		REQ1 := 'update op.histo_operation set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_parapheur SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_position_tr SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_pricing_detail SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille_tiers = :1 WHERE  portefeuille_tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_reg_releve SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_reg_solde SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_reg_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_reglement set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'update op.histo_reglement set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'UPDATE op.histo_titre_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.import_evenement SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.import_evenement SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.import_operation set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set compensateur=:1 where compensateur=:2';
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'update op.import_operation set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set intermediaire=:1 where intermediaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set depositaire_2=:1 where depositaire_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set emetteur=:1 where emetteur=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set tiers_domicile=:1 where tiers_domicile=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'update op.import_operation set tiers_libelle=null where tiers_libelle is not null';
		execute immediate REQ1;
		REQ1 := 'update op.import_operation set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.marge_compte_de SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.marge_regle SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.marge_regle SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_arrete SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_bafi_cpt SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_clonage SET por_maitre = :1 WHERE  por_maitre = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_clonage SET por_clone = :1 WHERE  por_clone = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_cpta_reg_gen SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_cpta_reg_ven SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_cpta_reg_ven SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_cpta_reg_ven SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_date SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_date SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_garanti_taux SET assureur = :1 WHERE  assureur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_marge_titre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_fils = :1 WHERE  portefeuille_fils = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_rappro_stock SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_sign_user SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo_budget SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo_flux SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.prevision_param SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.regle_rappro_auto SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.regle_rappro_auto SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_decalage SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_flux SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.reglement_flux SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_regle SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.spread_breakdown SET portfolio = :1 WHERE  portfolio = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.spread_breakdown SET entity = :1 WHERE  entity = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.spread_breakdown SET issuer = :1 WHERE  issuer = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.stress_results SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers SET entite_pere = :1 WHERE  entite_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET entite_fifo = :1 WHERE  entite_fifo = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso = :1 WHERE  tiers_conso = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_federateur = :1 WHERE  tiers_federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso2 = :1 WHERE  tiers_conso2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso3 = :1 WHERE  tiers_conso3 = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers SET adresse1 = :1 WHERE adresse1 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse2 = :1 WHERE adresse2 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse3 = :1 WHERE adresse3 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse4 = :1 WHERE adresse4 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse5 = :1 WHERE adresse5 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_compteur SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_foyer SET foyer = :1 WHERE  foyer = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers_foyer SET foyer_appartenance = :1 WHERE  foyer_appartenance = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_limite SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers_limite SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.titre SET emetteur = :1 WHERE  emetteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET bafi_garant = :1 WHERE  bafi_garant = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET domiciliataire = :1 WHERE  domiciliataire = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_bank_account set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_affilied_code set code_ref = :1 WHERE code_ref = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_third_party set adresse1 = :1 WHERE adresse1 = :2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.val_third_party set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.val_third_party set tiers_conso = :1 WHERE tiers_conso = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_table_security set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.valo_ccy_volat_rule SET portfolio = :1 WHERE  portfolio = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.valo_ccy_volat_rule SET entity = :1 WHERE  entity = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.valo_regle SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.valo_regle SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_contrat_cadre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_contrat_cadre SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_corresp SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET tiers_entite = :1 WHERE  tiers_entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_portef SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_portef SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_reg_liv SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_reg_liv SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_reg_liv SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.vue_affilie_tiers SET code_ref = :1 WHERE  code_ref = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_compte set valeur_1=:1 where valeur_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_2=:1 where valeur_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_3=:1 where valeur_3=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_4=:1 where valeur_4=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.utilisateur SET description = NULL WHERE description IS NOT NULL';
		execute immediate REQ1;

		REQ1 := 'UPDATE op.zba_payment_breakdown SET entity =:1 WHERE  entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_entity =:1 WHERE  mirrored_entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_portfolio =:1 WHERE  mirrored_portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET entity =:1 WHERE  entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET counterparty =:1 WHERE  counterparty =:2' ;
		execute immediate REQ1 using COLN,SCODE;
	END IF;
END IF;

IF ENTIT = 'Portefeuille' and PECRAN = 'w_tiers' THEN 

  IF FoldD='y' THEN  
  REQ1 := 'update op.structure set description=:1 where code=:2 and structure=:3 and ecran=:4';
  execute immediate REQ1 using COLN,SCODE, 'Entite', PECRAN;
  REQ1 := 'update op.tiers set description=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse1 = :1 WHERE adresse1 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse2 = :1 WHERE adresse2 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse3 = :1 WHERE adresse3 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse4 = :1 WHERE adresse4 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse5 = :1 WHERE adresse5 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Fold1<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Fold1||'=:1 where code=:2 and ' ||Fold1||' is not null' ;
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Fold2<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Fold2||'=:1 where code=:2 and ' ||Fold2||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Fold3<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Fold3||'=:1 where code=:2 and ' ||Fold3||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Fold4<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Fold4||'=:1 where code=:2 and ' ||Fold4||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Fold5<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Fold5||'=:1 where code=:2 and ' ||Fold5||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;

	IF FoldC='y' THEN 

		REQ1 := 'update op.structure set code=:1 where code=:2 and structure=:3 and ecran=:4';
		execute immediate REQ1 using COLN,SCODE, 'Entite', PECRAN;
		REQ1 := 'update op.tiers set code=:1 where code=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.param_marge_titre set entite=:1 where entite= :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.structure set pere=:1 where pere=:2 and structure=:3';
		execute immediate REQ1 using COLN,SCODE,'Entite';

		REQ1 := 'UPDATE op.ccp_breakdown set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.clearing_member_breakdown set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.budget_filtre set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.budget_regle set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_banque set agence=:1 where agence=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set banque=:1 where banque=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_banque set portefeuille_defaut=:1 where portefeuille_defaut=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_devise set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_filiale set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_filiale set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle_bqe set correspondant=:1 where correspondant=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_bqe set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.compte_regle_liv set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.compte_regle_liv set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.compte_titre SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.compte_titre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat SET emetteur = :1 WHERE  emetteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat_cadre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.contrat_cadre SET federateur = :1 WHERE  federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.contrat_instrument SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.contrat_instrument SET federateur = :1 WHERE  federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ctpyrating SET counterparty = :1 WHERE  counterparty = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.deposit_fils SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.deposit_fils SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.deposit_pere SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.deposit_pere SET portefeuille_depo = :1 WHERE  portefeuille_depo = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle SET entite_mere = :1 WHERE  entite_mere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.echelle SET portefeuille_mere = :1 WHERE  portefeuille_mere = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_condition SET code = :1 WHERE  code = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_cond_date SET condition = :1 WHERE  condition = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.echelle_marge SET condition = :1 WHERE  condition = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.fifo_solde_depo SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'UPDATE op.fifo_solde_depo SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.fifo_solde_depo SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.frais_gestion SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.groupe_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.groupe_provision SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_budget SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_compta set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_compta set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_compta set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_compta_solde set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_courtage SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_couverture SET tiers_deposit = :1 WHERE  tiers_deposit = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_couverture SET tiers_reception = :1 WHERE  tiers_reception = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_deposit SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_deposit SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_detenteur SET ancien_detenteur = :1 WHERE  ancien_detenteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_detenteur SET nouveau_detenteur = :1 WHERE  nouveau_detenteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_evenement set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set entity_corresp1=:1 where entity_corresp1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_evenement set entity_corresp2=:1 where entity_corresp2=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_facture SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_facture SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_fifo_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_fifo_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;

		REQ1 := 'UPDATE op.histo_fiscalite SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_fiscalite SET foyer = :1 WHERE  foyer = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_flux set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_flux set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_limite_tr SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_limite_tr SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_liv_solde SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_livraison SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_livraison SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_livraison SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_livraison set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_matiere SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_matiere SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_matiere SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_mouv_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;

		REQ1 := 'UPDATE op.histo_mouvement SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_operation set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set compensateur=:1 where compensateur=:2';
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'update op.histo_operation set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set intermediaire=:1 where intermediaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set depositaire_2=:1 where depositaire_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set emetteur=:1 where emetteur=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set tiers_domicile=:1 where tiers_domicile=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'update op.histo_operation set tiers_libelle=null where tiers_libelle is not null';
		execute immediate REQ1;
		REQ1 := 'update op.histo_operation set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_operation set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_parapheur SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_position_tr SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_pricing_detail SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille_tiers = :1 WHERE  portefeuille_tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_reg_releve SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.histo_reg_solde SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.histo_reg_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_reglement set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set tiers=:1 where tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.histo_reglement set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.histo_reglement set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'UPDATE op.histo_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'UPDATE op.histo_titre_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.import_evenement SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.import_evenement SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'update op.import_operation set clearing_member=:1 where clearing_member=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set entite=:1 where entite=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set contrepartie=:1 where contrepartie=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set compensateur=:1 where compensateur=:2';
		execute immediate REQ1 using COLNPENS,SCODE;
		REQ1 := 'update op.import_operation set filiale=:1 where filiale=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set intermediaire=:1 where intermediaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille=:1 where portefeuille=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set depositaire=:1 where depositaire=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set depositaire_2=:1 where depositaire_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set emetteur=:1 where emetteur=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_sender1=:1 where corresp_sender1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set corresp_sender2=:1 where corresp_sender2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set tiers_domicile=:1 where tiers_domicile=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set description=null where description is not null';
		execute immediate REQ1;
		REQ1 := 'update op.import_operation set tiers_libelle=null where tiers_libelle is not null';
		execute immediate REQ1;
		REQ1 := 'update op.import_operation set groupe_1=:1 where groupe_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set groupe_2=:1 where groupe_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'update op.import_operation set groupe_3=:1 where groupe_3=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.marge_compte_de SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.marge_regle SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.marge_regle SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_arrete SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_bafi_cpt SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_clonage SET por_maitre = :1 WHERE  por_maitre = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_clonage SET por_clone = :1 WHERE  por_clone = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_cpta_reg_gen SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_cpta_reg_ven SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_cpta_reg_ven SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_cpta_reg_ven SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_date SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_date SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_garanti_taux SET assureur = :1 WHERE  assureur = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_marge_titre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_fils = :1 WHERE  portefeuille_fils = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_rappro_stock SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.param_sign_user SET filiale = :1 WHERE  filiale = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo_budget SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.photo_flux SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.prevision_param SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.regle_rappro_auto SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.regle_rappro_auto SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_decalage SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_flux SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.reglement_flux SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.reglement_regle SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.spread_breakdown SET portfolio = :1 WHERE  portfolio = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.spread_breakdown SET entity = :1 WHERE  entity = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.spread_breakdown SET issuer = :1 WHERE  issuer = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.stress_results SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers SET entite_pere = :1 WHERE  entite_pere = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET entite_fifo = :1 WHERE  entite_fifo = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso = :1 WHERE  tiers_conso = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_federateur = :1 WHERE  tiers_federateur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso2 = :1 WHERE  tiers_conso2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET tiers_conso3 = :1 WHERE  tiers_conso3 = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers SET adresse1 = :1 WHERE adresse1 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse2 = :1 WHERE adresse2 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse3 = :1 WHERE adresse3 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse4 = :1 WHERE adresse4 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers SET adresse5 = :1 WHERE adresse5 is not null and code = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_compteur SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_foyer SET foyer = :1 WHERE  foyer = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers_foyer SET foyer_appartenance = :1 WHERE  foyer_appartenance = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.tiers_limite SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.tiers_limite SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.titre SET emetteur = :1 WHERE  emetteur = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET bafi_garant = :1 WHERE  bafi_garant = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.titre SET domiciliataire = :1 WHERE  domiciliataire = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_bank_account set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_affilied_code set code_ref = :1 WHERE code_ref = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_third_party set adresse1 = :1 WHERE adresse1 = :2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.val_third_party set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.val_third_party set tiers_conso = :1 WHERE tiers_conso = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.val_table_security set code = :1 WHERE code = :2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.valo_ccy_volat_rule SET portfolio = :1 WHERE  portfolio = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.valo_ccy_volat_rule SET entity = :1 WHERE  entity = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.valo_regle SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.valo_regle SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_contrat_cadre SET entite = :1 WHERE  entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_contrat_cadre SET tiers = :1 WHERE  tiers = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_corresp SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET tiers_entite = :1 WHERE  tiers_entite = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_corresp_bqe SET banque = :1 WHERE  banque = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_portef SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_portef SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_reg_liv SET depositaire = :1 WHERE  depositaire = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_reg_liv SET contrepartie = :1 WHERE  contrepartie = :2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_reg_liv SET portefeuille = :1 WHERE  portefeuille = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.vue_affilie_tiers SET code_ref = :1 WHERE  code_ref = :2' ;
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.ventiler_compte set valeur_1=:1 where valeur_1=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_2=:1 where valeur_2=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_3=:1 where valeur_3=:2';
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.ventiler_compte set valeur_4=:1 where valeur_4=:2';
		execute immediate REQ1 using COLN,SCODE;

		REQ1 := 'UPDATE op.utilisateur SET description = NULL WHERE description IS NOT NULL';
		execute immediate REQ1;

		REQ1 := 'UPDATE op.zba_payment_breakdown SET entity =:1 WHERE  entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_entity =:1 WHERE  mirrored_entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_portfolio =:1 WHERE  mirrored_portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET entity =:1 WHERE  entity =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
		execute immediate REQ1 using COLN,SCODE;
		REQ1 := 'UPDATE op.zba_transfer_breakdown SET counterparty =:1 WHERE  counterparty =:2' ;
		execute immediate REQ1 using COLN,SCODE;
	END IF;
END IF;

IF ENTIT = 'Tiers' and PECRAN = 'w_tiers' THEN 

  IF TierD='y' THEN  
  REQ1 := 'update op.structure set description=:1 where code=:2 and structure=:3 and ecran=:4';
  execute immediate REQ1 using COLN,SCODE, 'Compte', PECRAN;
  REQ1 := 'update op.tiers set description=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse1 = :1 WHERE adresse1 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse2 = :1 WHERE adresse2 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse3 = :1 WHERE adresse3 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse4 = :1 WHERE adresse4 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.tiers SET adresse5 = :1 WHERE adresse5 is not null and code = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Tier1<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Tier1||'=:1 where code=:2 and ' ||Tier1||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Tier2<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Tier2||'=:1 where code=:2 and ' ||Tier2||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Tier3<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Tier3||'=:1 where code=:2 and ' ||Tier3||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Tier4<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Tier4||'=:1 where code=:2 and ' ||Tier4||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Tier5<>'n' THEN  
  REQ1 := 'update op.tiers set ' ||Tier5||'=:1 where code=:2 and ' ||Tier5||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;

  IF TierC='y' THEN 
    REQ1 := 'update op.structure set code=:1 where code=:2 and structure=:3 and ecran=:4';
    execute immediate REQ1 using COLN,SCODE, 'Compte', PECRAN;
    REQ1 := 'update op.tiers set code=:1 where code=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.param_marge_titre set entite=:1 where entite= :2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.structure set pere=:1 where pere=:2 and structure=:3';
    execute immediate REQ1 using COLN,SCODE,'Compte';
    
    REQ1 := 'UPDATE op.ccp_breakdown set clearing_member=:1 where clearing_member=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.clearing_member_breakdown set clearing_member=:1 where clearing_member=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.budget_filtre set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.budget_regle set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_banque set agence=:1 where agence=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_banque set banque=:1 where banque=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_banque set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_banque set portefeuille_defaut=:1 where portefeuille_defaut=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_devise set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_filiale set filiale=:1 where filiale=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_filiale set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_regle set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_regle_bqe set correspondant=:1 where correspondant=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_bqe set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_bqe set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_bqe set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_bqe set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.compte_regle_liv set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_liv set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_liv set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.compte_regle_liv set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.compte_titre SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.compte_titre SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    --REQ1 := 'UPDATE op.conditions_echelle SET condition = :1 WHERE  condition = :2' ;
    --execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.contrat SET emetteur = :1 WHERE  emetteur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.contrat_cadre SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.contrat_cadre SET federateur = :1 WHERE  federateur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.contrat_instrument SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.contrat_instrument SET federateur = :1 WHERE  federateur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ctpyrating SET counterparty = :1 WHERE  counterparty = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.deposit_fils SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.deposit_fils SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.deposit_pere SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.deposit_pere SET portefeuille_depo = :1 WHERE  portefeuille_depo = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.echelle SET entite_mere = :1 WHERE  entite_mere = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.echelle SET portefeuille_mere = :1 WHERE  portefeuille_mere = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.echelle_condition SET code = :1 WHERE  code = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.echelle_cond_date SET condition = :1 WHERE  condition = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.echelle_marge SET condition = :1 WHERE  condition = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.fifo_solde_depo SET compensateur = :1 WHERE  compensateur = :2' ;
    execute immediate REQ1 using COLNPENS,SCODE;
    REQ1 := 'UPDATE op.fifo_solde_depo SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.fifo_solde_depo SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.frais_gestion SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.groupe_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.groupe_provision SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_budget SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_compta set tiers=:1 where tiers=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_compta set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_compta set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_compta_solde set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_courtage SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_couverture SET tiers_deposit = :1 WHERE  tiers_deposit = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_couverture SET tiers_reception = :1 WHERE  tiers_reception = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_deposit SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_deposit SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_detenteur SET ancien_detenteur = :1 WHERE  ancien_detenteur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_detenteur SET nouveau_detenteur = :1 WHERE  nouveau_detenteur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_evenement set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_evenement set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_evenement set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_evenement set entity_corresp1=:1 where entity_corresp1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_evenement set entity_corresp2=:1 where entity_corresp2=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_facture SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_facture SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_fifo_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_fifo_solde SET compensateur = :1 WHERE  compensateur = :2' ;
    execute immediate REQ1 using COLNPENS,SCODE;
    
    REQ1 := 'UPDATE op.histo_fiscalite SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_fiscalite SET foyer = :1 WHERE  foyer = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_flux set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_flux set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_flux set tiers=:1 where tiers=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_flux set groupe_1=:1 where groupe_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_flux set groupe_2=:1 where groupe_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_flux set groupe_3=:1 where groupe_3=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_limite_tr SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_limite_tr SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_liv_solde SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_livraison SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_livraison SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_livraison SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_livraison set groupe_1=:1 where groupe_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_livraison set groupe_2=:1 where groupe_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_livraison set groupe_3=:1 where groupe_3=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_matiere SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_matiere SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_matiere SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_mouv_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
    execute immediate REQ1 using COLNPENS,SCODE;
    
    REQ1 := 'UPDATE op.histo_mouvement SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_operation set clearing_member=:1 where clearing_member=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set compensateur=:1 where compensateur=:2';
    execute immediate REQ1 using COLNPENS,SCODE;
    REQ1 := 'update op.histo_operation set filiale=:1 where filiale=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set intermediaire=:1 where intermediaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set depositaire_2=:1 where depositaire_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set emetteur=:1 where emetteur=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set corresp_sender1=:1 where corresp_sender1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set corresp_sender2=:1 where corresp_sender2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set tiers_domicile=:1 where tiers_domicile=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set description=null where description is not null';
    execute immediate REQ1;
    REQ1 := 'update op.histo_operation set tiers_libelle=null where tiers_libelle is not null';
    execute immediate REQ1;
    REQ1 := 'update op.histo_operation set groupe_1=:1 where groupe_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set groupe_2=:1 where groupe_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_operation set groupe_3=:1 where groupe_3=:2';
    execute immediate REQ1 using COLN,SCODE;    

    REQ1 := 'UPDATE op.histo_parapheur SET filiale = :1 WHERE  filiale = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_position_tr SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_pricing_detail SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_pricing_detail SET portefeuille_tiers = :1 WHERE  portefeuille_tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_reg_releve SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_reg_solde SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.histo_reg_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.histo_reglement set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set tiers=:1 where tiers=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set corresp_receiver1=:1 where corresp_receiver1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set corresp_receiver2=:1 where corresp_receiver2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set corresp_sender1=:1 where corresp_sender1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set corresp_sender2=:1 where corresp_sender2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set description=null where description is not null';
    execute immediate REQ1;
    REQ1 := 'update op.histo_reglement set groupe_1=:1 where groupe_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set groupe_2=:1 where groupe_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.histo_reglement set groupe_3=:1 where groupe_3=:2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.histo_titre_solde SET compensateur = :1 WHERE  compensateur = :2' ;
    execute immediate REQ1 using COLNPENS,SCODE;
    REQ1 := 'UPDATE op.histo_titre_solde SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.import_evenement SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.import_evenement SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.import_evenement SET cpty_corresp1 = :1 WHERE cpty_corresp1 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.import_evenement SET cpty_corresp2 = :1 WHERE cpty_corresp2 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.import_evenement SET entity_corresp1 = :1 WHERE entity_corresp1 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.import_evenement SET entity_corresp2 = :1 WHERE entity_corresp2 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'update op.import_operation set clearing_member=:1 where clearing_member=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set entite=:1 where entite=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set contrepartie=:1 where contrepartie=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set compensateur=:1 where compensateur=:2';
    execute immediate REQ1 using COLNPENS,SCODE;
    REQ1 := 'update op.import_operation set filiale=:1 where filiale=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set intermediaire=:1 where intermediaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set portefeuille=:1 where portefeuille=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set portefeuille_tiers=:1 where portefeuille_tiers=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set depositaire=:1 where depositaire=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set depositaire_2=:1 where depositaire_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set emetteur=:1 where emetteur=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set corresp_receiver1=:1 where corresp_receiver1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set corresp_receiver2=:1 where corresp_receiver2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set corresp_sender1=:1 where corresp_sender1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set corresp_sender2=:1 where corresp_sender2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set portefeuille_deposit=:1 where portefeuille_deposit=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set tiers_domicile=:1 where tiers_domicile=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set description=null where description is not null';
    execute immediate REQ1;
    REQ1 := 'update op.import_operation set tiers_libelle=null where tiers_libelle is not null';
    execute immediate REQ1;
    REQ1 := 'update op.import_operation set groupe_1=:1 where groupe_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set groupe_2=:1 where groupe_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'update op.import_operation set groupe_3=:1 where groupe_3=:2';
    execute immediate REQ1 using COLN,SCODE;   
    
    REQ1 := 'UPDATE op.marge_compte_de SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.marge_regle SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.marge_regle SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_arrete SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_bafi_cpt SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_clonage SET por_maitre = :1 WHERE  por_maitre = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.param_clonage SET por_clone = :1 WHERE  por_clone = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_cpta_reg_gen SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_cpta_reg_ven SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.param_cpta_reg_ven SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.param_cpta_reg_ven SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_date SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.param_date SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_garanti_taux SET assureur = :1 WHERE  assureur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_marge_titre SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_pere = :1 WHERE  portefeuille_pere = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.param_ope_bloc SET portefeuille_fils = :1 WHERE  portefeuille_fils = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_parapheur_det SET filiale = :1 WHERE  filiale = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_rappro_stock SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.param_sign_user SET filiale = :1 WHERE  filiale = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.photo SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.photo_budget SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.photo_flux SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.prevision_param SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.regle_rappro_auto SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.regle_rappro_auto SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.reglement_decalage SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.reglement_flux SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.reglement_flux SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.reglement_regle SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.spread_breakdown SET portfolio = :1 WHERE  portfolio = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.spread_breakdown SET entity = :1 WHERE  entity = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.spread_breakdown SET issuer = :1 WHERE  issuer = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.stress_results SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.tiers SET entite_pere = :1 WHERE  entite_pere = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers SET entite_fifo = :1 WHERE  entite_fifo = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers SET tiers_conso = :1 WHERE  tiers_conso = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers SET tiers_federateur = :1 WHERE  tiers_federateur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers SET tiers_conso2 = :1 WHERE  tiers_conso2 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers SET tiers_conso3 = :1 WHERE  tiers_conso3 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.tiers_compteur SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.tiers_foyer SET foyer = :1 WHERE  foyer = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers_foyer SET foyer_appartenance = :1 WHERE  foyer_appartenance = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.tiers_limite SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.tiers_limite SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.titre SET emetteur = :1 WHERE  emetteur = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.titre SET bafi_garant = :1 WHERE  bafi_garant = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.titre SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.titre SET domiciliataire = :1 WHERE  domiciliataire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.val_bank_account set code = :1 WHERE code = :2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.val_affilied_code set code_ref = :1 WHERE code_ref = :2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.val_third_party set adresse1 = :1 WHERE adresse1 = :2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.val_third_party set code = :1 WHERE code = :2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.val_third_party set tiers_conso = :1 WHERE tiers_conso = :2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.val_table_security set code = :1 WHERE code = :2';
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.valo_ccy_volat_rule SET portfolio = :1 WHERE  portfolio = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.valo_ccy_volat_rule SET entity = :1 WHERE  entity = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.valo_regle SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.valo_regle SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_contrat_cadre SET entite = :1 WHERE  entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_contrat_cadre SET tiers = :1 WHERE  tiers = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_corresp SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_corresp_bqe SET tiers_entite = :1 WHERE  tiers_entite = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp_bqe SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_1 = :1 WHERE  correspondant_1 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp_bqe SET correspondant_2 = :1 WHERE  correspondant_2 = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_corresp_bqe SET banque = :1 WHERE  banque = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_portef SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_portef SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_reg_liv SET depositaire = :1 WHERE  depositaire = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_reg_liv SET contrepartie = :1 WHERE  contrepartie = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_reg_liv SET portefeuille = :1 WHERE  portefeuille = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.vue_affilie_tiers SET code_ref = :1 WHERE  code_ref = :2' ;
    execute immediate REQ1 using COLN,SCODE;
    
    REQ1 := 'UPDATE op.ventiler_compte set valeur_1=:1 where valeur_1=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_compte set valeur_2=:1 where valeur_2=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_compte set valeur_3=:1 where valeur_3=:2';
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.ventiler_compte set valeur_4=:1 where valeur_4=:2';
    execute immediate REQ1 using COLN,SCODE;

    REQ1 := 'UPDATE op.utilisateur SET description = NULL WHERE description IS NOT NULL';
    execute immediate REQ1;

    REQ1 := 'UPDATE op.zba_payment_breakdown SET entity =:1 WHERE  entity =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_payment_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_entity =:1 WHERE  mirrored_entity =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_portfolio =:1 WHERE  mirrored_portfolio =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_transfer_breakdown SET entity =:1 WHERE  entity =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_transfer_breakdown SET portfolio =:1 WHERE  portfolio =:2' ;
    execute immediate REQ1 using COLN,SCODE;
    REQ1 := 'UPDATE op.zba_transfer_breakdown SET counterparty =:1 WHERE  counterparty =:2' ;
    execute immediate REQ1 using COLN,SCODE;
   END IF;
END IF;

IF ENTIT = 'Compte' and PECRAN= 'w_compte_banque' THEN 

  IF CpteD='y' THEN  
  REQ1 := 'update op.structure set description=:1 where code=:2 and structure=:3 and ecran=:4';
  execute immediate REQ1 using COLN,SCODE, ENTIT, PECRAN;
  REQ1 := 'update op.compte_banque set description=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Cpte1<>'n' THEN  
  REQ1 := 'update op.compte_banque set ' ||Cpte1||'=:1 where code=:2 and ' ||Cpte1||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Cpte2<>'n' THEN  
  REQ1 := 'update op.compte_banque set ' ||Cpte2||'=:1 where code=:2 and ' ||Cpte2||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Cpte3<>'n' THEN  
  REQ1 := 'update op.compte_banque set ' ||Cpte3||'=:1 where code=:2 and ' ||Cpte3||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Cpte4<>'n' THEN  
  REQ1 := 'update op.compte_banque set ' ||Cpte4||'=:1 where code=:2 and ' ||Cpte4||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;
  
  IF Cpte5<>'n' THEN  
  REQ1 := 'update op.compte_banque set ' ||Cpte5||'=:1 where code=:2 and ' ||Cpte5||' is not null';
  execute immediate REQ1 using COLN,SCODE;
  END IF;

  IF CpteC='y' THEN
  REQ1 := 'update op.structure set code=:1 where code=:2 and structure=:3 and ecran=:4';
  execute immediate REQ1 using COLN,SCODE, ENTIT, PECRAN;
  REQ1 := 'update op.compte_banque set code=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.compte_banque set code_bban=:1 where code=:2';
  execute immediate REQ1 using COLN,SCODE;
  
  REQ1 := 'update op.histo_reglement SET compte=:1 WHERE compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.histo_reg_solde SET compte=:1 WHERE compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.echelle set compte_reglement=:1 where compte_reglement=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.echelle_compte set compte=:1 where compte=:2';
  execute immediate REQ1 using COLN,SCODE;
--  REQ1 := 'UPDATE op.affilie_code SET code_ref=:1, description=:1 where code_ref=:2 and nom_table=:3';
--  execute immediate REQ1 using COLN,SCODE,COLN1;
--  REQ1 := 'UPDATE op.affilie_code SET entite=:1, description=:1 where entite=:2';
--  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.ccp_breakdown SET clearing_member=:1 where clearing_member=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.clearing_member_breakdown set clearing_member=:1 where clearing_member=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_devise SET compte=:1 where compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_regle SET compte=:1 where compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_regle_bqe SET compte=:1 where compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_regle_liv SET compte=:1 where compte=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation set clearing_member=:1 where clearing_member=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET compte_entite=:1 where compte_entite=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET compte_tiers=:1 WHERE compte_tiers=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET compte_filiale=:1 WHERE compte_filiale=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET compte_tiers_2=:1 WHERE compte_tiers_2 =:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET compte_entite_2=:1 WHERE compte_entite_2=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_operation SET tiers_iban_compte=:1 WHERE tiers_iban_compte=:2';
  execute immediate REQ1 using COLN,SCODE;

  REQ1 := 'UPDATE op.histo_reglement SET cpty_account=:1 WHERE cpty_account=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.histo_reglement set description=null where description is not null';
  execute immediate REQ1;
  REQ1 := 'update op.histo_reglement set groupe_1=:1 where groupe_1=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.histo_reglement set groupe_2=:1 where groupe_2=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'update op.histo_reglement set groupe_3=:1 where groupe_3=:2';
  execute immediate REQ1 using COLN,SCODE;

  REQ1 := 'UPDATE op.import_evenement SET cpty_account = :1 WHERE cpty_account = :2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.import_evenement SET entity_account = :1 WHERE entity_account = :2' ;
  execute immediate REQ1 using COLN,SCODE;

  REQ1 := 'UPDATE op.import_operation set clearing_member=:1 where clearing_member=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.import_operation SET compte_entite=:1 where compte_entite=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.import_operation SET compte_tiers=:1 WHERE compte_tiers=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.import_operation SET compte_filiale=:1 WHERE compte_filiale=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.import_operation SET compte_tiers_2=:1 WHERE compte_tiers_2 =:2';
  execute immediate REQ1 using COLN,SCODE;

  REQ1 := 'UPDATE op.ventiler_compte set valeur_1=:1 where valeur_1=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.ventiler_compte set valeur_2=:1 where valeur_2=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.ventiler_compte set valeur_3=:1 where valeur_3=:2';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.ventiler_compte set valeur_4=:1 where valeur_4=:2';
  execute immediate REQ1 using COLN,SCODE;

  -- histo_mouvement description/libelle: handled by 05_op_performance_boost.sql pre-clear
  -- (Original code had a bug: set to literal single-quote instead of NULL, 2016x full-scan)
  UPDATE op.histo_mouvement SET description = NULL WHERE description IS NOT NULL;
  UPDATE op.histo_mouvement SET libelle = NULL WHERE libelle IS NOT NULL;

  REQ1 := 'UPDATE op.utilisateur SET description = NULL WHERE description IS NOT NULL';
  execute immediate REQ1;

  REQ1 := 'UPDATE op.structure SET pere =:1 WHERE pere =:2 AND structure = ''Compte''';
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_banque SET compte_previs_glob =:1 WHERE  compte_previs_glob =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.compte_filiale SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.contrat_cadre SET compte_echelle =:1 WHERE  compte_echelle =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.decouvert_compte SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_effet SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_effet SET compte_effet =:1 WHERE  compte_effet =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_fiscalite SET compte_fiscal =:1 WHERE  compte_fiscal =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_ligne SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_prevision SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_cpta_reg_gen SET compte_ana =:1 WHERE  compte_ana =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_cpta_reg_ven SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_effet_paye SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_effet_recu SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_fiche_val_detail SET code =:1 WHERE  code =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_net_reg SET compte_comp =:1 WHERE  compte_comp =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.param_net_reg SET compte_pivot =:1 WHERE  compte_pivot =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.prevision_param SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.reglement_decalage SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.reglement_flux SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.reglement_regle SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.virement_compte SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.vue_affilie_compte SET code_ref =:1 WHERE  code_ref =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_breakdown SET centralizer_account =:1 WHERE  centralizer_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_payment_breakdown SET centralizer_account =:1 WHERE  centralizer_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_payment_breakdown SET current_account =:1 WHERE  current_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_payment_breakdown SET mirrored_current_account =:1 WHERE  mirrored_current_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_transfer_breakdown SET centralizer_account =:1 WHERE  centralizer_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_transfer_breakdown SET counterparty_account =:1 WHERE  counterparty_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.zba_transfer_breakdown SET entity_account =:1 WHERE  entity_account =:2' ;
  execute immediate REQ1 using COLN,SCODE;
-------Anonymization of Histo_mouvement 
  REQ1 := 'UPDATE op.regle_rappro_auto SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_mouv_solde SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_mouvement SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_mouvement SET compte_contrepartie =:1 WHERE  compte_contrepartie =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_reg_conso SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;
  REQ1 := 'UPDATE op.histo_reg_releve SET compte =:1 WHERE  compte =:2' ;
  execute immediate REQ1 using COLN,SCODE;

  END IF; 
END IF;
  -------------APRES CETTE SECTION METTRE LES COMPTES NON GERES

COLN := DESCRIPT;
COLNPENS := DESCRIPT;

    execute immediate 'commit';

END LOOP;

close s_structure;
exception WHEN OTHERS THEN
RAISE_APPLICATION_ERROR (-20001, 'Error...' || to_char(SQLCODE) || ' ' || substr(SQLERRM,1,100)|| ' '||REQ1);
END;

END;
/
