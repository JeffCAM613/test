# 05 — History

How this package got here, and what v4 changed. Kept current — add a row when something material
changes.

---

## Timeline

| When | Version | What happened | Artifacts |
|---|---|---|---|
| Feb 2021 | vendor 3.1 | Original French-authored package. A PL/SQL package `pack_anonym` walks each entity one at a time and cascades its rename across the schema. 98 `AFTER UPDATE` triggers record every rename into `atrace.ref_tables_modif` as an audit trail. | `02pack_anonym_number.sql`, `03anon_triggers.sql`, `04drop_anon_triggers.sql`, `01_manage_tblspace.sql` |
| — | v2 | Windows batch driver wrapped around the vendor package: interactive prompts for categories and credentials, then one `sqlplus` call. Runtime on a production-sized instance: **8–12 hours**, because the per-entity loop re-scans the large `histo_*` tables once per entity. | `start_anonymous.sql`, `start_anonymous.bat` |
| — | v3 | Set-based rewrite. Instead of looping per entity, build a code mapping table once and issue one bulk `UPDATE` per column. Large `histo_*` free-text columns are cleared up-front in a single pass. Runtime dropped to **20–40 minutes**. | `start_anonymous_v3.sql`, `05_op_performance_boost.sql`, `06_op_setbased_anonym.sql` |
| 2026‑07‑07 | v3.1 | KTP/CTI extension scope added (12 tables: `charge_*`, `mpm_file_bkd`, `trade_repository_breakdown`, `val_*`). | `07_ktp_cti_anonym.sql`, `KTP_CTI_ANONYMIZATION_SCOPE.md` |
| 2026‑07‑08 | v3.2 | CTI scope added (`cm_*`, `dm_*`, `tp_*`, `uaa_*`). | `08_cti_anonym.sql` |
| 2026‑07‑10 | v3.3 | README, `/dryrun` flag, top-level OP+EPF orchestrator. | `docs/README.md`, `run_full_anonymization.bat` |
| 2026‑08‑07 | v3.4 | Custom inclusions: extend coverage from a CSV without editing SQL. | `09_inclusions_anonym.sql`, `load_inclusions.sql`, `inclusions.csv` |
| — | EPF track | Separate pipeline for the `OPPAYMENTS` schema: phases A–H, BIC/SWIFT component anonymization, payment amounts, password reset. Developed alongside v3. | `start_anonymous_epf.sql`, `anonymize_epf_itr1/itr2.sql`, `anonymize_epf_phase7/8/9.sql`, `bic/1..5` |
| 2026‑08‑10 | **v4** | Rebuild on an inventory-driven architecture. See below. | `Anonymization_v4/` |

---

## Why v4

Each extension from v3.1 onward added a new numbered script with its own hand-written list of
tables, and a corresponding hand-written section in the docs and in the verification script. By
v3.4 the same information existed in three places that nothing kept in sync — and they had already
diverged.

Alongside that drift, a review of the v3 code found defects that made parts of it unable to work at
all:

### Defects found in v3

| # | Defect | Where |
|---|---|---|
| 1 | **Custom inclusions could never run.** The batch file loaded them into `atrace.anon_inclusions`, then the orchestrator ran `DROP USER atrace CASCADE`, destroying the table. `09` then re-created it empty and reported "no inclusions to process". When launched from the top-level orchestrator the load step was skipped entirely. | `start_anonymous.bat:416`, `start_anonymous_v3.sql:66`, `start_anonymous.bat:321-324` |
| 2 | **Both orchestrators were broken by the folder layout.** `start_anonymous.bat` sat in `sql/` but resolved `%ROOT%sql\…`, i.e. `sql/sql/`. `run_full_anonymization.bat` sat in `Anonymization_OP/` but looked for `%ROOT%Anonymization_OP`. | `start_anonymous.bat:343,419`, `run_full_anonymization.bat:166,185` |
| 3 | **A failed run could not be re-run.** Every run dropped the mapping table and regenerated *random* codes, so rows renamed by a failed run held codes with no surviving mapping. There was no run state and no `WHENEVER SQLERROR`, so failures were silent. | `06_op_setbased_anonym.sql:49` |
| 4 | **`DROP USER atrace CASCADE` destroyed the EPF cascade source** (`ref_tables_modif`) on any re-run. | `start_anonymous_v3.sql:66` |
| 5 | **The OP verifier reported false PASSes.** `LIKE 'E_%'` — in Oracle `_` is a single-character wildcard, so a real code `EUR` counted as anonymized. The EPF verifier got this right (`LIKE 'E\_%' ESCAPE '\'`), so the OP copy was a regression. | `verify_anon_coverage_final.sql` |
| 6 | **Generated code width was never checked** against target column width; a narrow column would raise `ORA-12899` mid-run — see #3 for why that was unrecoverable. | `06_op_setbased_anonym.sql:100` |
| 7 | **Flag comparison was case-sensitive.** A user answering `Y` instead of `y` silently skipped every KTP/CTI table. | `07_ktp_cti_anonym.sql`, `08_cti_anonym.sql` |
| 8 | **Configuration was half-fake.** `06` ignored every category flag — its own header said so — while `07`/`08` honoured them. The PII column lists were hardcoded and merely happened to match `config.ini`. | `06_op_setbased_anonym.sql:27,775-836` |
| 9 | **Zero-row results were invisible.** `merge_codes` printed nothing when no rows matched, so a misspelled column name and a genuinely clean column produced identical output. | `06_op_setbased_anonym.sql:238` |
| 10 | **`/dryrun` could not fail.** Implemented only in the batch files; echoed five hardcoded filenames (three of which the real run never executed) and ran four `COUNT(*)` queries. | `start_anonymous.bat:255-319` |
| 11 | **12 remap calls were dead work.** `05` (phase 1) sets `groupe_1/2/3` to `NULL` on `histo_flux`, `histo_livraison`, `histo_operation` and `histo_reglement`; `06` (phase 3) then ran `merge_codes` on those same 12 columns, which can never match a `NULL`. Twelve `PARALLEL(4)` full scans of the four largest tables in the schema, guaranteed to change nothing. | `05:68,88,108,128` vs `06:497-499,515-517,559-561,602-604` |

