--create table atrace.ref_tables_modif(table_name varchar2(80),field_name varchar2(40),old_value varchar2(80),new_value varchar2(80));
--create unique index ndx_anno on atrace.ref_tables_modif(table_name,field_name,old_value,new_value);




create or replace trigger op.anon_1 after update of code_ref, entite on op.affilie_code for each row
begin
if :new.code_ref != :old.code_ref then
insert into atrace.ref_tables_modif values ('affilie_code','code_ref',to_char(:old.code_ref),to_char(:new.code_ref));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values('affilie_code','entite',:old.entite,:new.entite);
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_2 after update of entite on op.budget_filtre for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('budget_filtre','entite',to_char(:old.entite),to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_3 after update of entite on op.budget_regle for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('budget_regle','entite',to_char(:old.entite),to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_4 after update of agence,banque,code,entite,portefeuille_defaut,description,numero_banque,numero_guichet,numero_compte,numero_cle,code_paysiso,cle_iban,code_bban,compte_previs_glob,groupe_1,groupe_2,groupe_3 
on op.compte_banque for each row
begin
if :new.agence != :old.agence then
insert into atrace.ref_tables_modif values ('compte_banque','agence',to_char(:old.agence),to_char(:new.agence));
end if;
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('compte_banque','banque',to_char(:old.banque),to_char(:new.banque));
end if;
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('compte_banque','code',to_char(:old.code),to_char(:new.code));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_banque','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.portefeuille_defaut != :old.portefeuille_defaut then
insert into atrace.ref_tables_modif values ('compte_banque','portefeuille_defaut',to_char(:old.portefeuille_defaut),to_char(:new.portefeuille_defaut));
end if;
if :new.description != :old.description then
insert into atrace.ref_tables_modif values ('compte_banque','description',to_char(:old.description),to_char(:new.description));
end if;
if :new.numero_banque != :old.numero_banque then
insert into atrace.ref_tables_modif values ('compte_banque','numero_banque',to_char(:old.numero_banque),to_char(:new.numero_banque));
end if;
if :new.numero_guichet != :old.numero_guichet then
insert into atrace.ref_tables_modif values ('compte_banque','numero_guichet',to_char(:old.numero_guichet),to_char(:new.numero_guichet));
end if;
if :new.numero_compte != :old.numero_compte then
insert into atrace.ref_tables_modif values ('compte_banque','numero_compte',to_char(:old.numero_compte),to_char(:new.numero_compte));
end if;
if :new.numero_cle != :old.numero_cle then
insert into atrace.ref_tables_modif values ('compte_banque','numero_cle',to_char(:old.numero_cle),to_char(:new.numero_cle));
end if;
if :new.code_paysiso != :old.code_paysiso then
insert into atrace.ref_tables_modif values ('compte_banque','code_paysiso',to_char(:old.code_paysiso),to_char(:new.code_paysiso));
end if;
if :new.cle_iban != :old.cle_iban then
insert into atrace.ref_tables_modif values ('compte_banque','cle_iban',to_char(:old.cle_iban),to_char(:new.cle_iban));
end if;
if :new.code_bban != :old.code_bban then
insert into atrace.ref_tables_modif values ('compte_banque','code_bban',to_char(:old.code_bban),to_char(:new.code_bban));
end if;
if :new.compte_previs_glob != :old.compte_previs_glob then
insert into atrace.ref_tables_modif values ('compte_banque','compte_previs_glob',to_char(:old.compte_previs_glob),to_char(:new.compte_previs_glob));
end if;
if :new.groupe_1 != :old.groupe_1 then
insert into atrace.ref_tables_modif values ('compte_banque','groupe_1',to_char(:old.groupe_1),to_char(:new.groupe_1));
end if;
if :new.groupe_2 != :old.groupe_2 then
insert into atrace.ref_tables_modif values ('compte_banque','groupe_2',to_char(:old.groupe_2),to_char(:new.groupe_2));
end if;
if :new.groupe_3 != :old.groupe_3 then
insert into atrace.ref_tables_modif values ('compte_banque','groupe_3',to_char(:old.groupe_3),to_char(:new.groupe_3));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_5 after update of compte,entite on op.compte_devise for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('compte_devise','compte',to_char(:old.compte),to_char(:new.compte));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_devise','entite',to_char(:old.entite),to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_6 after update of entite,filiale on op.compte_filiale for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_filiale','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('compte_filiale','filiale',to_char(:old.filiale),to_char(:new.filiale));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_7 after update of compte,contrepartie,depositaire,entite,portefeuille 
on op.compte_regle for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('compte_regle','compte',to_char(:old.compte),to_char(:new.compte));
end if;
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('compte_regle','contrepartie',to_char(:old.contrepartie),to_char(:new.contrepartie));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('compte_regle','depositaire',to_char(:old.depositaire),to_char(:new.depositaire));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_regle','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('compte_regle','portefeuille',to_char(:old.portefeuille),to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_8 after update of compte,contrepartie,correspondant,depositaire,entite,portefeuille 
on op.compte_regle_bqe for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','compte',to_char(:old.compte),to_char(:new.compte));
end if;
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','contrepartie',to_char(:old.contrepartie),to_char(:new.contrepartie));
end if;
if :new.correspondant != :old.correspondant then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','correspondant',to_char(:old.correspondant),to_char(:new.correspondant));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','depositaire',to_char(:old.depositaire),to_char(:new.depositaire));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('compte_regle_bqe','portefeuille',to_char(:old.portefeuille),to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_9 after update of contrepartie,depositaire,entite,portefeuille 
on op.compte_regle_liv for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('compte_regle_liv','contrepartie',to_char(:old.contrepartie),to_char(:new.contrepartie));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('compte_regle_liv','depositaire',to_char(:old.depositaire),to_char(:new.depositaire));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_regle_liv','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('compte_regle_liv','portefeuille',to_char(:old.portefeuille),to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_10 after update of depositaire,entite on op.compte_titre for each row
begin
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('compte_titre','depositaire',to_char(:old.depositaire),to_char(:new.depositaire));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('compte_titre','entite',to_char(:old.entite),to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_11 after update of emetteur on op.contrat for each row
begin
if :new.emetteur != :old.emetteur then
insert into atrace.ref_tables_modif values ('contrat','emetteur',to_char(:old.emetteur),to_char(:new.emetteur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_12 after update of entite,federateur on op.contrat_cadre for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('contrat_cadre','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.federateur != :old.federateur then
insert into atrace.ref_tables_modif values ('contrat_cadre','federateur',to_char(:old.federateur),to_char(:new.federateur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_13 after update of entite,federateur on op.contrat_instrument for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('contrat_instrument','entite',to_char(:old.entite),to_char(:new.entite));
end if;
if :new.federateur != :old.federateur then
insert into atrace.ref_tables_modif values ('contrat_instrument','federateur',to_char(:old.federateur),to_char(:new.federateur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_14 after update of counterparty on op.ctpyrating for each row
begin
if :new.counterparty != :old.counterparty then
insert into atrace.ref_tables_modif values ('ctpyrating','counterparty',to_char(:old.counterparty),to_char(:new.counterparty));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_15 after update of portefeuille, portefeuille_pere on op.deposit_fils for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('deposit_fils','portefeuille',to_char(:old.portefeuille),to_char(:new.portefeuille));
end if;
if :new.portefeuille_pere != :old.portefeuille_pere then
insert into atrace.ref_tables_modif values ('deposit_fils','portefeuille_pere',to_char(:old.portefeuille_pere),
to_char(:new.portefeuille_pere));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_16 after update of portefeuille, portefeuille_depo on op.deposit_pere for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('deposit_pere','portefeuille',to_char(:old.portefeuille),to_char(:new.portefeuille));
end if;
if :new.portefeuille_depo != :old.portefeuille_depo then
insert into atrace.ref_tables_modif values ('deposit_pere','portefeuille_depo',to_char(:old.portefeuille_depo),
to_char(:new.portefeuille_depo));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_17 after update of compte_reglement, condition,entite_mere, portefeuille_mere on op.echelle for each row
begin
if :new.compte_reglement != :old.compte_reglement then
insert into atrace.ref_tables_modif values ('echelle','compte_reglement',to_char(:old.compte_reglement),
to_char(:new.compte_reglement));
end if;
if :new.condition != :old.condition then
insert into atrace.ref_tables_modif values ('echelle','condition',to_char(:old.condition), to_char(:new.condition));
end if;
if :new.entite_mere != :old.entite_mere then
insert into atrace.ref_tables_modif values ('echelle','entite_mere',to_char(:old.entite_mere), to_char(:new.entite_mere));
end if;
if :new.portefeuille_mere != :old.portefeuille_mere then
insert into atrace.ref_tables_modif values ('echelle','portefeuille_mere',to_char(:old.portefeuille_mere),
to_char(:new.portefeuille_mere));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_18 after update of compte on op.echelle_compte for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('echelle_compte','compte',to_char(:old.compte), to_char(:new.compte));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_19 after update of compensateur,depositaire,portefeuille on op.fifo_solde_depo for each row
begin
if :new.compensateur != :old.compensateur then
insert into atrace.ref_tables_modif values ('fifo_solde_depo','compensateur',to_char(:old.compensateur), to_char(:new.compensateur));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('fifo_solde_depo','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('fifo_solde_depo','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_20 after update of portefeuille on op.frais_gestion for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('frais_gestion','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_21 after update of portefeuille on op.groupe_detail for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('groupe_detail','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_22 after update of entite on op.groupe_provision for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('groupe_provision','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_23 after update of entite on op.histo_budget for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_budget','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_24 after update of entite,portefeuille,tiers on op.histo_compta for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_compta','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_compta','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_compta','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_25 after update of entite on op.histo_compta_solde for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_compta_solde','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_26 after update of tiers on op.histo_courtage for each row
begin
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_courtage','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_27 after update of tiers_deposit, tiers_reception on op.histo_couverture for each row
begin
if :new.tiers_deposit != :old.tiers_deposit then
insert into atrace.ref_tables_modif values('histo_couverture','tiers_deposit',to_char(:old.tiers_deposit),
to_char(:new.tiers_deposit));
end if;
if :new.tiers_reception != :old.tiers_reception then
insert into atrace.ref_tables_modif values('histo_couverture','tiers_reception',to_char(:old.tiers_reception),
to_char(:new.tiers_reception));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_28 after update of depositaire,portefeuille on op.histo_deposit for each row
begin
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('histo_deposit','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_deposit','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_29 after update of ancien_detenteur,nouveau_detenteur on op.histo_detenteur for each row
begin
if :new.ancien_detenteur != :old.ancien_detenteur then
insert into atrace.ref_tables_modif values ('histo_detenteur','ancien_detenteur',to_char(:old.ancien_detenteur), to_char(:new.ancien_detenteur));
end if;
if :new.nouveau_detenteur != :old.nouveau_detenteur then
insert into atrace.ref_tables_modif values ('histo_detenteur','nouveau_detenteur',to_char(:old.nouveau_detenteur), to_char(:new.nouveau_detenteur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_30 after update of contrepartie,depositaire,entite,entity_corresp1,entity_corresp2
on op.histo_evenement for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('histo_evenement','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('histo_evenement','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_evenement','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.entity_corresp1 != :old.entity_corresp1 then
insert into atrace.ref_tables_modif values ('histo_evenement','entity_corresp1',to_char(:old.entity_corresp1), to_char(:new.entity_corresp1));
end if;
if :new.entity_corresp2 != :old.entity_corresp2 then
insert into atrace.ref_tables_modif values ('histo_evenement','entity_corresp2',to_char(:old.entity_corresp2), to_char(:new.entity_corresp2));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_31 after update of entite,tiers on op.histo_facture for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_facture','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_facture','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_32 after update of compensateur,portefeuille on op.histo_fifo_solde for each row
begin
if :new.compensateur != :old.compensateur then
insert into atrace.ref_tables_modif values ('histo_fifo_solde','compensateur',to_char(:old.compensateur), to_char(:new.compensateur));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_fifo_solde','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_33 after update of entite,foyer on op.histo_fiscalite for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_fiscalite','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.foyer != :old.foyer then
insert into atrace.ref_tables_modif values ('histo_fiscalite','foyer',to_char(:old.foyer), to_char(:new.foyer));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_34 after update of entite,portefeuille,tiers on op.histo_flux for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_flux','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_flux','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_flux','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_35 after update of entite,tiers on op.histo_limite_tr for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_limite_tr','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_limite_tr','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_36 after update of entite on op.histo_liv_solde for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_liv_solde','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_37 after update of entite,portefeuille,tiers on op.histo_livraison for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_livraison','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_livraison','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_livraison','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_38 after update  of entite,portefeuille,tiers on op.histo_matiere for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_matiere','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_matiere','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_matiere','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_39 after update of compensateur on op.histo_mouv_titre_solde for each row
begin
if :new.compensateur != :old.compensateur then
insert into atrace.ref_tables_modif values ('histo_mouv_titre_solde','compensateur',to_char(:old.compensateur), to_char(:new.compensateur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_40 after update of entite on op.histo_mouvement for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_mouvement','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_41 after update on op.histo_operation for each row
begin
if :new.clearing_member != :old.clearing_member then
insert into atrace.ref_tables_modif values ('histo_operation','clearing_member',to_char(:old.clearing_member), to_char(:new.clearing_member));
end if;
if :new.compensateur != :old.compensateur then
insert into atrace.ref_tables_modif values ('histo_operation','compensateur',to_char(:old.compensateur), to_char(:new.compensateur));
end if;
if :new.compte_entite != :old.compte_entite then
insert into atrace.ref_tables_modif values ('histo_operation','compte_entite',to_char(:old.compte_entite), to_char(:new.compte_entite));
end if;
if :new.compte_entite_2 != :old.compte_entite_2 then
insert into atrace.ref_tables_modif values ('histo_operation','compte_entite_2',to_char(:old.compte_entite_2), to_char(:new.compte_entite_2));
end if;
if :new.compte_filiale != :old.compte_filiale then
insert into atrace.ref_tables_modif values ('histo_operation','compte_filiale',to_char(:old.compte_filiale), to_char(:new.compte_filiale));
end if;
if :new.compte_tiers != :old.compte_tiers then
insert into atrace.ref_tables_modif values ('histo_operation','compte_tiers',to_char(:old.compte_tiers), to_char(:new.compte_tiers));
end if;
if :new.compte_tiers_2 != :old.compte_tiers_2 then
insert into atrace.ref_tables_modif values ('histo_operation','compte_tiers_2',to_char(:old.compte_tiers_2), to_char(:new.compte_tiers_2));
end if;
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('histo_operation','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.corresp_receiver1 != :old.corresp_receiver1 then
insert into atrace.ref_tables_modif values ('histo_operation','corresp_receiver1',to_char(:old.corresp_receiver1), to_char(:new.corresp_receiver1));
end if;
if :new.corresp_receiver2 != :old.corresp_receiver2 then
insert into atrace.ref_tables_modif values ('histo_operation','corresp_receiver2',to_char(:old.corresp_receiver2), to_char(:new.corresp_receiver2));
end if;
if :new.corresp_sender1 != :old.corresp_sender1 then
insert into atrace.ref_tables_modif values ('histo_operation','corresp_sender1',to_char(:old.corresp_sender1), to_char(:new.corresp_sender1));
end if;
if :new.corresp_sender2 != :old.corresp_sender2 then
insert into atrace.ref_tables_modif values ('histo_operation','corresp_sender2',to_char(:old.corresp_sender2), to_char(:new.corresp_sender2));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('histo_operation','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.depositaire_2 != :old.depositaire_2 then
insert into atrace.ref_tables_modif values ('histo_operation','depositaire_2',to_char(:old.depositaire_2), to_char(:new.depositaire_2));
end if;
if :new.emetteur != :old.emetteur then
insert into atrace.ref_tables_modif values ('histo_operation','emetteur',to_char(:old.emetteur), to_char(:new.emetteur));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_operation','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('histo_operation','filiale',to_char(:old.filiale), to_char(:new.filiale));
end if;
if :new.intermediaire != :old.intermediaire then
insert into atrace.ref_tables_modif values ('histo_operation','intermediaire',to_char(:old.intermediaire), to_char(:new.intermediaire));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_operation','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.portefeuille_tiers != :old.portefeuille_tiers then
insert into atrace.ref_tables_modif values ('histo_operation','portefeuille_tiers',to_char(:old.portefeuille_tiers), to_char(:new.portefeuille_tiers));
end if;
if :new.portefeuille_deposit != :old.portefeuille_deposit then
insert into atrace.ref_tables_modif values ('histo_operation','portefeuille_deposit',to_char(:old.portefeuille_deposit), to_char(:new.portefeuille_deposit));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_42 after update of filiale on op.histo_parapheur for each row
begin
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('histo_parapheur','filiale',to_char(:old.filiale), to_char(:new.filiale));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_43 after update of filiale on op.histo_parapheur_det for each row
begin
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('histo_parapheur_det','filiale',to_char(:old.filiale), to_char(:new.filiale));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_44 after update of entite on op.histo_position_tr for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_position_tr','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_45 after update of entite,portefeuille,portefeuille_tiers on op.histo_pricing_detail for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_pricing_detail','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_pricing_detail','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.portefeuille_tiers != :old.portefeuille_tiers then
insert into atrace.ref_tables_modif values ('histo_pricing_detail','portefeuille_tiers',to_char(:old.portefeuille_tiers), to_char(:new.portefeuille_tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_46 after update of entite on op.histo_reg_releve for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_reg_releve','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_47 after update on op.histo_reg_solde for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('histo_reg_solde','compte',to_char(:old.compte), to_char(:new.compte));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_reg_solde','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_reg_solde','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_48 after update of compte, cpty_account,corresp_receiver1,corresp_receiver2,corresp_sender1,
corresp_sender2,entite, portefeuille, tiers on op.histo_reglement for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('histo_reglement','compte',to_char(:old.compte), to_char(:new.compte));
end if;
if :new.cpty_account != :old.cpty_account then
insert into atrace.ref_tables_modif values ('histo_reglement','cpty_account',to_char(:old.cpty_account), to_char(:new.cpty_account));
end if;
if :new.corresp_receiver1 != :old.corresp_receiver1 then
insert into atrace.ref_tables_modif values ('histo_reglement','corresp_receiver1',to_char(:old.corresp_receiver1), to_char(:new.corresp_receiver1));
end if;
if :new.corresp_receiver2 != :old.corresp_receiver2 then
insert into atrace.ref_tables_modif values ('histo_reglement','corresp_receiver2',to_char(:old.corresp_receiver2), to_char(:new.corresp_receiver2));
end if;
if :new.corresp_sender1 != :old.corresp_sender1 then
insert into atrace.ref_tables_modif values ('histo_reglement','corresp_sender1',to_char(:old.corresp_sender1), to_char(:new.corresp_sender1));
end if;
if :new.corresp_sender2 != :old.corresp_sender2 then
insert into atrace.ref_tables_modif values ('histo_reglement','corresp_sender2',to_char(:old.corresp_sender2), to_char(:new.corresp_sender2));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('histo_reglement','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_reglement','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('histo_reglement','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_49 after update of compensateur,portefeuille on op.histo_titre_solde for each row
begin
if :new.compensateur != :old.compensateur then
insert into atrace.ref_tables_modif values ('histo_titre_solde','compensateur',to_char(:old.compensateur), to_char(:new.compensateur));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('histo_titre_solde','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_50 after update of contrepartie,entite on op.import_evenement for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('import_evenement','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('import_evenement','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_51 after update of contrepartie on op.marge_compte_de for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('marge_compte_de','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_52 after update of contrepartie,entite on op.marge_regle for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('marge_regle','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('marge_regle','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_53 after update of entite on op.param_arrete for each row 
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('param_arrete','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_54 after update of entite on op.param_bafi_cpt for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('param_bafi_cpt','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_55 after update of por_clone,por_maitre on op.param_clonage for each row
begin
if :new.por_clone != :old.por_clone then
insert into atrace.ref_tables_modif values ('param_clonage','por_clone',to_char(:old.por_clone), to_char(:new.por_clone));
end if;
if :new.por_maitre != :old.por_maitre then
insert into atrace.ref_tables_modif values ('param_clonage','por_maitre',to_char(:old.por_maitre), to_char(:new.por_maitre));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_56 after update of portefeuille on op.param_cpta_reg_gen for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('param_cpta_reg_gen','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_57 after update of banque,entite,portefeuille on op.param_cpta_reg_ven for each row
begin
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('param_cpta_reg_ven','banque',to_char(:old.banque), to_char(:new.banque));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('param_cpta_reg_ven','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('param_cpta_reg_ven','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_58 after update of contrepartie,portefeuille on op.param_date for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('param_date','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('param_date','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_59 after update of assureur on op.param_garanti_taux for each row
begin
if :new.assureur != :old.assureur then
insert into atrace.ref_tables_modif values ('param_garanti_taux','assureur',to_char(:old.assureur), to_char(:new.assureur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_60 after update of entite on op.param_marge_titre for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('param_marge_titre','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_61 after update of portefeuille_fils, portefeuille_pere on op.param_ope_bloc for each row
begin
if :new.portefeuille_fils != :old.portefeuille_fils then
insert into atrace.ref_tables_modif values ('param_ope_bloc','portefeuille_fils',to_char(:old.portefeuille_fils), to_char(:new.portefeuille_fils));
end if;
if :new.portefeuille_pere != :old.portefeuille_pere then
insert into atrace.ref_tables_modif values ('param_ope_bloc','portefeuille_pere',to_char(:old.portefeuille_pere), to_char(:new.portefeuille_pere));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_62 after update of compte on op.decouvert_compte for each row
begin
if :new.compte != :old.compte then
insert into atrace.ref_tables_modif values ('decouvert_compte','compte',to_char(:old.compte),to_char(:new.compte));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_63 after update of filiale on op.param_parapheur_det for each row
begin
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('param_parapheur_det','filiale',to_char(:old.filiale), to_char(:new.filiale));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_64 after update of depositaire on op.param_rappro_stock for each row
begin
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('param_rappro_stock','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_65 after update of filiale on op.param_sign_user for each row
begin
if :new.filiale != :old.filiale then
insert into atrace.ref_tables_modif values ('param_sign_user','filiale',to_char(:old.filiale), to_char(:new.filiale));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_66 after update of entite on op.photo for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('photo','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_67 after update of entite on op.photo_budget for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('photo_budget','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_68 after update of entite on op.photo_flux for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('photo_flux','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_69 after update of entite on op.prevision_param for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('prevision_param','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_70 after update of banque,entite on op.regle_rappro_auto for each row
begin
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('regle_rappro_auto','banque',to_char(:old.banque), to_char(:new.banque));
end if;
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('regle_rappro_auto','entite',to_char(:old.entite), to_char(:new.entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_71 after update of banque on op.reglement_decalage for each row
begin
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('reglement_decalage','banque',to_char(:old.banque), to_char(:new.banque));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_72 after update of entite,tiers on op.reglement_flux for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('reglement_flux','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('reglement_flux','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_73 after update of banque on op.reglement_regle for each row
begin
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('reglement_regle','banque',to_char(:old.banque), to_char(:new.banque));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_74 after update of entity,issuer,portfolio on op.spread_breakdown for each row
begin
if :new.entity != :old.entity then
insert into atrace.ref_tables_modif values ('spread_breakdown','entity',to_char(:old.entity), to_char(:new.entity));
end if;
if :new.issuer != :old.issuer then
insert into atrace.ref_tables_modif values ('spread_breakdown','issuer',to_char(:old.issuer), to_char(:new.issuer));
end if;
if :new.portfolio != :old.portfolio then
insert into atrace.ref_tables_modif values ('spread_breakdown','portfolio',to_char(:old.portfolio), to_char(:new.portfolio));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_75 after update of portefeuille on op.stress_results for each row
begin
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('stress_results','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_76 after update of code,pere on op.structure for each row
begin
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('structure','code',to_char(:old.code), to_char(:new.code));
end if;
if :new.pere != :old.pere then
insert into atrace.ref_tables_modif values ('structure','pere',to_char(:old.pere), to_char(:new.pere));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_77 after update of code,entite_fifo,entite_pere,tiers_conso,tiers_conso2,tiers_conso3,tiers_federateur,description,code_bis,code_abrege,bank_code,iso_country_code,location_code,branch_code,
email_adress,adresse1,adresse2,adresse3,adresse4,adresse5,groupe_1,groupe_2,groupe_3 on op.tiers for each row
begin
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('tiers','code',to_char(:old.code), to_char(:new.code));
end if;
if :new.entite_fifo != :old.entite_fifo then
insert into atrace.ref_tables_modif values ('tiers','entite_fifo',to_char(:old.entite_fifo), to_char(:new.entite_fifo));
end if;
if :new.entite_pere != :old.entite_pere then
insert into atrace.ref_tables_modif values ('tiers','entite_pere',to_char(:old.entite_pere), to_char(:new.entite_pere));
end if;
if :new.tiers_conso != :old.tiers_conso then
insert into atrace.ref_tables_modif values ('tiers','tiers_conso',to_char(:old.tiers_conso), to_char(:new.tiers_conso));
end if;
if :new.tiers_conso2 != :old.tiers_conso2 then
insert into atrace.ref_tables_modif values ('tiers','tiers_conso2',to_char(:old.tiers_conso2), to_char(:new.tiers_conso2));
end if;
if :new.tiers_conso3 != :old.tiers_conso3 then
insert into atrace.ref_tables_modif values ('tiers','tiers_conso3',to_char(:old.tiers_conso3), to_char(:new.tiers_conso3));
end if;
if :new.tiers_federateur != :old.tiers_federateur then
insert into atrace.ref_tables_modif values ('tiers','tiers_federateur',to_char(:old.tiers_federateur), to_char(:new.tiers_federateur));
end if;
if :new.description != :old.description then
insert into atrace.ref_tables_modif values ('tiers','description',to_char(:old.description), to_char(:new.description));
end if;
if :new.code_bis != :old.code_bis then
insert into atrace.ref_tables_modif values ('tiers','code_bis',to_char(:old.code_bis), to_char(:new.code_bis));
end if;
if :new.code_abrege != :old.code_abrege then
insert into atrace.ref_tables_modif values ('tiers','code_abrege',to_char(:old.code_abrege), to_char(:new.code_abrege));
end if;
if :new.bank_code != :old.bank_code then
insert into atrace.ref_tables_modif values ('tiers','bank_code',to_char(:old.bank_code), to_char(:new.bank_code));
end if;
if :new.iso_country_code != :old.iso_country_code then
insert into atrace.ref_tables_modif values ('tiers','iso_country_code',to_char(:old.iso_country_code), to_char(:new.iso_country_code));
end if;
if :new.location_code != :old.location_code then
insert into atrace.ref_tables_modif values ('tiers','location_code',to_char(:old.location_code), to_char(:new.location_code));
end if;
if :new.branch_code != :old.branch_code then
insert into atrace.ref_tables_modif values ('tiers','branch_code',to_char(:old.branch_code), to_char(:new.branch_code));
end if;
if :new.email_adress != :old.email_adress then
insert into atrace.ref_tables_modif values ('tiers','email_adress',to_char(:old.email_adress), to_char(:new.email_adress));
end if;
if :new.groupe_1 != :old.groupe_1 then
insert into atrace.ref_tables_modif values ('tiers','groupe_1',to_char(:old.groupe_1), to_char(:new.groupe_1));
end if;
if :new.groupe_2 != :old.groupe_2 then
insert into atrace.ref_tables_modif values ('tiers','groupe_2',to_char(:old.groupe_2), to_char(:new.groupe_2));
end if;
if :new.groupe_3 != :old.groupe_3 then
insert into atrace.ref_tables_modif values ('tiers','groupe_3',to_char(:old.groupe_3), to_char(:new.groupe_3));
end if;
if :new.adresse1 != :old.adresse1 then
insert into atrace.ref_tables_modif values ('tiers','adresse1',to_char(:old.adresse1), to_char(:new.adresse1));
end if;
if :new.adresse2 != :old.adresse2 then
insert into atrace.ref_tables_modif values ('tiers','adresse2',to_char(:old.adresse2), to_char(:new.adresse2));
end if;
if :new.adresse3 != :old.adresse3 then
insert into atrace.ref_tables_modif values ('tiers','adresse3',to_char(:old.adresse3), to_char(:new.adresse3));
end if;
if :new.adresse4 != :old.adresse4 then
insert into atrace.ref_tables_modif values ('tiers','adresse4',to_char(:old.adresse4), to_char(:new.adresse4));
end if;
if :new.adresse5 != :old.adresse5 then
insert into atrace.ref_tables_modif values ('tiers','adresse5',to_char(:old.adresse5), to_char(:new.adresse5));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_78 after update of tiers on op.tiers_compteur for each row
begin
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('tiers_compteur','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_79 after update of foyer,foyer_appartenance on op.tiers_foyer for each row
begin
if :new.foyer != :old.foyer then
insert into atrace.ref_tables_modif values ('tiers_foyer','foyer',to_char(:old.foyer), to_char(:new.foyer));
end if;
if :new.foyer_appartenance != :old.foyer_appartenance then
insert into atrace.ref_tables_modif values ('tiers_foyer','foyer_appartenance',to_char(:old.foyer_appartenance), to_char(:new.foyer_appartenance));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_80 after update of entite,tiers on op.tiers_limite for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('tiers_limite','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('tiers_limite','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_81 after update of bafi_garant,depositaire,domiciliataire,emetteur on op.titre for each row
begin
if :new.bafi_garant != :old.bafi_garant then
insert into atrace.ref_tables_modif values ('titre','bafi_garant',to_char(:old.bafi_garant), to_char(:new.bafi_garant));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('titre','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.domiciliataire != :old.domiciliataire then
insert into atrace.ref_tables_modif values ('titre','domiciliataire',to_char(:old.domiciliataire), to_char(:new.domiciliataire));
end if;
if :new.emetteur != :old.emetteur then
insert into atrace.ref_tables_modif values ('titre','emetteur',to_char(:old.emetteur), to_char(:new.emetteur));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_82 after update on op.valo_ccy_volat_rule for each row
begin
if :new.entity != :old.entity then
insert into atrace.ref_tables_modif values ('valo_ccy_volat_rule','entity',to_char(:old.entity), to_char(:new.entity));
end if;
if :new.portfolio != :old.portfolio then
insert into atrace.ref_tables_modif values ('valo_ccy_volat_rule','portfolio',to_char(:old.portfolio), to_char(:new.portfolio));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_83 after update on op.valo_regle for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('valo_regle','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('valo_regle','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_84 after update on op.ventiler_contrat_cadre for each row
begin
if :new.entite != :old.entite then
insert into atrace.ref_tables_modif values ('ventiler_contrat_cadre','entite',to_char(:old.entite), to_char(:new.entite));
end if;
if :new.tiers != :old.tiers then
insert into atrace.ref_tables_modif values ('ventiler_contrat_cadre','tiers',to_char(:old.tiers), to_char(:new.tiers));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_85 after update on op.ventiler_corresp for each row
begin
if :new.correspondant_1 != :old.correspondant_1 then
insert into atrace.ref_tables_modif values ('ventiler_corresp','correspondant_1',to_char(:old.correspondant_1), to_char(:new.correspondant_1));
end if;
if :new.correspondant_2 != :old.correspondant_2 then
insert into atrace.ref_tables_modif values ('ventiler_corresp','correspondant_2',to_char(:old.correspondant_2), to_char(:new.correspondant_2));
end if;
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('ventiler_corresp','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('ventiler_corresp','banque',to_char(:old.banque), to_char(:new.banque));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_86 after update on op.ventiler_corresp_bqe for each row
begin
if :new.correspondant_1 != :old.correspondant_1 then
insert into atrace.ref_tables_modif values ('ventiler_corresp_bqe','correspondant_1',to_char(:old.correspondant_1), to_char(:new.correspondant_1));
end if;
if :new.correspondant_2 != :old.correspondant_2 then
insert into atrace.ref_tables_modif values ('ventiler_corresp_bqe','correspondant_2',to_char(:old.correspondant_2), to_char(:new.correspondant_2));
end if;
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('ventiler_corresp_bqe','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.banque != :old.banque then
insert into atrace.ref_tables_modif values ('ventiler_corresp_bqe','banque',to_char(:old.banque), to_char(:new.banque));
end if;
if :new.tiers_entite != :old.tiers_entite then
insert into atrace.ref_tables_modif values ('ventiler_corresp_bqe','tiers_entite',to_char(:old.tiers_entite), to_char(:new.tiers_entite));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_87 after update on op.ventiler_portef for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('ventiler_portef','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('ventiler_portef','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_88 after update on op.ventiler_reg_liv for each row
begin
if :new.contrepartie != :old.contrepartie then
insert into atrace.ref_tables_modif values ('ventiler_reg_liv','contrepartie',to_char(:old.contrepartie), to_char(:new.contrepartie));
end if;
if :new.depositaire != :old.depositaire then
insert into atrace.ref_tables_modif values ('ventiler_reg_liv','depositaire',to_char(:old.depositaire), to_char(:new.depositaire));
end if;
if :new.portefeuille != :old.portefeuille then
insert into atrace.ref_tables_modif values ('ventiler_reg_liv','portefeuille',to_char(:old.portefeuille), to_char(:new.portefeuille));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/
create or replace trigger op.anon_89 after update on op.val_bank_account for each row
begin
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('val_bank_account','code',to_char(:old.code),to_char (:new.code));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_90 after update on op.clearing_member_breakdown for each row
begin
if :new.clearing_member != :old.clearing_member then
insert into atrace.ref_tables_modif values ('clearing_member_breakdown','clearing_member',to_char(:old.clearing_member), to_char(:new.clearing_member));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_91 after update on op.ccp_breakdown for each row
begin
if :new.clearing_member != :old.clearing_member then
insert into atrace.ref_tables_modif values ('ccp_breakdown','clearing_member',to_char(:old.clearing_member), to_char(:new.clearing_member));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_92 after update on op.val_affilied_code for each row
begin
if :new.code_ref != :old.code_ref then
insert into atrace.ref_tables_modif values ('val_affilied_code','code_ref',to_char(:old.code_ref), to_char(:new.code_ref));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_93 after update on op.conditions_echelle for each row
begin
if :new.condition != :old.condition then
insert into atrace.ref_tables_modif values ('condition_echelle','condition',to_char(:old.condition), to_char(:new.condition));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_94 after update on op.echelle_condition for each row
begin
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('echelle_condition','code',to_char(:old.code), to_char(:new.code));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_95 after update on op.echelle_cond_date for each row
begin
if :new.condition != :old.condition then
insert into atrace.ref_tables_modif values ('echelle_cond_date','condition',to_char(:old.condition), to_char(:new.condition));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_96 after update on op.echelle_marge for each row
begin
if :new.condition != :old.condition then
insert into atrace.ref_tables_modif values ('echelle_marge','condition',to_char(:old.condition), to_char(:new.condition));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_97 after update on op.import_operation for each row
begin
if :new.clearing_member != :old.clearing_member then
insert into atrace.ref_tables_modif values ('import_operation','clearing_member',to_char(:old.clearing_member), to_char(:new.clearing_member));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

create or replace trigger op.anon_98 after update on op.val_third_party for each row
begin
if :new.adresse1 != :old.adresse1 then
insert into atrace.ref_tables_modif values ('val_third_party','adresse1',to_char(:old.adresse1), to_char(:new.adresse1));
end if;
if :new.code != :old.code then
insert into atrace.ref_tables_modif values ('val_third_party','code',to_char(:old.code), to_char(:new.code));
end if;
if :new.tiers_conso != :old.tiers_conso then
insert into atrace.ref_tables_modif values ('val_third_party','tiers_conso',to_char(:old.tiers_conso), to_char(:new.tiers_conso));
end if;
EXCEPTION
When dup_val_on_index then null;
end;
/

