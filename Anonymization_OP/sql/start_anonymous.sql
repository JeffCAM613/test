define BASENAME = &1
define SYSPASS = &2
define OPPASS = &3
define EntC = &4
define EntD = &5
define Ent1 = &6
define Ent2 = &7
define Ent3 = &8
define Ent4 = &9
define Ent5 = &10
define FoldC = &11
define FoldD = &12
define Fold1 = &13
define Fold2 = &14
define Fold3 = &15
define Fold4 = &16
define Fold5 = &17
define TierC = &18
define TierD = &19
define Tier1 = &20
define Tier2 = &21
define Tier3 = &22
define Tier4 = &23
define Tier5 = &24
define CpteC = &25
define CpteD = &26
define Cpte1 = &27
define Cpte2 = &28
define Cpte3 = &29
define Cpte4 = &30
define Cpte5 = &31
define TBSDATA = &32
define TBSINDEX = &33

conn sys/&SYSPASS@&BASENAME as sysdba; 
set echo on;
spool anonyme.log

drop user atrace cascade;

--whenever sqlerror exit sql.sqlcode

grant select on sys.dba_users to op;
grant select on sys.dba_data_files to op;
grant select on sys.dba_objects to op;
alter system set optimizer_mode=first_rows;
alter system set undo_retention=28800;
alter user OP quota unlimited on &TBSDATA;

create user atrace identified by atrace default tablespace data quota unlimited on &TBSDATA;
create table atrace.ref_tables_modif(table_name varchar2(80),field_name varchar2(40), old_value varchar2(80), new_value varchar2(80));
create unique index op.ndx_anno on atrace.ref_tables_modif(table_name,field_name,old_value,new_value);
grant select on atrace.ref_tables_modif to op;
grant insert,update,delete on atrace.ref_tables_modif to op;

connect op/&OPPASS@&BASENAME

--whenever sqlerror exit sql.sqlcode
-- Create pack_anonym to execute later...
@sql\02pack_anonym_number.sql;

-- Disable triggers BEFORE pre-clear to avoid ORA-01858 from
-- OBS_ACCOUNTING_PAYMENT / OBS_ACCOUNTING_DEAL firing during bulk updates
execute pack_anonym.disable_enable_all_triggers('D');

-- Performance boost: pre-clear histo description fields to avoid repeated full scans
-- This saves 6-8 hours on large instances (3M+ histo_reglement rows)
@sql\05_op_performance_boost.sql;