### Documentation inconsistencies found

- `08_cti_anonym.sql` header says "34 tables"; it implements 38.
- `07_ktp_cti_anonym.sql` header lists items 2 and 3 both as `charge_contract_process`; the code
  processes `charge_missing_process`.
- `KTP_CTI_ANONYMIZATION_SCOPE.md:301` puts `inclusions.csv` in `Anonymization_OP/`; it is in
  `Anonymization_OP/sql/`.
- `README.md` describes a directory tree that does not exist (`logs/`, package-root batch files).
- `monitor_op_progress.sql` documents the v2 per-entity loop that v3 replaced, and lives in the EPF
  folder.
- Free-text clearing performed by `05_op_performance_boost.sql` was never verified by either
  verification script.

---

## What v4 changed

| Area | v3 | v4 |
|---|---|---|
| Coverage definition | ~700 hardcoded calls across 4 files + a separate doc + a separate verifier list | One inventory CSV read by engine, dry run, verifier and doc generator |
| Configuration | Ignored by `06`, honoured by `07`/`08` | Enforced once at mapping generation; authoritative everywhere |
| Code generation | Random + collision probe + up to 100 retries per code | Deterministic `ROW_NUMBER()`, one statement per category |
| Width safety | None | Preflight refuses to start if any target column is too narrow |
| Restartability | Impossible — mapping regenerated every run | Mapping reused; completed steps skipped |
| Run state | None | `anon_run` + `anon_step_log` |
| Zero-row reporting | Silent | Explicit `NOOP` status |
| Error handling | No `WHENEVER SQLERROR`; always exits 0 | `EXIT FAILURE`; non-zero exit code propagates |
| Dry run | Batch-only, cosmetic, cannot fail | Same code path as the real run; rehearses and can fail |
| Verification | Prefix matching with an unescaped `LIKE` | Residual-value detection (primary) + escaped prefix checks (secondary), inventory-driven, computed summary, non-zero exit |
| Custom inclusions | Separate mechanism that never worked | Just extra inventory rows |

### Coverage reconciliation (v3 → v4)

The v4 inventory was extracted mechanically from `05`/`06`/`07`/`08` and then diffed back against
them. The result is exact:

| | Count |
|---|---|
| `CODE` columns in v3 | 474 |
| `CODE` columns in v4 | 462 |
| Difference | the 12 dead columns from defect #11 |
| `NULL_OUT` columns | 92 in v3, 92 in v4 — identical |
| `DESCRIPTION` | 3 |
| `SELF_CODE` | 22 |
| **Total inventory rows** | **579**, across **167 tables** |

The 12 dropped columns lose no coverage: they remain in the inventory as `NULL_OUT`, which is
strictly stronger than remapping — a nulled grouping column leaks nothing, whereas a remapped one
still reveals how records were grouped.

One judgement call was made during extraction. In v3, `07`/`08` gated each column on a specific
category flag according to the type recorded in `KTP_CTI_ANONYMIZATION_SCOPE.md` (`E`, `P`, `C`,
`E,P,C`, `BA`), but the `merge_codes` call itself only ever restricted the mapping for `BA`
columns — every other type searched the whole mapping. v4 preserves the *executed* behaviour
(`category = ANY`) rather than the *declared* type, for two reasons:

- Under-anonymizing is a data leak; over-anonymizing is at worst a mis-mapping, and only where the
  same code value exists in two categories. The safe direction is broad.
