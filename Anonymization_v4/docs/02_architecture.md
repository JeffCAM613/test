# 02 — Architecture

## The problem v4 solves

In v3, what got anonymized was expressed as roughly 700 hand-written procedure calls spread across
four SQL files, the documentation was a hand-maintained Markdown table, and the verification script
had its own hand-maintained list of columns. Three independent lists of the same thing. They had
already drifted apart, and nothing could detect that they had.

v4 replaces all three with **one declaration read by all consumers**.

```
config/inventory_op.csv          ← shipped coverage
config/inventory_op_custom.csv   ← site-specific additions
                │
                │  20_load_inventory.sql
                ▼
      anon_meta.anon_inventory   ← the single source of truth
                │
   ┌────────────┼────────────────┬────────────────────┐
   ▼            ▼                ▼                    ▼
anon_engine  anon_engine    verify_op_        generate_coverage_
.apply_      .preflight     coverage.sql      doc.sql
 inventory   (dry run)       (checks it        (writes
 (does it)   (rehearses it)   is gone)         03_coverage.md)
```

Adding a table to scope is a one-line CSV change. The engine picks it up, the dry run reports it,
the verifier checks it, and the coverage doc lists it — with no code change anywhere.

## The inventory

One row per anonymized column.

| Field | Meaning |
|---|---|
| `table_name` | Table in the OP schema |
| `column_name` | Column to anonymize |
| `rule` | `CODE` · `NULL_OUT` · `DESCRIPTION` · `SELF_CODE` — see [01_overview.md](01_overview.md#what-anonymized-means-here) |
| `category` | `ENTITY` · `PORTFOLIO` · `COUNTERPARTY` · `BANK_ACCOUNT` · `ANY` · `NONE` |
| `source` | `BASE` (shipped) or `CUSTOM` (from the site CSV) |
| `notes` | Documentation only; never interpreted |

`category` means different things per rule:

- On a **`CODE`** column it says which slice of the mapping may apply.
  `BANK_ACCOUNT` restricts lookups to bank-account codes — necessary because a `compte_banque.code`
  can be textually identical to a `tiers.code`, and without the restriction a column referencing one
  would be rewritten using the other's mapping.
  `ANY` means the column may hold an entity, portfolio or counterparty code and the mapping is
  searched unrestricted.
- On **`DESCRIPTION`** and **`SELF_CODE`** it says which entity type owns the row, so the correct
  per-category configuration flag gates it.
- On **`NULL_OUT`** it is always `NONE`. Free text is never category-dependent.

## How configuration flags work

Configuration says which entity categories to anonymize. v4 enforces that **at mapping generation,
not at each column**:

```
COUNTERPARTY disabled
        → no COUNTERPARTY rows generated in anon_meta.code_map
                → every CODE column finds no match for counterparty values
                        → counterparty codes are left alone, everywhere, automatically
```

This is why v4 has no per-column conditionals. v3 needed roughly 200 `IF flag = 'y' THEN … ELSE …`
blocks in `07`/`08` to achieve the same thing, and still got it wrong in `06`, which ignored the
flags entirely while documenting that it honoured them. Gating at the source makes the flags
genuinely authoritative and removes the possibility of one script disagreeing with another.

Three flag families, one per rule that is optional:

| Flag | Gates | Was |
|---|---|---|
| `ANONYMIZE_<CATEGORY>` | `CODE` — whether the category's identifiers are mapped at all | `Ent0` + `EntC` |
| `ANONYMIZE_<CATEGORY>_DESCRIPTION` | `DESCRIPTION` — the label column | `EntD` |
| `ANONYMIZE_<CATEGORY>_ATTRIBUTES` | `SELF_CODE` — the extra PII attribute columns | `Ent1`–`Ent5` |

Descriptions and attributes are gated separately because the vendor package
separated them, and the separation is genuinely useful: a support copy often
wants readable labels (`T_0000412` in the UI) while still scrubbing phone
numbers and personal names.

Both require their category to be enabled, because both write the row's
anonymized identifier — without a mapping there is nothing to write.

`NULL_OUT` has no flag. Free text and PII are always erased: it is the
highest-risk category and the least useful to preserve, so it is not made
optional.

**Which columns** each flag governs is declared in the inventory, not in the
configuration. That is the part that changed most from v2, where the five
`Ent1`–`Ent5` slots held column names directly. The inventory removes the
five-slot ceiling, is not restricted to `op.tiers` and `op.compte_banque`, and
is the same list the verifier and the coverage document read.

## Code generation

Codes are generated **deterministically and set-based**:

```sql
INSERT INTO anon_meta.code_map (category, old_code, new_code)
SELECT :category, code,
       :prefix || LPAD(ROW_NUMBER() OVER (ORDER BY code), 7, '0')
  FROM (<category source query>);
```

Uniqueness is guaranteed by construction, so there is no collision probe and no retry loop. The
whole mapping is produced in one statement per category instead of one round-trip per code, and the
result is reproducible: the same source data always yields the same mapping.

v3 instead drew a random 7-digit number per code, queried the mapping table to check for a
collision, and retried up to 100 times — a per-code round-trip that could also fail outright once
the table filled up.

**Width is checked before any data is touched.** `E_` + 7 digits is 9 characters and `CB_` + 7 is
10; preflight compares that against `all_tab_columns.data_length` for every `CODE` column in the
inventory and refuses to start if any target is too narrow. v3 would have discovered this as an
`ORA-12899` partway through a run it could not resume.

## Run lifecycle and restartability

```
anon_meta.anon_run       one row per run: run_id, run_mode (EXECUTE|DRYRUN), status, timestamps
anon_meta.anon_step_log  one row per inventory item per run: rows_affected, elapsed, status, error
anon_meta.code_map       old_code → new_code, retained across runs
```

A run proceeds:

1. **Start** — open a run row, resolve configuration.
2. **Preflight** — resolve every inventory row against the data dictionary; check widths; report.
   A dry run stops here.
3. **Disable triggers** on the target schema.
4. **Generate mapping** — *only if `code_map` is empty for the enabled categories.* An existing
   mapping is reused.
5. **Apply** — iterate the inventory; log every item.
6. **Re-enable triggers**, close the run row.

Step 4 is the critical correctness property. v3 dropped and recreated the mapping table at the top
of every run and regenerated random codes. If a run failed midway, the already-renamed rows held
codes from a mapping that no longer existed — the link between original and anonymized values was
destroyed and could not be rebuilt.

In v4 a re-run **reuses** the mapping. It does not skip previously-completed steps — it re-executes
the whole inventory, and every operation is written to be a no-op when its work is already done.
That is a deliberate choice: skipping based on a previous run's log would be wrong the moment the
configuration changed or the database was partially restored, whereas idempotent re-execution is
correct in every case. See [04_operations.md](04_operations.md#re-running-after-a-failure) for what
that costs.

The metadata schema is never dropped as part of a run. (v3 issued `DROP USER atrace CASCADE` at
startup, which also destroyed `ref_tables_modif` — the table EPF reads to cascade OP's renames.)

## Logging

Every inventory item produces exactly one `anon_step_log` row, **including items that changed zero
rows**. A zero-row result is reported explicitly and distinguished from `SKIPPED`:

| Status | Meaning |
|---|---|
| `OK` | Applied, *n* rows changed |
| `NOOP` | Applied, 0 rows changed — column already clean, or nothing matched |
| `SKIPPED` | Table or column does not exist on this instance (`ORA-00942` / `ORA-00904`) |
| `DISABLED` | Excluded by configuration |
| `ERROR` | Anything else — the run fails |

The distinction matters. v3's `merge_codes` printed nothing at all when zero rows matched, so a
column with a misspelled name and a column that was genuinely already clean produced identical
output: silence. `NOOP` on a column you expected to change is the signal that something is wrong.

Errors other than missing-object are not swallowed. The orchestrator runs under
`WHENEVER SQLERROR EXIT FAILURE`, so the batch file returns a non-zero exit code and a failed run
is visible to whatever invoked it.

## Dry run

`/dryrun` runs the same code path with `p_dry_run => TRUE`. It:

- resolves every inventory row against `all_tab_columns` and reports missing objects,
- checks generated code width against every `CODE` target,
- counts the rows each item *would* change,
- reports how many rows already look anonymized,
- writes `DRYRUN` rows to the step log,
- issues **no DML**, and
- exits non-zero if any check fails.

It is a rehearsal of the real run. (v3's `/dryrun` lived entirely in the batch file, echoed a
hardcoded list of five filenames — three of which the real run did not execute — and issued four
`COUNT(*)` queries. It never consulted the inventory and could not fail.)

## Naming

Our own objects use English names. The vendor's schema objects are never renamed — doing so would
break the application. [06_glossary.md](06_glossary.md) translates them.

| v3 | v4 |
|---|---|
| `atrace` (schema) | `anon_meta` |
| `pack_anonym` | `anon_engine` |
| `merge_codes` | `anon_engine.apply_code_mapping` |
| `generate_unique_mappings` | `anon_engine.generate_code_map` |
| `op_code_mapping` | `code_map` |
| `EntC` / `FoldC` / `TierC` / `CpteC` | `ANONYMIZE_ENTITY` / `_PORTFOLIO` / `_COUNTERPARTY` / `_BANK_ACCOUNT` |
| `ENTITE` / `PORTEFEUILLE` / `TIERS` / `COMPTE` (categories) | `ENTITY` / `PORTFOLIO` / `COUNTERPARTY` / `BANK_ACCOUNT` |

One exception: a schema named `atrace` still exists, holding a single view
`atrace.ref_tables_modif` over `code_map`. The EPF pipeline reads that name and shape, and EPF has
not been ported yet — so the compatibility surface stays until it is. Nothing else uses it, and it
disappears with EPF's port. See [../epf/README.md](../epf/README.md).
