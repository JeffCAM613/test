# 07 — Test checklist

Ordered so nothing touches data until stage D. Stages A–C are read-only or reversible.

None of this code has executed against Oracle yet, so the sequence is built to fail early and
cheaply. **Send back the output at each ⏎ marker before moving on.**

| Stage | What | Safe? |
|---|---|---|
| **A** | Install and compile | yes |
| **B** | Baseline capture — the "before" picture for comparison | read-only |
| **C** | Dry run and impact analysis | no DML |
| **D** | Execute | **irreversible** |
| **E** | Verify | read-only |
| **F** | Compare old vs new | read-only |
| **G** | Re-run and restart tests | safe by design |

---

## Stage A — Install and compile

### A0. Prerequisites

- A **restored copy** of a KTP instance. Never production. Prefer the **smallest** you have.
- `sqlplus` on PATH, SYS and OP passwords, DATA and INDEX tablespace names.

```batch
sqlplus -V
```

### A1. Metadata schema and engine

The most likely first-run failure is a PL/SQL compile error, and it is far easier to read on its own
than buried in a full run.

```batch
cd Anonymization_v4\op
sqlplus -L sys/<pwd>@<SID> as sysdba @sql\10_create_metadata_schema.sql <DATA_TBS> <INDEX_TBS>
sqlplus -L op/<pwd>@<SID> @sql\30_install_engine.sql
```

### A2. Confirm both objects compiled

```sql
SELECT object_name, object_type, status FROM all_objects
 WHERE owner = 'OP' AND object_name = 'ANON_ENGINE';
```

Both rows must read `VALID`. If either is `INVALID`:

```sql
SELECT line, position, text FROM all_errors
 WHERE owner = 'OP' AND name = 'ANON_ENGINE' ORDER BY sequence;
```

**⏎ Send: output of A1 and A2.** Compile errors give exact line numbers — that is all I need to fix
them. Repeat A1 after each fix; it changes nothing in OP.

### A3. Confirm the seven metadata tables

```sql
SELECT table_name FROM dba_tables WHERE owner = 'ANON_META' ORDER BY table_name;
```

Expect: `ANON_INVENTORY`, `ANON_RUN`, `ANON_STEP_LOG`, `CODE_MAP`, `CODE_MAP_ANY`, `VERIFY_RESULT`.
(`FLAG_IMPACT` and `SOURCE_POPULATION` appear later, at C3.)

---

## Stage B — Baseline, before anything changes

This is what the old-versus-new comparison in stage F is measured against. **Capture it before
stage D or it is gone.**

### B1. Source populations and table sizes

```batch
sqlplus -L op/<pwd>@<SID> @..\tests\manual\row_counts.sql
```

Records how many entities, portfolios, counterparties and bank accounts exist, and the 25 largest
tables. Also predicts runtime: a few hundred thousand rows in the biggest `histo_*` means minutes;
5M+ means the full 20–40.

### B2. What exists on this instance

```batch
sqlplus -L op/<pwd>@<SID> @..\tests\manual\check_tables_exist.sql
```

Some absences are normal — the inventory covers several KTP/CTI versions. `val_ssi_account` and
`val_cptyrating` in particular are not on every instance.

**Watch the last section:** columns too narrow for a generated identifier. Anything listed there is
either a checkbox column (fine, will be skipped) or a genuine problem.

### B3. A sample of real values, for the before/after diff

```sql
-- Keep this output. It is the evidence that anonymization actually happened.
SELECT code, description FROM op.tiers WHERE ROWNUM <= 20;
SELECT code, description FROM op.compte_banque WHERE ROWNUM <= 20;
SELECT COUNT(*) AS tiers_rows FROM op.tiers;
SELECT COUNT(*) AS cb_rows FROM op.compte_banque;
```

**⏎ Send: B1, B2, B3.** This is the baseline.

> ⚠️ B3 output is **real client data**. Keep it local; do not paste it anywhere shared.

---

## Stage C — Dry run and impact analysis

### C1. Dry run

```batch
cd Anonymization_v4\op
run_op_anonymization.bat /dryrun
```

Interactive. Expect, in order:

1. `Load it? Anything missing is still asked for [Y/n]:` — Enter.
2. SID and passwords (blank in the config on purpose).
3. Four category switches — Enter for `y`.
4. Eight description/attribute prompts, each listing the columns it governs.
   **Check the counts:** descriptions should list 2 / 2 / 2 / 3 columns; attributes 10 / 10 / 9 / 8.
   Wrong counts mean the CSV parser is misreading the inventory.
5. Four run-behaviour prompts, defaults `[4]`, `[inventory_op_custom.csv]`, `[n]`, `[2]`.

### C2. Read the dry-run report

