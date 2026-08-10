# KTP Payment Factory - Data Anonymization (KTP680)

## Overview

Production-ready anonymization package for the KTP Payment Factory databases:
- **OP** schema: Core treasury operations (entities, portfolios, counterparties, bank accounts)
- **EPF** (OPPAYMENTS) schema: Payment factory data (payments, bulk payments, users, audit trail)

## Directory Structure

```
ktp-op-oppayments-data-anonymization/
├── run_full_anonymization.bat ← Top-level orchestrator (OP + EPF, supports /dryrun)
├── docs/
│ └── README.md ← This file
│
├── Anonymization_OP/ ← OP Schema
│ ├── start_anonymous.bat ← Interactive OP launcher (supports /dryrun, config.ini)
│ ├── config.ini ← Non-interactive configuration
│ ├── config_template.ini ← Template for config.ini
│ ├── logs/ ← Runtime logs (anonyme_op.log)
│ └── sql/
│ ├── start_anonymous_v3.sql ← OP SQL orchestrator (set-based)
│ ├── 01_manage_tblspace.sql ← Create atrace schema + mapping tables
│ ├── 02pack_anonym_number.sql ← Trigger management procedure
│ ├── 03anon_triggers.sql ← Cascade triggers
│ ├── 04drop_anon_triggers.sql ← Legacy trigger cleanup
│ ├── 05_op_performance_boost.sql ← Phase 1: Pre-clear histo tables
│ ├── 06_op_setbased_anonym.sql ← Phase 3: Set-based code rename
│ ├── 07_ktp_cti_anonym.sql ← Phase 3B: KTP tables
│ ├── 08_cti_anonym.sql ← Phase 3C: CTI tables
│ └── verify_anon_coverage_final.sql ← Post-run OP verification
│
└── Anonymization_EPF/ ← EPF Schema (OPPAYMENTS)
 ├── start_epf_anonymization.bat ← EPF launcher (supports /dryrun)
 ├── monitor_epf_anon.ps1 ← PowerShell progress monitor
 ├── logs/ ← Runtime logs (anonyme_epf.log)
 └── sql/
 ├── start_anonymous_epf.sql ← Main EPF orchestrator (Phases A-H)
 ├── anonymize_epf_itr1.sql ← Phase B: Code cascade from OP
 ├── anonymize_epf_itr2.sql ← Phase D: Independent (20 steps)
 ├── anonymize_epf_phase7_refdata.sql ← Phase E: REF_TIERS/REF_BANK_BRANCHE
 ├── anonymize_epf_phase8_swift_audit.sql ← Phase F: SWIFT messages + audit IPs
 ├── anonymize_epf_phase9_op_bic_bban.sql ← Phase G: OP BIC/BBAN gap fix
 ├── verify_epf_anon_coverage_final.sql ← Comprehensive EPF verification
 ├── monitor_epf_progress.sql ← Progress monitoring queries
 ├── monitor_op_progress.sql ← OP progress monitoring queries
 └── bic/ ← BIC/SWIFT component scripts
 ├── 1_Anonymize_Bank_Codes.sql
 ├── 2_Anonymize_Country_Codes.sql
 ├── 3_Anonymize_Location_Codes.sql
 ├── 4_Anonymize_Branch_Codes.sql
 └── 5_Anonymize_payment_amounts.sql
```

## Execution Modes

### Dry Run (Validation Only)

All scripts support a `/dryrun` flag that validates configuration and shows row counts **without making any database changes**:

```batch
REM Full orchestrator dry run
run_full_anonymization.bat /dryrun

REM OP only dry run
cd Anonymization_OP
start_anonymous.bat /dryrun

REM EPF only dry run 
cd Anonymization_EPF
start_epf_anonymization.bat /dryrun
```

Dry run output includes:
- Configuration summary (all selected options)
- SQL files that would be executed
- Live row counts from database (based on selected categories)
- OP mapping prerequisite check (for EPF)
- Estimated runtime

Example OP dry run output:
```
 [DRY RUN] OP ANONYMIZATION PLAN
 ====================================================================

 SQL Files to Execute:
 1. sql\01_manage_tblspace.sql - Tablespace setup
 2. sql\02pack_anonym_number.sql - Anonymization package
 3. sql\03anon_triggers.sql - Cascade triggers
 4. sql\06_op_setbased_anonym.sql - Set-based anonymization
 5. sql\04drop_anon_triggers.sql - Cleanup triggers

 Fetching row counts from database...

 [x] Entities: 1,234 rows
 [x] Portfolios: 567 rows
 [x] Counterparties: 8,901 rows
 [x] Bank Accounts: 2,345 rows

 ====================================================================
 [DRY RUN COMPLETE] - No database changes were made
```

### Full Anonymization (recommended)

```
run_full_anonymization.bat
```

- Prompts for mode selection: **Full (OP + EPF)**, **OP only**, or **EPF only**
- Collects ALL credentials upfront (no mid-run prompts)
- In Full mode: OP runs in current window, EPF opens in a new window after OP completes

