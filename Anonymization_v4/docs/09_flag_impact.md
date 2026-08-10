# 09 — Flag impact: what each flag covers and skips

Answers the question "if I turn a flag off, which columns stop being anonymized?"

The short version: **the flags filter by VALUE, not by column** — with one important exception where
the effect *is* per-column and completely predictable.

> Static part (below) is derived from the inventory CSVs and needs no database.
> The 390 unresolved columns need one run of `tools/analyze_flag_impact.sql` — see the end.

---

## The mental model to correct

Disabling a category does not remove columns from the run. Every column is still visited and its
`UPDATE` still executes. What changes is **what is in the mapping** — and a value that is not in the
mapping is left alone.

```
ANONYMIZE_COUNTERPARTY=n
   └─ no COUNTERPARTY rows generated in anon_meta.code_map
        └─ the UPDATE on histo_flux.tiers still runs
             └─ rows holding a counterparty code: no match, left as-is
             └─ rows holding an entity code:      still replaced
```

So one column can be *partly* anonymized. That is why a flat covered/skipped list cannot be produced
from the inventory alone — for most columns the answer depends on what values the column actually
contains on your instance.

**The exception:** a column declared `BANK_ACCOUNT` only ever looks at bank-account codes. For those,
the flag genuinely is an on/off switch for the whole column, and the answer *is* knowable in advance.

---

## Summary: what governs each of the 579 rows

| Rows | Rule + category | Governed by | Predictable from the CSV alone? |
|---:|---|---|---|
|  72 | `CODE` + `BANK_ACCOUNT` | `ANONYMIZE_BANK_ACCOUNT` | **Yes — off means the column is 100% untouched** |
| 390 | `CODE` + `ANY` | all four category flags, per value | No — depends on instance data |
|  92 | `NULL_OUT` | nothing | **Yes — always erased, no flag applies** |
|   3 | `DESCRIPTION` | `ANONYMIZE_*_DESCRIPTION` | Yes |
|   5 | `SELF_CODE` + `ANY` | any `ANONYMIZE_*_ATTRIBUTES` | Yes |
|  17 | `SELF_CODE` + category | that category's `_ATTRIBUTES` | Yes |

**189 of 579 rows (33%) are fully predictable right now.** The other 390 need one analysis run.

---

## 1. Always anonymized — no flag can stop it (92 columns)

Every `NULL_OUT` column. Free text, names, emails, phone numbers, IBAN and RIB fragments. No setting
in `anonymization.ini` affects these. Full list: `inventory_op.csv`, section 8.

This is deliberate — free text is the highest-risk content and the least useful to preserve. If that
should be configurable, it is [open question 3](08_open_questions.md).

---

## 2. Fully skipped when `ANONYMIZE_BANK_ACCOUNT=n` (72 columns)

These reference `compte_banque.code` and the engine restricts their lookup to bank-account codes
only. With the flag off, the mapping holds none, so **nothing in these columns changes at all**.

Across 54 tables:

| Table | Column |
|---|---|
| `charge_contract_criteria` | `account` |
| `charge_contract_process` | `account` |
| `charge_missing_process` | `account` |
| `cm_account_of_bkstmt_file` | `account` |
| `cm_bsi_bank_statement` | `bank_account` |
| `cm_cash_concent_accounts` | `account` |
| `cm_cash_concent_header` | `compte_entite` |
| `cm_cash_concent_header` | `compte_filiale` |
| `cm_cash_concent_header` | `compte_tiers` |
| `cm_cash_concent_header` | `master_account` |
| `cm_deal_deal` | `compte_entite` |
| `cm_deal_deal` | `compte_filiale` |
| `cm_deal_deal` | `compte_tiers_2` |
| `cm_deal_deal` | `compte_tiers` |
| `cm_fli_flow` | `account` |
| `cm_payt_payment` | `cpty_account_code` |
| `compte_banque` | `code_bban` |
| `compte_banque` | `code` |
| `compte_banque` | `compte_previs_glob` |
| `compte_devise` | `compte` |
| `compte_filiale` | `compte` |
| `compte_regle_bqe` | `compte` |
| `compte_regle_liv` | `compte` |
| `compte_regle` | `compte` |
| `contrat_cadre` | `compte_echelle` |
| `decouvert_compte` | `compte` |
| `dm_hr_quotation` | `account` |
| `echelle_compte` | `compte` |
| `echelle` | `compte_reglement` |
| `histo_effet` | `compte_effet` |
| `histo_effet` | `compte` |
| `histo_fiscalite` | `compte_fiscal` |
| `histo_ligne` | `compte` |
| `histo_mouv_solde` | `compte` |
| `histo_prevision` | `compte` |
| `histo_reg_conso` | `compte` |
| `histo_reg_releve` | `compte` |
| `histo_reg_solde` | `compte` |
| `import_evenement` | `cpty_account` |
| `import_evenement` | `entity_account` |
| `import_operation` | `compte_entite` |
| `import_operation` | `compte_filiale` |
| `import_operation` | `compte_tiers_2` |
| `import_operation` | `compte_tiers` |
| `mpm_file_bkd` | `account` |
| `param_cpta_reg_gen` | `compte_ana` |
| `param_cpta_reg_ven` | `compte` |
| `param_effet_paye` | `compte` |
| `param_effet_recu` | `compte` |
| `param_net_reg` | `compte_comp` |
| `param_net_reg` | `compte_pivot` |
| `prevision_param` | `compte` |
| `regle_rappro_auto` | `compte` |
| `reglement_decalage` | `compte` |
| `reglement_flux` | `compte` |
| `reglement_regle` | `compte` |
| `tp_comm_entity_dim` | `account` |
| `tp_contact` | `bank_account` |
| `tp_data_profile_ptf` | `account` |
| `tp_pos_snapshot_results` | `account` |
| `tp_pos_snapshot` | `account` |
| `val_bank_account` | `code` |
| `val_currency_account` | `compte` |
| `val_ssi_account` | `compte` |
| `virement_compte` | `compte` |
| `zba_breakdown` | `centralizer_account` |
| `zba_payment_breakdown` | `centralizer_account` |
| `zba_payment_breakdown` | `current_account` |
| `zba_payment_breakdown` | `mirrored_current_account` |
| `zba_transfer_breakdown` | `centralizer_account` |
| `zba_transfer_breakdown` | `counterparty_account` |
| `zba_transfer_breakdown` | `entity_account` |

> Turning this flag off leaves every real bank account identifier in the database, in all 72 places.

---

## 3. Partly affected — depends on your data (390 columns)

Declared `CODE` + `ANY`: the column may hold an entity, portfolio or counterparty code, and often
holds a mix. Which flags matter depends on which categories actually appear in it.

The tables carrying the most of these:

| Table | `ANY` columns |
|---|---|
| `cm_deal_deal` | 32 |
| `histo_operation` | 23 |
| `import_operation` | 20 |
| `cm_cash_concent_header` | 18 |
| `histo_reglement` | 9 |
| `cm_forecast` | 9 |
| `tiers` | 7 |
| `import_evenement` | 6 |
| `ventiler_corresp_bqe` | 5 |
| `val_ssi_corresp` | 5 |
| `histo_evenement` | 5 |
| `compte_regle_bqe` | 5 |

For a column like `histo_operation.contrepartie` the name suggests counterparties only — but the
inventory does not assert that, and v3's behaviour was to substitute any category's code found
there. Guessing from the name is exactly the mistake that made v3's per-column gating wrong.

`tools/analyze_flag_impact.sql` answers this empirically, per column, against your instance.

---

## 4. Labels and attributes (25 columns)

Fully predictable. Each is switched off by exactly one flag, or by the category flag above it.