| Line | Expected | If different |
|---|---|---|
| `579 inventory items prepared` | 579 | the CSV parser dropped or duplicated rows |
| `loaded ............ 579 items` | 579 | the load file did not reach the database intact |
| `shipped ......... 562` | 562 | `inventory_op.csv` |
| `site-specific ... 17` | 17 | if 0, the custom file was not found |
| `resolved ..........` | most of 579 | how much of the inventory this schema has |
| `missing tables ....` | some is normal | which modules are absent here |
| `checkbox columns ..` | ≥ 1 expected | see C4 |
| `too narrow ........ 0` | **must be 0** | a code column cannot hold `CB_0000001` |
| `wrong type ........ 0` | **must be 0** | a code column is not text |
| `not nullable ......` | ideally 0 | a free-text column is mandatory here |
| exit code | `0` | preflight refused to proceed |

```batch
run_op_anonymization.bat /dryrun
echo Exit code: %ERRORLEVEL%
```

```sql
-- per-item detail
SELECT status, COUNT(*) FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run) GROUP BY status;

SELECT object_name, rule, message FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
   AND status IN ('ERROR','SKIPPED') ORDER BY object_name;
```

**⏎ Send: console output, `op\logs\op_anon_<timestamp>.log`, and both queries.**

**Do not proceed until the dry run exits 0.**

### C3. Flag impact

```batch
cd Anonymization_v4
sqlplus -L op/<pwd>@<SID> @tools\analyze_flag_impact.sql
```

Read-only. Writes `docs\09_flag_impact_measured.md`.

**⏎ Send: the first two sections.** The second — columns holding *unmapped* values — is the
important one. Those values are anonymized by no flag setting at all. A column you believe holds
client identifiers showing a high unmapped share is a coverage hole that neither verifier would
catch.

### C4. Checkbox columns

```sql
SELECT object_name, message FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
   AND message LIKE '%checkbox%' ORDER BY object_name;
```

**⏎ Send this.** I expect `tiers.flag_pp` at minimum — a natural-person checkbox that the old
`config.ini` listed as an anonymizable attribute. Confirm every column listed is genuinely a
checkbox and not something that ought to be anonymized.

Also check nothing real is being skipped as too short:

```sql
SELECT category, old_code FROM anon_meta.code_map WHERE LENGTH(old_code) < 2;
```

If those are genuine client identifiers, lower `MIN_CODE_LENGTH` and re-run C1.

### C5. Cross-check the mapping against reality

The mapping counts from C1 must equal the source populations from B1 — same four numbers. If they
differ, the mapping source queries are selecting the wrong rows, which is a correctness bug worth
catching before any data changes.

**⏎ Send: the comparison.**

---

## Stage D — Execute

### D1. Restore point

Everything after this is irreversible.

```sql
-- as SYS, if the database is in archivelog mode
CREATE RESTORE POINT before_anon GUARANTEE FLASHBACK DATABASE;
```

If flashback is unavailable, take whatever snapshot or export your environment offers. **Do not skip
this on the first run.**

### D2. Run

```batch
cd Anonymization_v4\op
run_op_anonymization.bat
```

Type `YES` when asked. From a **second terminal**:

```batch
sqlplus -L op/<pwd>@<SID> @..\tests\manual\monitor_op_progress.sql
```

Re-run it whenever you want a fresh picture — it takes no locks, and it is the only way to see
progress while a phase is running.

**⏎ Send: console output, log file, and one monitor snapshot from partway through.**

### D3. If it fails

**Do not restore yet.** The mapping survives and the failure is diagnosable:

```sql
SELECT phase, object_name, message FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run) AND status = 'ERROR';
```

**⏎ Send that.** I will tell you whether re-running resumes cleanly or whether the restore point is
needed.

---

## Stage E — Verify

### E1. Coverage verification

```batch
cd Anonymization_v4\op
sqlplus -L op/<pwd>@<SID> @verify\verify_op_coverage.sql
echo Exit code: %ERRORLEVEL%
```

Goal: `RESULT: PASS`, exit code 0.

The part that matters is **PART 1, residual identifiers**. Any non-zero there means a column still
holds real client codes.

```sql
SELECT part, check_name, bad_rows, detail
  FROM anon_meta.verify_result WHERE status IN ('FAIL','WARN') ORDER BY part;
```

**⏎ Send: full output and that query.**

### E2. Eyeball it against the baseline

Same queries as B3:

```sql
SELECT code, description FROM op.tiers WHERE ROWNUM <= 20;
SELECT code, description FROM op.compte_banque WHERE ROWNUM <= 20;
SELECT COUNT(*) AS tiers_rows FROM op.tiers;
SELECT COUNT(*) AS cb_rows FROM op.compte_banque;
```

Expect `E_`/`P_`/`T_` codes in `tiers`, `CB_` in `compte_banque`, descriptions matching their own
code, and **row counts identical to B3** — anonymization must not lose rows.

**⏎ Send: this, alongside the B3 output.**

### E3. Spot-check the things most likely to be wrong

```sql
-- checkbox column must still hold its original short values
SELECT flag_pp, COUNT(*) FROM op.tiers GROUP BY flag_pp;

-- free text must be entirely gone
SELECT COUNT(*) FROM op.histo_operation WHERE description IS NOT NULL;
SELECT COUNT(*) FROM op.uaa_users WHERE email IS NOT NULL;

-- the EPF compatibility view must return rows
SELECT COUNT(*) FROM atrace.ref_tables_modif;

-- triggers must be back on
SELECT status, COUNT(*) FROM all_triggers WHERE owner = 'OP' GROUP BY status;
```

