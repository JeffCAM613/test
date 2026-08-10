# 04 — Operations

## Before you start

- **Restored copy only.** This makes mass irreversible `UPDATE`s across ~167 tables.
- You need the **SYS** and **OP** passwords, and the names of a data and an index tablespace.
- Oracle 19c or later.
- Expect **20–40 minutes** on a production-sized instance. Almost all of it is a handful of
  `histo_*` tables; the other 150-odd tables are seconds. `tests/manual/row_counts.sql` will tell
  you what you are dealing with.

## Configure

Copy the template and fill it in:

```batch
copy config\anonymization.template.ini config\anonymization.ini
```

Leave the passwords blank — anything blank is prompted for at runtime, which keeps credentials off
disk. Every setting is explained in the template.

## Run

```batch
cd Anonymization_v4\op

REM 1. Rehearse
run_op_anonymization.bat /dryrun

REM 2. Execute  (asks for confirmation)
run_op_anonymization.bat

REM 3. Verify
sqlplus op/<password>@<TNS> @verify\verify_op_coverage.sql
```

Everything is logged to `op\logs\op_anon_<timestamp>.log`.

### Modes

| Invocation | Behaviour |
|---|---|
| `run_op_anonymization.bat` | Interactive. Offers to load `anonymization.ini`, then asks for whatever is missing. |
| `... /dryrun` | Same prompts, then rehearses without changing anything. |
| `... /auto` | No prompts. Takes `anonymization.ini` as-is and applies defaults for anything absent. Fails if a password or SID is missing, since it cannot ask. Still asks for the final `YES`. |
| `... /auto /force` | No prompts at all, including the confirmation. For scripted runs only. |

### What the interactive run asks

1. **Load `anonymization.ini`?** It reports how many values are populated first. Answer `n` and every value is asked for instead, ignoring the file entirely.
2. **Connection** — SID, passwords, tablespaces. Anything already supplied by the config is shown as `[config]` and not re-asked; passwords display masked.
3. **What to anonymize** — the four category switches.
4. **Description labels** and **PII attributes** — one prompt per category, each preceded by **the actual list of columns it governs**, read from the inventory CSVs at prompt time:

   ```
   Entity - columns affected:
         tiers.adresse1 - applies to every category
         ...
         tiers.telephone [site]
         tiers.fax [site]
         tiers.email_adress [site]
         tiers.nom_pp [site]
         tiers.prenom_pp [site]
       Anonymize these? [y]:
   ```

   `[site]` marks rows from `inventory_op_custom.csv`. Because the list is read from
   the CSVs rather than hardcoded, it cannot drift from what the run will actually do — add a
   column to the inventory and it appears in the prompt.

   A category switched off in step 3 skips both of its prompts, since both write that
   category's anonymized code and there would be none to write.
5. **Run behaviour** — parallel degree, custom inventory filename, fail-on-missing. Each shows its
   default in brackets; pressing Enter accepts it.

### What the dry run actually does

It is a rehearsal on the same code path, not a summary. It:

- resolves all 579 inventory items against the data dictionary and reports what is missing here,
- checks every column that will receive a generated identifier is character-typed and at least 10
  characters wide,
- counts how many identifiers each category would produce,
- counts the rows each item **would** change,
- writes `DRYRUN` rows to `anon_meta.anon_step_log`,
- issues **no DML**, and
- **exits non-zero if anything would fail.**

Run it after any change to an inventory CSV. It is the only cheap way to find a typo in a column
name before a 40-minute run finds it for you.

## Watching a long run

sqlplus only prints `DBMS_OUTPUT` once a PL/SQL block finishes, so the running window is quiet for
long stretches. The engine writes its step log through an autonomous transaction, so progress is
visible from a second session straight away:

```batch
sqlplus op/<password>@<TNS> @tests\manual\monitor_op_progress.sql
```

Re-run it whenever you want a fresh picture. It takes no locks.

## Reading the result

Every inventory item produces one step-log row.

| Status | Means | Worth investigating? |
|---|---|---|
| `OK` | Applied, *n* rows changed | No |
| `NOOP` | Applied, **0 rows** changed | **Sometimes.** Fine for a column that was already clean. On a column you expected to change, it means the name is wrong or the mapping is empty. |
| `SKIPPED` | Table or column not on this instance | Only if you expected it to be here |
| `DISABLED` | Excluded by configuration | No |
| `ERROR` | Anything else | Yes — the run failed |

```sql
-- what matched nothing
SELECT object_name, phase FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run) AND status = 'NOOP';

-- the slowest steps
SELECT object_name, rows_affected, ROUND(elapsed_ms/1000) AS secs
  FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run)
 ORDER BY elapsed_ms DESC FETCH FIRST 10 ROWS ONLY;
```

`NOOP` deserves the attention. In v3 a column that matched nothing printed nothing at all, so a
misspelled column name and a genuinely clean column looked identical — silence.

## Re-running after a failure

**Safe. Fix the cause and run it again — no restore needed, no special flag.**

The guarantee is that every operation is a **no-op when its work is already done**, so re-executing
the whole inventory converges on the same result whether the previous run got 5% or 95% through.

| Rule | Why a second pass changes nothing |
|---|---|
| `CODE` | Matches `WHERE column IN (SELECT old_code …)`. An already-substituted value is a *new* code, which is not in `old_code`, so it does not match. |
| `NULL_OUT` | Matches `WHERE column IS NOT NULL`. Already empty, nothing to do. |
| `DESCRIPTION` / `SELF_CODE` | Matches only rows where the column does not already equal its row's code. |
| Mapping | Reused, never regenerated — identifiers stay stable across runs. |
| Triggers | Re-enabled even when the run fails, by a handler that runs before the error propagates. |