| Column | Rule | Turned off by |
|---|---|---|
| `structure.description` | `DESCRIPTION` | `any *_DESCRIPTION being off` |
| `tiers.description` | `DESCRIPTION` | `any *_DESCRIPTION being off` |
| `compte_banque.description` | `DESCRIPTION` | `ANONYMIZE_BANK_ACCOUNT_DESCRIPTION` |
| `tiers.adresse1` | `SELF_CODE` | `all *_ATTRIBUTES being off` |
| `tiers.adresse2` | `SELF_CODE` | `all *_ATTRIBUTES being off` |
| `tiers.adresse3` | `SELF_CODE` | `all *_ATTRIBUTES being off` |
| `tiers.adresse4` | `SELF_CODE` | `all *_ATTRIBUTES being off` |
| `tiers.adresse5` | `SELF_CODE` | `all *_ATTRIBUTES being off` |
| `tiers.telephone` | `SELF_CODE` | `ANONYMIZE_ENTITY_ATTRIBUTES` |
| `tiers.fax` | `SELF_CODE` | `ANONYMIZE_ENTITY_ATTRIBUTES` |
| `tiers.email_adress` | `SELF_CODE` | `ANONYMIZE_ENTITY_ATTRIBUTES` |
| `tiers.nom_pp` | `SELF_CODE` | `ANONYMIZE_ENTITY_ATTRIBUTES` |
| `tiers.prenom_pp` | `SELF_CODE` | `ANONYMIZE_ENTITY_ATTRIBUTES` |
| `tiers.groupe_1` | `SELF_CODE` | `ANONYMIZE_PORTFOLIO_ATTRIBUTES` |
| `tiers.groupe_2` | `SELF_CODE` | `ANONYMIZE_PORTFOLIO_ATTRIBUTES` |
| `tiers.groupe_3` | `SELF_CODE` | `ANONYMIZE_PORTFOLIO_ATTRIBUTES` |
| `tiers.flag_pp` | `SELF_CODE` | `ANONYMIZE_PORTFOLIO_ATTRIBUTES` |
| `tiers.dpt_naissance` | `SELF_CODE` | `ANONYMIZE_PORTFOLIO_ATTRIBUTES` |
| `tiers.sector` | `SELF_CODE` | `ANONYMIZE_COUNTERPARTY_ATTRIBUTES` |
| `tiers.seniority` | `SELF_CODE` | `ANONYMIZE_COUNTERPARTY_ATTRIBUTES` |
| `tiers.telex` | `SELF_CODE` | `ANONYMIZE_COUNTERPARTY_ATTRIBUTES` |
| `tiers.type_interne` | `SELF_CODE` | `ANONYMIZE_COUNTERPARTY_ATTRIBUTES` |
| `compte_banque.groupe_1` | `SELF_CODE` | `ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES` |
| `compte_banque.groupe_2` | `SELF_CODE` | `ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES` |
| `compte_banque.groupe_3` | `SELF_CODE` | `ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES` |

Each is also skipped if its category flag is off, since both rules write that category's anonymized
code and there would be none to write.

---

## Resolving the remaining 390

```batch
cd Anonymization_v4
sqlplus op/<password>@<TNS> @tools\analyze_flag_impact.sql
```

It builds the four source populations **regardless of your current flags**, then counts — for every
`CODE` column — how many rows hold a value of each category. Output is written to
`docs/09_flag_impact_measured.md` and to `anon_meta.flag_impact`.

That turns every row of section 3 into a definite statement, for example:

```
histo_operation.contrepartie   1,204,331 rows
    ENTITY          12,004   1%    kept if ANONYMIZE_ENTITY=n
    COUNTERPARTY 1,192,327  99%    kept if ANONYMIZE_COUNTERPARTY=n
    unmapped             0   0%
```

Read `unmapped` carefully: those values are in no source population, so **no flag setting will ever
anonymize them**. A large `unmapped` count is worth investigating — either the values are legitimate
system codes, or the column references a population the inventory does not cover.

It is read-only and safe to run at any time, including before the first anonymization.

**Cost:** one pass per table, roughly the length of a dry run. Add `SAMPLE` mode for a fast estimate
on very large instances — see the header of the script.
