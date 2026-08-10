# KTP/CTI Anonymization Scope Reference

This document lists tables/columns that require anonymization for **KTP/CTI applications** that use OP.
This is in addition to the core OP anonymization scope.

**Verified on:** 2026-07-07 against multiple KTP/CTI OP databases (Oracle 19c)

**STRICT RULE:** Table and column names are treated as EXACT. `val_cptyrating` ≠ `ctpyrating`.

---

## Reference: 12 Tables from KTP/CTI Analysis

| # | TABLE NAME | COLUMN NAME | TYPE |
|---|----------------------------|-----------------|--------|
| 1 | charge_contract_criteria | entity | E |
| 1 | charge_contract_criteria | bank | E,P,C |
| 1 | charge_contract_criteria | account | BA |
| 2 | charge_contract_process | entity | E |
| 2 | charge_contract_process | bank | E,P,C |
| 2 | charge_contract_process | account | BA |
| 3 | charge_missing_process | entity | E |
| 3 | charge_missing_process | bank | E,P,C |
| 3 | charge_missing_process | account | BA |
| 4 | mpm_file_bkd | entity | E |
| 4 | mpm_file_bkd | counterparty | E,P,C |
| 4 | mpm_file_bkd | account | BA |
| 5 | trade_repository_breakdown | entity | E |
| 6 | val_cptyrating | counterparty | E,P,C |
| 7 | val_currency_account | entity | E |
| 7 | val_currency_account | compte | BA |
| 8 | val_security_account | entite | E |
| 8 | val_security_account | depositaire | E,P,C |
| 8 | val_security_account | numero_compte | * |
| 8 | val_security_account | groupe_1 | * |
| 8 | val_security_account | groupe_2 | * |
| 8 | val_security_account | groupe_3 | * |
| 8 | val_security_account | correspondant | E,P,C |
| 8 | val_security_account | contrepartie | E,P,C |
| 9 | val_ssi_account | portefeuille | P |
| 9 | val_ssi_account | depositaire | BA |
| 9 | val_ssi_account | compte | BA |
| 9 | val_ssi_account | tiers_entite | E,P,C |
|10 | val_ssi_corresp | banque | E,P,C |
|10 | val_ssi_corresp | contrepartie | E,P,C |
|10 | val_ssi_corresp | correspondant_1 | E,P,C |
|10 | val_ssi_corresp | correspondant_2 | E,P,C |
|10 | val_ssi_corresp | tiers_entite | E,P,C |
|11 | val_third_party_limit | entite | E,P,C |
|11 | val_third_party_limit | tiers | E,P,C |
|12 | val_user | description | * |

---

## Multi-Instance Verification Results

| TABLE NAME | Instance 1 | Instance 2 | Notes |
|-----------------------------|------------|------------|-------|
| charge_contract_criteria | ✅ YES | ✅ YES | Core - all instances |
| charge_contract_process | ✅ YES | ✅ YES | Core - all instances |
| charge_missing_process | ✅ YES | ✅ YES | Core - all instances |
| mpm_file_bkd | ✅ YES | ✅ YES | Core - all instances |
| trade_repository_breakdown | ✅ YES | ✅ YES | Core - all instances |
| **val_cptyrating** | ❌ NO | ❌ NO | May not exist - script skips |
| val_currency_account | ✅ YES | ✅ YES | Core - all instances |
| val_security_account | ✅ YES | ✅ YES | Core - all instances |
| val_ssi_account | ✅ YES | ❌ NO | Instance-specific |
| val_ssi_corresp | ✅ YES | ❌ NO | Instance-specific |
| val_third_party_limit | ✅ YES | ✅ YES | Core - all instances |
| val_user | ✅ YES | ✅ YES | Core - all instances |

### Column Existence Issues

| TABLE.COLUMN | Status |
|-------------------------------------|--------|
| val_currency_account.entity | ❌ Column doesn't exist (only compte exists) |
| val_security_account.correspondant | ❌ Column doesn't exist |
| val_security_account.contrepartie | ❌ Column doesn't exist |