### What it does *not* do

It does **not** skip steps that completed in an earlier run. There is no checkpoint; the whole
inventory is re-executed. That is deliberate — skipping based on a previous run's log would be wrong
the moment you changed the configuration or partially restored the database, whereas idempotent
re-execution is correct in every case.

**The cost:** a re-run re-scans every table. Expect it to take roughly as long as the original run
even though it changes almost nothing. On a failure at 90%, you pay for the whole thing again. That
is the price of not having to restore.

### What a clean re-run looks like

```
    NULL_OUT items ......... NOOP
    CODE items ............. NOOP
    DESCRIPTION / SELF_CODE  NOOP
    mapping ................ REUSED (n existing mappings)
```

`REUSED` on all four categories is the signal that the mapping survived. If you see identifiers
being generated instead, `anon_meta` was dropped and the previous run's work can no longer be
reconciled — restore and start over.

### When you must NOT re-run

**After restoring the database.** The mapping in `anon_meta` refers to values the restore has put
back, so the two are out of step. Drop it first:

```sql
DROP USER anon_meta CASCADE;
DROP USER atrace CASCADE;
```

Find the cause of the original failure:

```sql
SELECT phase, object_name, message
  FROM anon_meta.anon_step_log
 WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run) AND status = 'ERROR';
```

> This is the one behaviour you should not take for granted if you have used v3. There, every run
> dropped the mapping table and generated fresh random identifiers, so a failed run left renamed
> rows whose originals could no longer be recovered — the database had to be restored from scratch.

## Verifying

`verify_op_coverage.sql` reads the same inventory the engine used, so it cannot check a different
set of columns than the one that was anonymized.

| Part | Question | Pass/fail? |
|---|---|---|
| 1 | Does any **original identifier** still exist in any identifier column? | **Yes — this is the test** |
| 2 | Is every free-text / PII column empty? | Yes |
| 3 | Do anonymized rows agree with their own code? | Warning only |
| 4 | Is the mapping internally sound — unique, complete, unambiguous? | Yes |
| 5 | How much of each identifier column carries a prefix? | Informational |

Part 5 is deliberately **not** pass/fail. A column can legitimately hold codes that were never
client data — currency codes, product codes, system references — and those correctly have no prefix.
Judging anonymization by prefix would flag them as failures and, worse, would pass a column that
merely happens to start with the right letters.

The script exits non-zero on failure, so it can gate a pipeline. Results persist:

```sql
SELECT part, check_name, bad_rows, detail
  FROM anon_meta.verify_result WHERE status = 'FAIL' ORDER BY part;
```

## Extending coverage

Add a line to `config/inventory_op_custom.csv`:

```csv
my_new_table,entity_code,CODE,ANY,CUSTOM,Added for the 2026 module
my_new_table,contact_email,NULL_OUT,NONE,CUSTOM,
```

Then `run_op_anonymization.bat /dryrun` to confirm it resolves, run for real, and regenerate the
coverage document:

```batch
sqlplus op/<password>@<TNS> @tools\generate_coverage_doc.sql
```

No SQL changes. The engine, the dry run, the verifier and the document all pick it up.

## After handover

`anon_meta.code_map` maps every anonymized identifier back to the real one. It is kept so a failed
run can resume and so verification can be re-run — **not** as a key to hold on to. Once the copy is
verified and handed over:

```sql
DROP USER anon_meta CASCADE;
DROP USER atrace CASCADE;   -- EPF compatibility view; only once EPF has also run
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `ORA-20010 No category is enabled` | Every `ANONYMIZE_*` flag is `n`. Set at least one to `y`. |
| `ORA-20011 column(s) cannot hold a generated identifier` | Preflight found a column too narrow or not character-typed. Nothing was changed. `SELECT object_name, message FROM anon_meta.anon_step_log WHERE status='ERROR'` |
| `ORA-20013 core entity tables are not shaped as expected` | This schema has no `structure`/`tiers`/`compte_banque` in the expected form, so no identifiers can be derived. Check you connected to the right database. |
| Preflight reports `NOT NULL` columns | A free-text column is mandatory on this (usually older) schema, so it cannot be emptied. The engine skips it and the verifier will fail on it. Either change its rule to `SELF_CODE` in the inventory so it is overwritten instead of emptied, or accept the gap knowingly. |
| `ORA-20020 The inventory is empty` | `config/inventory_op.csv` was not found, or every line is a comment. |
| `ORA-20030 code_map is empty` (verify) | Anonymization has not run, or `anon_meta` was dropped. |
| Many `SKIPPED` items | Normal. The inventory covers several KTP/CTI versions; `val_ssi_account` and `val_cptyrating` in particular are not on every instance. Confirm with `tests\manual\check_tables_exist.sql`. |
| A `NOOP` you did not expect | Wrong column name in the inventory, or the category is disabled so the mapping is empty. |
| Run is far slower than 40 minutes | Check the slowest steps (query above). Usually stale statistics on a `histo_*` table, or `PARALLEL_DEGREE=1`. |
| EPF phase B finds no mappings | EPF reads `atrace.ref_tables_modif`, which v4 exposes as a view over `code_map`. Confirm it exists and returns rows. See [../epf/README.md](../epf/README.md). |

## A note on credentials

Passwords are passed to sqlplus as command-line arguments, so they are briefly visible in the
process list to anyone who can see it on the same host. This is inherited from v3 and is normal for
an internal DBA tool, but it is worth knowing before running on a shared jump box. Leaving them out
of `anonymization.ini` at least keeps them off disk.