-- if already does exists -> continue
whenever sqlerror continue
drop index ndx_compte_bqe_1;
drop index ndx_his_courtage1;
drop index ndx_his_flx1;
drop index ndx_his_flx2;
drop index ndx_his_flx3;
drop index ndx_his_liv1;
drop index ndx_his_liv2;
drop index ndx_his_liv3;
drop index ndx_his_matiere1;
drop index ndx_his_matiere2;
drop index ndx_his_matiere3;
drop index ndx_his_mouv_1;
drop index ndx_his_op_up1;
drop index ndx_his_op_up2;
drop index ndx_his_op_up3;
drop index ndx_his_op_up4;
drop index ndx_his_op_up5;
drop index ndx_his_op_up6;
drop index ndx_his_op_up7;
drop index ndx_his_op_up8;
drop index ndx_his_op_up9;
drop index ndx_his_op_up10;
drop index ndx_his_op_up11;
drop index ndx_his_op_up12;
drop index ndx_his_op_up13;
drop index ndx_his_op_up14;
drop index ndx_his_op_up15;
drop index ndx_his_op_up16;
drop index ndx_his_op_up17;
drop index ndx_his_op_up18;
drop index ndx_his_op_up19;
drop index ndx_his_op_up20;
drop index ndx_imp_eve1;
drop index ndx_imp_eve2;
drop index ndx_imp_eve3;
drop index ndx_imp_eve4;
drop index ndx_imp_eve5;
create bitmap index ndx_his_coutage1 on op.histo_courtage(tiers) TABLESPACE &TBSINDEX;
create bitmap index ndx_his_ev_up1 on op.histo_evenement(entite) tablespace &TBSINDEX;
create bitmap index ndx_his_ev_up2 on op.histo_evenement(depositaire) tablespace &TBSINDEX;
create bitmap index ndx_his_ev_up3 on op.histo_evenement(entity_corresp1) tablespace &TBSINDEX;
create bitmap index ndx_his_ev_up4 on op.histo_evenement(entity_corresp2) tablespace &TBSINDEX;
create bitmap index ndx_his_ev_up5 on op.histo_evenement(contrepartie) tablespace &TBSINDEX;
--
create bitmap index ndx_his_matiere1 on op.histo_matiere(entite) TABLESPACE &TBSINDEX;
create bitmap index ndx_his_matiere2 on op.histo_matiere(tiers) TABLESPACE &TBSINDEX;
create bitmap index ndx_his_matiere3 on op.histo_matiere(portefeuille) TABLESPACE &TBSINDEX;
--
create bitmap index ndx_his_mouv_1 on op.histo_mouvement(entite) tablespace &TBSINDEX;
--
create bitmap index ndx_his_op_up1 on op.histo_operation(compensateur) tablespace &TBSINDEX;
create index ndx_his_op_up2 on op.histo_operation(corresp_receiver1) tablespace &TBSINDEX;
create index ndx_his_op_up3 on op.histo_operation(corresp_receiver2) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up4 on op.histo_operation(corresp_sender1) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up5 on op.histo_operation(corresp_sender2) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up6 on op.histo_operation(portefeuille_deposit) tablespace &TBSINDEX;
create index ndx_his_op_up7 on op.histo_operation(contrepartie) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up8 on op.histo_operation(filiale) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up9 on op.histo_operation(intermediaire) tablespace &TBSINDEX;
create index ndx_his_op_up10 on op.histo_operation(portefeuille_tiers) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up11 on op.histo_operation(depositaire) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up12 on op.histo_operation(depositaire_2) tablespace &TBSINDEX;
create index ndx_his_op_up13 on op.histo_operation(emetteur) tablespace &TBSINDEX;
create index ndx_his_op_up14 on op.histo_operation(compte_tiers) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up15 on op.histo_operation(entite) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up16 on op.histo_operation(portefeuille) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up18 on op.histo_operation(compte_filiale) tablespace &TBSINDEX;
--
create bitmap index ndx_his_reg_up1 on op.histo_reglement(entite) tablespace &TBSINDEX;
create index ndx_his_reg_up2 on op.histo_reglement(tiers) tablespace &TBSINDEX;
create index ndx_his_reg_up3 on op.histo_reglement(corresp_receiver1) tablespace &TBSINDEX;
create bitmap index ndx_his_reg_up4 on op.histo_reglement(corresp_receiver2) tablespace &TBSINDEX;
create bitmap index ndx_his_reg_up5 on op.histo_reglement(corresp_sender1) tablespace &TBSINDEX;
create bitmap index ndx_his_reg_up6 on op.histo_reglement(corresp_sender2) tablespace &TBSINDEX;
create bitmap index ndx_his_reg_up7 on op.histo_reglement(portefeuille) tablespace &TBSINDEX;
create bitmap index ndx_his_reg_cpty on op.histo_reglement(cpty_account) tablespace &TBSINDEX;
--
create bitmap index ndx_his_compta_up1 on op.histo_compta(standard) tablespace &TBSINDEX;
create bitmap index ndx_his_compta_up2 on op.histo_compta(entite) tablespace &TBSINDEX;
create index ndx_his_compta_up3 on op.histo_compta(tiers) tablespace &TBSINDEX;
create index ndx_his_compta_up4 on op.histo_compta(portefeuille) tablespace &TBSINDEX;
--
create bitmap index ndx_his_flx1 on histo_flux(portefeuille) tablespace &TBSINDEX;
create index ndx_his_flx2 on histo_flux(tiers) tablespace &TBSINDEX;
create bitmap index ndx_his_flx3 on histo_flux(entite) tablespace &TBSINDEX;
--
create index ndx_his_liv1 on histo_livraison(tiers) tablespace &TBSINDEX;
create index ndx_his_liv2 on histo_livraison(portefeuille) tablespace &TBSINDEX;
create index ndx_his_liv3 on histo_livraison(entite) tablespace &TBSINDEX;
--
create bitmap index ndx_imp_eve1 on op.import_evenement(entite) tablespace &TBSINDEX;
create bitmap index ndx_imp_eve2 on op.import_evenement(contrepartie) tablespace &TBSINDEX;
whenever sqlerror exit sql.sqlcode