**⏎ Send all four.** The last is important: every trigger should be `ENABLED`.

---

## Stage F — Old versus new

### F1. Run the v3 verifier against the v4-anonymized database

```batch
sqlplus -L op/<pwd>@<SID> @..\..\Anonymization_OP\sql\verify_anon_coverage_final.sql
```

It reads `atrace.op_code_mapping`, which v4 does not create, so PARTS 7–8 will error. **That is
expected.** What matters is PARTS 1–6.

**⏎ Send the output.** Two outcomes are interesting:

- Old says `PASS` where new says `FAIL` → the unescaped `LIKE 'E_%'` bug demonstrated on your own
  data, since `_` matches any character.
- Old says `FAIL` where new says `PASS` → I need to look at it. Most likely the old script is
  checking a column v4 deliberately skips (a checkbox, or a short code).

### F2. Comparing a v3 run with a v4 run

If you want to run **v3 on one copy and v4 on another** and have an AI compare the databases, the
comparable facts are:

| Compare | How |
|---|---|
| Row counts per table | must be identical on both — neither tool deletes rows |
| Distinct code counts in `tiers`, `compte_banque` | must match the B1 baseline on both |
| Which columns still hold pre-anonymization values | v4: `anon_meta.verify_result`. v3: no equivalent — has to be derived by hand |
| Free-text columns still populated | run E3's queries on both |
| Checkbox columns | v3 overwrote `tiers.flag_pp` with a code; v4 leaves it. **Expect a difference here — it is the fix, not a regression** |
| Runtime | v3 20–40 min; v4 should be comparable or faster (12 fewer full scans) |

**Expected differences, all deliberate:**

1. `tiers.flag_pp` and any other checkbox column — v3 corrupts, v4 preserves.
2. `groupe_1/2/3` on `histo_flux`, `histo_livraison`, `histo_operation`, `histo_reglement` — both
   end up `NULL`, but v3 wasted four parallel full scans getting there.
3. Identifiers under 3 characters — v3 substitutes, v4 leaves alone to protect checkbox values.
4. Generated codes differ — v3 random, v4 sequential. Both are valid anonymizations; only the
   *shape* differs (`E_4821903` vs `E_0000017`).

**⏎ Send: whatever comparison you produce.** I am most interested in any difference **not** on that
list.

---

## Stage G — Re-run and restart

### G1. Re-run without restoring

```batch
cd Anonymization_v4\op
run_op_anonymization.bat
```

Expect:

- all four categories report **`REUSED`** — this is the key line,
- **every** inventory item reports `NOOP` — nothing left to change,
- `rows affected` near zero,
- verification still passes,
- **runtime comparable to the first run.** It re-scans every table rather than skipping completed
  steps, so it is not fast. That is deliberate: skipping based on the previous run's log would be
  wrong if the config changed or the database were partially restored.

This proves the restartability fix — the property v3 lacked, where a failed run could not be resumed
because the mapping had been regenerated with new random values.

**⏎ Send: the summary block.** If any category says it generated identifiers rather than `REUSED`,
stop and tell me — that would mean the mapping did not survive.

### G2. Custom inclusions

Add a real row to `config\inventory_op_custom.csv` — any table and free-text column that exists on
your instance:

```csv
some_table,some_text_column,NULL_OUT,NONE,CUSTOM,test of the custom inventory
```

Then dry run, run, and confirm it appears in the step log and the coverage document.

**This feature never once worked in v3** (the load target was dropped before it was read), so this
is its first real exercise.

**⏎ Send: the step-log row for it.**

### G3. Coverage document

```batch
cd Anonymization_v4
sqlplus -L op/<pwd>@<SID> @tools\generate_coverage_doc.sql
```

Overwrites `docs\03_coverage.md` with the real per-column list including what exists here.

**⏎ Send: the first 60 lines** so I can confirm the formatting.

---

## Quick reference

| Stage | Command | Safe? |
|---|---|---|
| A1 | `@sql\10_create_metadata_schema.sql <DATA> <IDX>`, `@sql\30_install_engine.sql` | yes |
| B1–B3 | `@..\tests\manual\row_counts.sql`, `check_tables_exist.sql`, sample queries | read-only |
| C1 | `run_op_anonymization.bat /dryrun` | no DML |
| C3 | `@tools\analyze_flag_impact.sql` | read-only |
| D1 | `CREATE RESTORE POINT ... GUARANTEE FLASHBACK DATABASE` | yes |
| D2 | `run_op_anonymization.bat` | **irreversible** |
| E1 | `@verify\verify_op_coverage.sql` | read-only |
| F1 | v3 verifier, for comparison | read-only |
| G1 | `run_op_anonymization.bat` again | safe by design |

## Starting over

After restoring from the flashback point, drop the metadata schema so the mapping is regenerated:

```sql
DROP USER anon_meta CASCADE;
DROP USER atrace CASCADE;
```

Leaving `anon_meta` in place after a restore is what you do **not** want — the mapping would refer to
values the restore has put back.
