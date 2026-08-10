# KTP Payment Factory — Data Anonymization

Anonymizes client-identifying data in the KTP Payment Factory Oracle databases so a copy of a
production instance can be used for development, testing and support without exposing real client
information.

> **Never run against production.** This performs mass irreversible `UPDATE`s. It is for a restored
> copy only.

---

## What's here

| Folder | What it is |
|---|---|
| **[Anonymization_v4/](Anonymization_v4/)** | **The rebuild. Start here.** OP schema, inventory-driven. |
| [Anonymization_OP/](Anonymization_OP/) | v3, kept unchanged as backup and for comparison |
| [Anonymization_EPF/](Anonymization_EPF/) | v3 EPF (`OPPAYMENTS`) pipeline — not yet ported, still the live path for EPF |

v4 covers the **OP** schema. **EPF** still runs from `Anonymization_EPF/` — see
[Anonymization_v4/epf/README.md](Anonymization_v4/epf/README.md) for what porting it involves.

---

## Start with these

| Read | For |
|---|---|
| [v4/docs/00_status.md](Anonymization_v4/docs/00_status.md) | Objectives and where each one stands |
| [v4/docs/01_overview.md](Anonymization_v4/docs/01_overview.md) | What the two schemas hold, what "anonymized" means here |
| [v4/docs/05_history.md](Anonymization_v4/docs/05_history.md) | How this evolved, and the eleven defects found in v3 |
| [v4/docs/07_first_run_checklist.md](Anonymization_v4/docs/07_first_run_checklist.md) | **Test checklist** — stages A to G |
| [v4/docs/08_open_questions.md](Anonymization_v4/docs/08_open_questions.md) | Decisions to confirm with the original developer |

---

## The idea behind v4

Every anonymized column is declared once, in `config/inventory_op.csv`. That one file drives four
things — the engine, the dry run, the verifier, and the coverage document — so they cannot disagree
about what gets anonymized.

In v3 the same information lived in three hand-maintained places (the SQL scripts, a scope document,
and the verification script) and had already drifted apart.

**579 columns across 167 tables.**

---

## Quick start

```batch
cd Anonymization_v4\config
copy anonymization.template.ini anonymization.ini
REM fill in the SID and tablespaces; leave passwords blank to be prompted

cd ..\op
run_op_anonymization.bat /dryrun     REM rehearse, changes nothing
run_op_anonymization.bat             REM execute
sqlplus op/<password>@<TNS> @verify\verify_op_coverage.sql
```

`anonymization.ini` is git-ignored on purpose — it is the file that ends up holding a real SID and
possibly passwords. Only the template is committed.

---

## Status

Rebuilt but **not yet run against Oracle**. Everything is complete as written and statically
checked; nothing is proven. [The test checklist](Anonymization_v4/docs/07_first_run_checklist.md)
is the plan for proving it, ordered so nothing touches data until stage D.

---

## A note on the old folders

`Anonymization_OP/` and `Anonymization_EPF/` are the previous generation, kept for comparison. They
are unmodified except for one pass that removed a database password and some internal instance names
from usage comments before this repo was made public:

- `op/cashflow` and `oppayments/cashflow` → `op/<password>`, `oppayments/<password>`
- `TANM7881/7882/7883`, `EPFPG783`, `EPFPG785` → generic wording

Nothing functional changed — all five edits were in comments and `PROMPT` text.
