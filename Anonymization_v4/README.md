# KTP Payment Factory — Data Anonymization (v4)

Anonymizes client-identifying data in the KTP Payment Factory Oracle databases so that a copy of a
production instance can be used for development, testing and support without exposing real client
information.

> **v4 is a rebuild.** `Anonymization_OP/` and `Anonymization_EPF/` are kept unchanged as backup and
> reference. Nothing in v4 reads from or writes to them. See [docs/05_history.md](docs/05_history.md)
> for what changed and why.

---

## Status

| Schema | State |
|---|---|
| **OP** | Being rebuilt in `op/` |
| **EPF (OPPAYMENTS)** | Not yet ported — still runs from `Anonymization_EPF/`. See [epf/README.md](epf/README.md) |

---

## The one idea worth knowing

Every column this tool anonymizes is declared **once**, in `config/inventory_op.csv`. That single
file drives four things:

```
                      config/inventory_op.csv
                      config/inventory_op_custom.csv
                                  │
                    loaded into anon_meta.anon_inventory
                                  │
        ┌─────────────┬───────────┴───────────┬──────────────────┐
        ▼             ▼                       ▼                  ▼
   the engine     the dry run           the verifier      docs/03_coverage.md
  (what changes) (what would change)  (what must be gone)   (generated)
```

Because all four read the same rows, **the script, the check and the documentation cannot disagree
about what is anonymized**. Adding a table means adding a line to a CSV — not editing SQL, not
updating a doc, not extending the verifier.

---

## Quick start

```batch
cd Anonymization_v4\op

REM 1. Rehearse. Reads the inventory, checks every table/column exists on this
REM    instance, checks generated codes fit, reports rows that WOULD change.
REM    Makes no changes and returns non-zero if anything would fail.
run_op_anonymization.bat /dryrun

REM 2. Execute.
run_op_anonymization.bat

REM 3. Verify.
sqlplus op/<password>@<TNS> @verify\verify_op_coverage.sql
```

Settings live in `config/anonymization.ini`. Anything left blank is prompted for at runtime —
which is the recommended handling for passwords.

---

## Documentation

| Read this | For |
|---|---|
| [docs/00_status.md](docs/00_status.md) | **Objectives and current status** — start here |
| [docs/01_overview.md](docs/01_overview.md) | What the two schemas hold and what "anonymized" means here |
| [docs/02_architecture.md](docs/02_architecture.md) | How the inventory, engine, mapping and run state fit together |
| [docs/03_coverage.md](docs/03_coverage.md) | **Every table and column that gets anonymized** — generated, never hand-edited |
| [docs/04_operations.md](docs/04_operations.md) | Running, monitoring, restarting, troubleshooting |
| [docs/05_history.md](docs/05_history.md) | How this package evolved, and what v4 changed |
| [docs/06_glossary.md](docs/06_glossary.md) | French→English for the vendor's schema names (`tiers`, `portefeuille`, …) |
| [docs/07_first_run_checklist.md](docs/07_first_run_checklist.md) | **Test checklist** — stages A to G for the first run |
| [docs/08_open_questions.md](docs/08_open_questions.md) | Reversible decisions to confirm with the original developer |
| [docs/09_flag_impact.md](docs/09_flag_impact.md) | Which columns each config flag covers and skips |
| [docs/10_test_log.md](docs/10_test_log.md) | Record of every run against a real database |

---

## Safety notes

- **Never run against production.** This tool performs mass irreversible `UPDATE`s. It is intended
  for a restored copy.
- **OP must complete before EPF.** EPF cascades read the code mapping OP produces.
- **The mapping is the only link back to the original values.** `anon_meta.code_map` maps old code →
  new code. v4 never drops it as part of a run. If you drop it, a partially anonymized database
  cannot be reconciled.
- All triggers on the target schema are disabled for the duration of a run and re-enabled at the
  end, including on failure.