- With flags now gating at mapping generation, `ANY` is already correct: a disabled category simply
  has no rows to match, so the column is left alone automatically.

This also resolves the open question about `tp_data_profile_entity.portfolio`, which the scope doc
typed as `E` while the column name says portfolio — under `ANY` the distinction stops mattering.

### What happened to the v2 selection flags

The vendor design let an operator choose what to include, through four groups of flags in
`config.ini`. It is worth recording exactly what each did, because by v3 most of them had stopped
doing anything.

| v2 flag | What it did | State in v3 | v4 |
|---|---|---|---|
| `Ent0` | Batch-only master switch. If not `y`, forced the other six to `n`. Never reached SQL. | Worked (batch only) | Folded into `ANONYMIZE_ENTITY` |
| `EntC` | Rename entity codes and cascade the rename across the schema | **Ignored by `06`**, honoured by `07`/`08` | `ANONYMIZE_ENTITY` |
| `EntD` | Overwrite `structure.description`, `tiers.description` **and `adresse1`–`adresse5`** | **Ignored by `06`** | `ANONYMIZE_ENTITY_DESCRIPTION` (+ address lines as `SELF_CODE`) |
| `Ent1`–`Ent5` | Names of up to five `op.tiers` columns, each overwritten with the entity's new code where not null | **Completely dead** — passed into `start_anonymous_v3.sql` as `&6`–`&10` and never referenced again | `ANONYMIZE_ENTITY_ATTRIBUTES` + `SELF_CODE` rows in the inventory |

Same for `Fold*` (portfolios, `op.tiers`), `Tier*` (counterparties, `op.tiers`) and `Cpte*`
(bank accounts, `op.compte_banque`).

So of the 28 flags in `config.ini`, v3 actually honoured **eight** — the `C` and `D` flags — and
only inside `07`/`08`. `06`, which does the bulk of the work, ignored all of them and hardcoded the
column list; the 20 numbered slots were dead in every script. A site that changed `Ent1=telephone`
to something else got no change in behaviour and no warning.

v4 restores the intent and makes it real, with one structural change: the *choice of which columns*
moved from five free-form slots in `config.ini` into the inventory as `SELF_CODE` rows. The flags
stayed as the on/off control. This removes the five-column ceiling, lifts the restriction to
`op.tiers` / `op.compte_banque`, and puts the choice in the same list the verifier and the coverage
document read — so a column added there is automatically anonymized, checked, and documented.

The 17 columns this site had selected live in **`inventory_op_custom.csv`**, not in the shipped
`inventory_op.csv`, because they are a site choice rather than vendor behaviour — another site's
`config.ini` would have named different ones. `tiers.adresse1`–`adresse5` stayed in the shipped
inventory: they were never one of the five slots, the vendor package always cleared them.

Whether that split is right is [open question 1](08_open_questions.md).

One v2 combination is deliberately not reproduced: `EntC=n` with `EntD=y`, which set descriptions to
a freshly generated code while leaving the actual code untouched, producing labels that referred to
nothing. In v4 a description or attribute flag requires its category to be enabled.

### Carried forward from v3/EPF

- The **set-based approach** itself — it is what took the runtime from 8–12 h to 20–40 min.
- **Bulk up-front free-text clearing** of the large `histo_*` tables (`05_op_performance_boost.sql`).
- The **category prefix scheme** (`E_`, `P_`, `T_`, `CB_`), so anonymized data looks the same as before.
- The **`entity_type` collision guard** between `compte_banque.code` and `tiers.code`.
- **`pack_anonym.disable_enable_all_triggers`** — the only part of the 118 KB vendor package still in use.
- **EPF's `epf_anon_log` run-logging pattern**, generalized into `anon_step_log`.
- **EPF verifier PART 6's residual-value check** (`admin_leaked`) — the strongest idea in the old
  codebase, and now the *primary* check rather than one section of ten.

### Left behind (kept in `Anonymization_OP/` as backup, not ported)

Confirmed unreachable from `start_anonymous_v3.sql`:

| File | Size | Why dropped |
|---|---|---|
| `02pack_anonym_number.sql` | 118 KB | Only `disable_enable_all_triggers` (~30 lines) was used; `anonymous_tables` is the superseded v2 engine |
| `03anon_triggers.sql` | 61 KB | 98 audit triggers, never created in v3 — `06` wrote `ref_tables_modif` directly |
| `04drop_anon_triggers.sql` | 2.5 KB | Drops triggers 1–98; v3 inlined its own loop for 1–30 only |
| `01_manage_tblspace.sql` | 2.3 KB | Never called, though the dry run listed it as if it were |
| `start_anonymous.sql` | 10 KB | Legacy v2 driver |
| `load_inclusions.sql` | 2.8 KB | Superseded by SQL the batch file generated inline |

Roughly 200 KB of the ~340 KB OP codebase was unreachable.