### Manual / Standalone Execution

1. **OP Anonymization**:
 ```batch
 cd Anonymization_OP
 start_anonymous.bat # Interactive mode
 start_anonymous.bat /dryrun # Dry run (no changes)
 ```
 Supports `config.ini` for non-interactive runs.

2. **EPF Anonymization** (requires OP to be completed first):
 ```batch
 cd Anonymization_EPF
 start_epf_anonymization.bat # Execute
 start_epf_anonymization.bat /dryrun # Dry run (no changes)
 ```
 ## OP Phases (start_anonymous_v3.sql)

| Phase | Description | Duration* |
|-------|-------------|-----------|
| Infra | Create atrace schema + mapping table | ~30s |
| 1 | Pre-clear histo table text fields (12 tables) | ~5-15 min |
| 2 | Drop legacy indexes | ~5s |
| 3 | Set-based code anonymization (entities, folders, tiers, accounts) | ~20-40 min |
| 4 | Cleanup: drop anon triggers, re-enable OP triggers | ~10s |

*Duration varies by instance size.

## EPF Phases (start_anonymous_epf.sql)

| Phase | Description | Connection | Duration* |
|-------|-------------|------------|-----------|
| A | Infrastructure (tables, indexes, functions, grants) | SYS | ~15s |
| B | Code cascade from OP (payment, bulk_payment, admin_template) | OPPAYMENTS | ~4 min |
| C | BIC/SWIFT components + payment amounts | OPPAYMENTS | ~50 min |
| D | Independent anonymization (20 steps: users, text, addresses) | OPPAYMENTS | ~10 min |
| E | Reference data (REF_TIERS, REF_BANK_BRANCHE) | OPPAYMENTS | ~10s |
| F | SWIFT message fields + audit trail IPs | OPPAYMENTS | ~10s |
| G | OP schema BIC/BBAN gap fix | SYS | ~10s |
| H | Password reset + hashcode recalculation | OPPAYMENTS | ~4 min |

*Durations measured on a reference instance (~5.3M payments). Production may be slower.

## Output

All SQL output is suppressed except:
- Phase headers (clear section markers)
- Step results with row counts
- Phase completion with elapsed time (e.g., `>> Phase B complete (4m 32s)`)
- Final verification summary (coverage percentages)

Logs are written to:
- `Anonymization_OP/logs/anonyme_op.log`
- `Anonymization_EPF/logs/anonyme_epf.log`

## Key Design Decisions

- **Dry run mode**: All scripts support `/dryrun` flag for pre-flight validation without database changes
- **Set-based**: OP uses MERGE-based bulk updates instead of iterative per-entity calls (20-40 min vs 8-12 hours)
- **Idempotent**: All scripts can be re-run safely (existence checks, NVL patterns)
- **Audit trail**: EPF changes logged to `oppayments.epf_anon_log` with run_id
- **Mapping tables**: `atrace.ref_tables_modif` (OP), `atrace.ref_tables_modif_epf` (EPF), `atrace.epf_anonymization_map` (BIC)
- **Error handling**: Per-step SAVEPOINT with autonomous transaction logging
- **Triggers disabled**: All triggers disabled during execution, re-enabled at end
- **Orphan detection**: Phase A detects EPF codes with no OP mapping and generates synthetic entries
- **Password reset**: Phase H resets all EPF user passwords to "EPF" and recalculates hashcodes (required for login after anonymization)
- **entity_type filtering**: OP merge_codes procedure uses entity_type parameter to avoid mapping collisions between tiers and compte_banque codes

## Prerequisites

- Oracle 19c+ (tested on 19c Enterprise Edition)
- DBA access (SYS, OP, OPPAYMENTS passwords)
- OP anonymization must complete before EPF (EPF Phase B depends on `atrace.ref_tables_modif` being populated)

## Post-Anonymization

After successful execution:
- Login to EPF with any user code + password "EPF"
- **OP Verification:**
 ```batch
 cd Anonymization_OP
 sqlplus op/<password>@<TNS> @sql/verify_anon_coverage_final.sql
 ```
- **EPF Verification:**
 ```batch
 cd Anonymization_EPF
 sqlplus oppayments/<password>@<TNS> @sql/verify_epf_anon_coverage_final.sql
 ```
- Both verification scripts can also be run as SYS (all tables are fully schema-qualified)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| EPF Phase B shows 0 mappings | Run OP anonymization first - EPF depends on `atrace.ref_tables_modif` |
| Dry run shows `[TABLE NOT CREATED]` | Expected if OP hasn't run yet; mapping tables created during execution |
| `ORA-00942: table or view does not exist` | Check schema prefix; verify correct user (OP vs OPPAYMENTS) |
| Long runtime on payment_audit | Normal - table often has 20M+ rows; consider running overnight |

---
*Last updated: 2026-07-10*