# 06 — Glossary

The KTP product was written by a French team. Its Oracle table and column names are French and
**cannot be renamed** — the application depends on them. Everything v4 owns uses English names;
this table bridges the two.

## Core entity vocabulary

| French (schema) | English | Notes |
|---|---|---|
| `tiers` | third party / counterparty | The central table. Confusingly it holds **all four** categories: entities, portfolios *and* counterparties are all rows in `tiers`, distinguished by joining `structure` and by `flag_portefeuille`. |
| `entité` / `entite` | legal entity | A company in the group. `structure='Entite'` + `flag_portefeuille='N'`. |
| `portefeuille` | portfolio | `structure='Entite'` + `flag_portefeuille='O'`. Despite `structure='Entite'`, a portfolio is *not* an entity. |
| `compte` | account | Bare `compte` in a column name almost always means a bank account reference. |
| `compte_banque` | bank account | The bank account master table. |
| `structure` | structure / classification | Classifies each `tiers` row. `structure='Entite'` vs `'Compte'` plus `ecran='w_tiers'` is what separates entities/portfolios from counterparties. |
| `flag_portefeuille` | is-portfolio flag | `'O'` = *oui* = yes, `'N'` = *non* = no. |
| `filiale` | subsidiary | |
| `contrepartie` | counterparty | |
| `correspondant` | correspondent (bank) | |
| `dépositaire` / `depositaire` | custodian | |
| `émetteur` / `emetteur` | issuer | |
| `banque` | bank | |
| `agence` | branch | |

## Common column words

| French | English |
|---|---|
| `code` | code / identifier |
| `description` | description |
| `libellé` / `libelle` | label / caption |
| `adresse1`–`adresse5` | address lines 1–5 |
| `téléphone` / `telephone` | phone |
| `télex` / `telex` | telex |
| `email_adress` | email address (sic — the vendor's spelling) |
| `nom_pp` | surname (*nom*), natural person |
| `prenom_pp` | given name (*prénom*), natural person |
| `flag_pp` | natural-person flag (*personne physique*) |
| `dpt_naissance` | department of birth (French administrative division) |
| `groupe_1/2/3` | free-text grouping fields 1–3 |
| `valeur_1`…`valeur_4` | value 1–4 |
| `père` / `pere` | parent (as in parent record) |
| `fils` | child |
| `mère` / `mere` | mother / parent |
| `devise` | currency |
| `montant` | amount |
| `règle` / `regle` | rule |
| `règlement` / `reglement` | settlement |
| `livraison` | delivery |
| `mouvement` | movement |
| `opération` / `operation` | transaction / deal |
| `flux` | flow |
| `prévision` / `prevision` | forecast |
| `solde` | balance |
| `courtage` | brokerage |
| `couverture` | hedge / cover |
| `matière` / `matiere` | commodity |
| `facture` | invoice |
| `fiscalité` / `fiscalite` | taxation |
| `foyer` | tax household |
| `parapheur` | signature folder (approval queue) |
| `échelle` / `echelle` | scale (fee/interest tier) |
| `marge` | margin |
| `ventiler` | to break down / allocate |
| `rappro` (`rapprochement`) | reconciliation |
| `décalage` / `decalage` | offset / lag |
| `découvert` / `decouvert` | overdraft |
| `titre` | security (financial instrument) |
| `compensateur` | clearer / clearing agent |
| `arrêté` / `arrete` | period close |
| `clonage` | cloning |
| `utilisateur` | user |
| `histo_*` | history table prefix (*historique*) |
| `param_*` | parameter/configuration table prefix |
| `val_*` | validation / reference table prefix |
| `imp_*`, `import_*` | inbound staging table prefix |

## Product and module abbreviations

| Abbreviation | Meaning |
|---|---|
| **KTP** | Kyriba Treasury Platform — the product family this database belongs to |
| **OP** | The core treasury schema (Oracle user `OP`) |
| **EPF** | Electronic Payment Factory — the payments module (Oracle user `OPPAYMENTS`) |
| **CTI** | Cash & Treasury Intelligence — the module owning the `cm_*`, `dm_*`, `tp_*`, `uaa_*` tables |
| `cm_*` | Cash Management tables |
| `dm_*` | Deal Management / hedging tables |
| `tp_*` | Third Party / contact management tables |
| `uaa_*` | User Authentication & Authorization tables |
| `zba_*` | Zero Balance Account tables |
| `ssi` | Standard Settlement Instructions |
| `bkd` | breakdown |
| `bkstmt` | bank statement |
| `ctrp` / `cpty` / `ctpy` | counterparty (all three spellings occur; they are **not** interchangeable as identifiers — `val_cptyrating` and `ctpyrating` are different tables) |
| `ptf` | portfolio |
| `bic` | Bank Identifier Code (SWIFT) |
| `bban` | Basic Bank Account Number |
| `rib` | *Relevé d'Identité Bancaire* — French bank account identifier |

## A trap worth knowing

`tiers` is both a **category name** ("counterparty") and a **table name** (the table holding all
four categories). When v3 said `TIERS` it meant the counterparty category; when it said the `tiers`
table it meant everything. v4 uses `COUNTERPARTY` for the category to remove the ambiguity, and only
ever writes `tiers` when it means the actual table.