---

## Implementation Approach

### Script: `07_ktp_cti_anonym.sql`

**All 12 tables and all columns from the reference are included.**

### User Selection Behavior

Columns are conditionally anonymized based on config.ini settings:

| Type | Config Flag | Behavior |
|------|-------------|----------|
| **E** (Entity only) | `EntC=y/n` | Only if EntC=y |
| **P** (Portfolio only) | `FoldC=y/n` | Only if FoldC=y |
| **C** (Counterparty only) | `TierC=y/n` | Only if TierC=y |
| **BA** (Bank Account only) | `CpteC=y/n` | Only if CpteC=y |
| **E,P,C** (Mixed) | Any of above | If ANY of EntC/FoldC/TierC=y |
| **\*** (Free-text) | N/A | ALWAYS anonymized (NULLed) |

### Error Handling

Missing tables/columns are handled gracefully:
- `ORA-00942` (table doesn't exist) → SKIPPED
- `ORA-00904` (column doesn't exist) → SKIPPED

This ensures:
1. Same script works on ALL KTP/CTI instances
2. No manual editing required per-instance
3. All items from reference are covered if they exist
4. User selections from config.ini are respected

### Integration Point

Called from `start_anonymous_v3.sql` after Phase 3:
```sql
@sql\07_ktp_cti_anonym.sql &EntC &FoldC &TierC &CpteC
@sql\08_cti_anonym.sql &EntC &FoldC &TierC &CpteC
@sql\09_inclusions_anonym.sql &EntC &FoldC &TierC &CpteC -- Custom inclusions (future extensions)
```

---

## TYPE Legend
- **E** = Entity only (anonymized with prefix `E_`) - requires EntC=y
- **P** = Portfolio only (anonymized with prefix `P_`) - requires FoldC=y
- **C** = Counterparty/Tiers only (anonymized with prefix `T_`) - requires TierC=y
- **BA** = Bank Account / Compte only (anonymized with prefix `CB_`) - requires CpteC=y
- **E,P,C** = Can contain Entity, Portfolio, or Counterparty codes - requires any of EntC/FoldC/TierC=y
- **\*** = Free-text or other sensitive field - ALWAYS NULLed regardless of flags

---

## CTI Tables Reference (38 tables)

Added: 2026-07-08

### CM Tables (Cash Management) - 17 tables

| TABLE NAME | COLUMN NAME | TYPE |
|--------------------------|-----------------------|--------|
| cm_account_of_bkstmt_file | entity | E |
| cm_account_of_bkstmt_file | account | BA |
| cm_account_of_bkstmt_file | bank | E,P,C |
| cm_archived_forecast | entity | E |
| cm_archived_forecast | bank | C |
| cm_bkstmt_file_config | collator | E,P,C |
| cm_bkstmt_file_config | bank | E,P,C |
| cm_bsi_bank_statement | entity | E |
| cm_bsi_bank_statement | bank_account | BA |
| cm_cash_concent_accounts | entity | E |
| cm_cash_concent_accounts | account | BA |
| cm_cash_concent_accounts | bank | E,P,C |
| cm_cash_concent_header | master_account | BA |
| cm_cash_concent_header | entity | E |
| cm_cash_concent_header | contrepartie | E,P,C |
| cm_cash_concent_header | description | * |
| cm_cash_concent_header | compte_tiers | BA |
| cm_cash_concent_header | compte_entite | BA |
| cm_cash_concent_header | filiale | C |
| cm_cash_concent_header | compte_filiale | BA |
| cm_cash_concent_header | intermediaire | C |
| cm_cash_concent_header | portefeuille | P |
| cm_cash_concent_header | correspondant_1-5 | E,P,C |
| cm_cash_concent_header | portefeuille_tiers | E,P,C |
| cm_cash_concent_header | groupe_1/2/3 | * |
| cm_cash_concent_header | depositaire/2 | E,P,C |
| cm_cash_concent_header | emetteur | E,P,C |
| cm_cash_concent_header | correspondant_sender1/2 | E,P,C |
| cm_cash_concent_header | correspondant_receiver1/2 | E,P,C |
| cm_deal_deal | (see 08_cti_anonym.sql - 40+ columns) | mixed |
| cm_fli_flow | entity | E |
| cm_fli_flow | counterparty | E,P,C |
| cm_fli_flow | portfolio | P |
| cm_fli_flow | group1/2/3 | * |
| cm_fli_flow | account | BA |
| cm_flow_to_pay_rules | entity | E |
| cm_flow_to_pay_rules | bank | E,P,C |
| cm_foi_forecast | entity | E |
| cm_foi_forecast | bank | E,P,C |
| cm_forecast | entity | E |
| cm_forecast | bank | E,P,C |
| cm_forecast | branch | E,P,C |
| cm_forecast | subsidiary_cpty | E,P,C |
| cm_forecast | group1/2/3 | * |
| cm_forecast | portfolio | P |
| cm_forecast | corresp_receiver1/2 | E,P,C |
| cm_forecast | corresp_sender1/2 | E,P,C |
| cm_payt_payment | portfolio | P |
| cm_payt_payment | corresp_receiver1/2 | E,P,C |
| cm_payt_payment | corresp_sender1/2 | E,P,C |
| cm_payt_payment | iban_key, bban_code | * |
| cm_payt_payment | cpty_account_code | BA |
| cm_payt_payment | free_tiers_1/2/3 | * |
| cm_payt_payment | groupe_1/2/3 | * |
| cm_pooling_convention | entity | E |
| cm_pooling_convention | counterparty | E,P,C |
| cm_pooling_convention | value_1/2 | * |
| cm_pooling_method | groupe_1/2/3 | * |
| cm_process | entity | E |
| cms_file_bkd | entity | E |
| cms_file_bkd | counterparty | E,P,C |
| cm_cms_exceptions | entity | E |
| cm_cms_exceptions | counterparty | E,P,C |
| cm_cms_exceptions | portfolio | P |
| cm_cms_exceptions | issuer | E,P,C |

### DM Tables (Deal Management / Hedging) - 7 tables

| TABLE NAME | COLUMN NAME | TYPE |
|---------------------|------------------|--------|
| dm_hedge_request | entity | E |
| dm_hedge_request | counterparty | E,P,C |
| dm_hedge_request | portfolio | P |
| dm_hr_autovalid_bkd | entity | E |
| dm_hr_ctrp_map | counterparty | E,P,C |
| dm_hr_cutoff_bkd | entity | E |
| dm_hr_cutoff_bkd | counterparty | E,P,C |
| dm_hr_cutoff_bkd | portfolio | P |
| dm_hr_limit_bkd | entity | E |
| dm_hr_limit_bkd | portfolio | P |
| dm_hr_ptf_bkd | issuer | E,P,C |
| dm_hr_ptf_bkd | cts_counterparty | E,P,C |
| dm_hr_quotation | entity | E |
| dm_hr_quotation | account | BA |
| dm_hr_quotation | bank | E,P,C |
| dm_hr_quotation | phone | * |

### TP Tables (Third Party / Contact Management) - 13 tables

| TABLE NAME | COLUMN NAME | TYPE |
|----------------------------|----------------|--------|
| tp_business_profile | description | * |
| tp_comm_entity_dim | entity | E |
| tp_comm_entity_dim | account | BA |
| tp_comm_entity_dim | bank | E,P,C |
| tp_comm_entity_dim | phone, mobile, name, email | * |
| tp_contact | entity | E |
| tp_contact | bank_account | BA |
| tp_data_profile_bankaccount | counterparty | E,P,C |
| tp_data_profile_ctrp | entity | E |
| tp_data_profile_entity | portfolio | E |
| tp_data_profile_ptf | account | BA |
| tp_data_profile_ptf | bank | E,P,C |
| tp_pos_snapshot | entity | E |
| tp_pos_snapshot | account | BA |
| tp_pos_snapshot_results | entity | E |
| tp_pos_snapshot_results | account | BA |
| tp_pos_snapshot_results | description, firstname, lastname, email, phone_number | * |
| tp_tenant_entity | entity | E |
| tp_users | entity | E |
| tp_users | counterparty | E,P,C |
| tp_wv_mailing_rule | entity | E |
| tp_wv_mailing_rule | counterparty | E,P,C |
| tp_wv_mailing_rule | description, firstname, lastname, email, phone_number | * |
| tp_wv_transition_rule | entity | E |
| tp_wv_transition_rule | counterparty | E,P,C |

### UAA Tables (User Authentication) - 1 table

| TABLE NAME | COLUMN NAME | TYPE |
|------------|----------------------------------------------------|------|
| uaa_users | description, firstname, lastname, email, phone_number | * |

---

## Custom Inclusions (Future Extensions)

Added: 2026-08-07

### Purpose

The **Custom Inclusions** feature allows adding future tables/columns to anonymization **WITHOUT modifying any SQL scripts**. This enables:

1. Support for new KTP/CTI versions with additional tables
2. Customer-specific tables/columns that need anonymization
3. Quick additions without developer intervention

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Edit inclusions.csv │
│ - Add table/column/type entries │
│ - Lines starting with # are comments │
├─────────────────────────────────────────────────────────────────┤
│ 2. Run start_anonymous.bat │
│ - Batch parses inclusions.csv │
│ - Generates SQL INSERT statements │
│ - Loads into atrace.anon_inclusions table │
├─────────────────────────────────────────────────────────────────┤
│ 3. Phase 3D: 09_inclusions_anonym.sql │
│ - Reads from atrace.anon_inclusions │
│ - Processes each entry based on TYPE and config flags │
│ - Missing tables/columns are SKIPPED (no error) │
└─────────────────────────────────────────────────────────────────┘
```

### File: `inclusions.csv`

Location: `Anonymization_OP/inclusions.csv`

Format:
```csv
TABLE_NAME,COLUMN_NAME,TYPE,NOTES
# Lines starting with # are comments
new_table,entity_col,E,Entity reference - added for v3.0
new_table,account_num,BA,Bank account reference
new_table,description,*,Free text - always NULLed
```
### Type Values

| Type | Meaning | Config Flag | Anonymization Method |
|------|---------|-------------|----------------------|
| `E` | Entity only | EntC=y | op.merge_codes (prefix E_) |
| `P` | Portfolio only | FoldC=y | op.merge_codes (prefix P_) |
| `C` | Counterparty only | TierC=y | op.merge_codes (prefix T_) |
| `BA` | Bank Account | CpteC=y | op.merge_codes with COMPTE (prefix CB_) |
| `EPC` | Mixed E/P/C | ANY of above | op.merge_codes |
| `*` | Free-text | N/A (always) | SET column = NULL |

### Script: `09_inclusions_anonym.sql`

- Called after Phase 3C (CTI tables)
- Processes entries from `atrace.anon_inclusions` table
- Respects config.ini flags (EntC, FoldC, TierC, CpteC)
- Missing tables/columns are gracefully SKIPPED

### Example Usage

To add a new table `ktp_new_module` with three columns:

1. Edit `inclusions.csv`:
```csv
ktp_new_module,entity_ref,E,Entity reference field
ktp_new_module,cpty_code,EPC,Could be Entity/Portfolio/Counterparty
ktp_new_module,notes,*,Free text notes - PII
```

2. Run `start_anonymous.bat` as normal
3. Phase 3D will process these entries automatically

### Error Handling

- **Table doesn't exist**: SKIPPED (ORA-00942)
- **Column doesn't exist**: SKIPPED (ORA-00904)
- **Unknown TYPE**: WARNING + SKIP
- **Empty file**: INFO message, continues normally