@sql\03anon_triggers.sql;

select 'start procedure ENTITE' from dual;
set timing on
set serveroutput on
execute pack_anonym.anonymous_tables('Entite','E_','w_tiers','&EntC','&EntD','&Ent1','&Ent2','&Ent3','&Ent4','&Ent5','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n');
set timing off
commit;

select 'start procedure PORTEFEUILLE' from dual;
set timing on
set serveroutput on
execute pack_anonym.anonymous_tables('Portefeuille','P_','w_tiers','n','n','n','n','n','n','n','&FoldC','&FoldD','&Fold1','&Fold2','&Fold3','&Fold4','&Fold5','n','n','n','n','n','n','n','n','n','n','n','n','n','n');
set timing off
commit;

select 'start procedure TIERS' from dual;
set timing on
execute pack_anonym.anonymous_tables('Tiers','T_','w_tiers','n','n','n','n','n','n','n','n','n','n','n','n','n','n','&TierC','&TierD','&Tier1','&Tier2','&Tier3','&Tier4','&Tier5','n','n','n','n','n','n','n');
set timing off
commit;

whenever sqlerror continue

create index ndx_compte_bqe_1 on op.compte_regle_bqe(compte) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up17 on op.histo_operation(compte_entite) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up19 on op.histo_operation(compte_tiers_2) tablespace &TBSINDEX;
create bitmap index ndx_his_op_up20 on op.histo_operation(compte_entite_2) tablespace &TBSINDEX;

whenever sqlerror exit sql.sqlcode

select 'start procedure COMPTE_BANQUE' from dual;
set timing on
execute pack_anonym.anonymous_tables('Compte','CB_','w_compte_banque','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','n','&CpteC','&CpteD','&Cpte1','&Cpte2','&Cpte3','&Cpte4','&Cpte5');
set timing off
commit;

whenever sqlerror continue

drop index ndx_compte_bqe_1;
drop index ndx_his_courtage1;
drop index ndx_his_flx1;
drop index ndx_his_flx2;
drop index ndx_his_flx3;
drop index ndx_his_liv1;
drop index ndx_his_liv2;
drop index ndx_his_liv3;
drop index ndx_his_matiere1;
drop index ndx_his_matiere2;
drop index ndx_his_matiere3;
drop index ndx_his_mouv_1;
drop index ndx_his_op_up1;
drop index ndx_his_op_up2;
drop index ndx_his_op_up3;
drop index ndx_his_op_up4;
drop index ndx_his_op_up5;
drop index ndx_his_op_up6;
drop index ndx_his_op_up7;
drop index ndx_his_op_up8;
drop index ndx_his_op_up9;
drop index ndx_his_op_up10;
drop index ndx_his_op_up11;
drop index ndx_his_op_up12;
drop index ndx_his_op_up13;
drop index ndx_his_op_up14;
drop index ndx_his_op_up15;
drop index ndx_his_op_up16;
drop index ndx_his_op_up17;
drop index ndx_his_op_up18;
drop index ndx_his_op_up19;
drop index ndx_his_op_up20;
drop index ndx_imp_eve1;
drop index ndx_imp_eve2;
drop index ndx_imp_eve3;
drop index ndx_imp_eve4;
drop index ndx_imp_eve5;


connect sys/&SYSPASS@&BASENAME as sysdba
@sql\04drop_anon_triggers.sql
execute op.pack_anonym.disable_enable_all_triggers('E');
set echo off;
spool off;
EXIT;