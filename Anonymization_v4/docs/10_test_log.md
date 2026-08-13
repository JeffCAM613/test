# 10 — Test log

Running record of every execution against a real database: what was run, what happened, what broke,
and what was changed as a result.

Kept in the repo rather than in a ticket so that the reason for each fix stays next to the code.
Newest session first.

---

## Session 1 — TANM7881, 2026-08-13

| | |
|---|---|
| Database | TANM7881 — personal/disposable instance, recreatable |
| Oracle server | 19c Enterprise Edition 19.24.0.0.0 |
| sqlplus client | 19.28.0.0.0 |
| Code location | `C:\Users\u735031\Desktop\WORK_DIR\Projects\Test_Anonymization` |
| Config | `anonymization.ini`, `DATA` for both data and index tablespaces, passwords left blank |
| Stage reached | **A1 — blocked, then fixed** |

### Result summary

| Stage | Result |
|---|---|
| A0 — prerequisites | ✅ PASS — sqlplus present, connected as OP |
| A1 — metadata schema | ❌ **FAIL** — two defects, both fixed below |
| A2 — engine compile | ⛔ blocked by A1 |
| B–G | ⏳ not started |

---

### Defect T1 — `MODE` is an Oracle reserved word 🔴 BLOCKER — fixed

```
ORA-00904: "MODE": invalid identifier
ORA-06512: at line 8
```

**Where:** `op/sql/10_create_metadata_schema.sql`, `anon_run` table definition.

**Cause:** the column was named `mode`. `MODE` is on Oracle's reserved word list (it is the keyword
in `LOCK TABLE … IN EXCLUSIVE MODE`), so it cannot be used as a column name unquoted.

**Consequence:** `anon_run` was never created. Because the sequence `seq_anon_run` is created in the
same PL/SQL block *after* the table, it was not created either — and three later `GRANT` statements
then failed with `ORA-00942` because their target did not exist. **Four of the five reported errors
were downstream of this one.**

**Fix:** renamed the column `mode` → `run_mode`, in four places:

| File | What |
|---|---|
| `op/sql/10_create_metadata_schema.sql` | column definition and the `ck_anon_run_mode` check constraint |
| `op/sql/30_install_engine.sql` | the `INSERT` in `start_run` |
| `op/verify/verify_op_coverage.sql` | `WHERE run_mode = 'EXECUTE'` when reading back `MIN_CODE_LENGTH` |
| `tests/manual/monitor_op_progress.sql` | `SELECT` list and `COLUMN` format |

Renamed rather than quoted as `"MODE"`: a quoted identifier stays case-sensitive forever and every
future query has to quote it too.

**Why it was not caught earlier:** nothing in this package had been compiled against Oracle. Reserved
words are exactly the class of error that only a real parser finds — no amount of reading catches it.

**Audit done as a result:** checked every column name in all eight metadata tables against Oracle's
reserved word list. `MODE` was the only one. `RULE`, `SOURCE`, `PART`, `DETAIL`, `PHASE`, `LEVEL` and
`STATUS` are keywords but not reserved, and the tables using them created without error — which the
test output independently confirms.

---

### Defect T2 — view owner had no privilege on the table it reads 🟠 fixed

```
ORA-00942: table or view does not exist
```
…on `CREATE OR REPLACE VIEW atrace.ref_tables_modif`.

**Where:** `op/sql/10_create_metadata_schema.sql`, EPF compatibility view.

**Cause:** the view belongs to `atrace` but selects from `anon_meta.code_map`. A view compiles with
its **owner's** rights, not the creator's, so SYS creating it is not sufficient — `atrace` needed its
own `SELECT` privilege on `anon_meta.code_map`. It had none.

`WITH GRANT OPTION` is required as well, because the next statement is
`GRANT SELECT ON atrace.ref_tables_modif TO op` — `atrace` can only pass on a privilege it holds
grantable.

**Fix:** added before the view is created:

```sql
GRANT SELECT ON anon_meta.code_map TO atrace WITH GRANT OPTION;
```

**Worth noting:** `ORA-00942` here reads as "the table does not exist", which invites the wrong
diagnosis — the initial reading of this error was that the `atrace` schema was missing. It existed;
it simply could not see `anon_meta.code_map`. The script now carries a comment saying so.

**Is `atrace` required?** Not for OP anonymization. It exists solely so the **unported EPF pipeline**
can keep reading `atrace.ref_tables_modif`, which is the name and shape its phase B expects. It
disappears when EPF is ported — see [../epf/README.md](../epf/README.md).

---

### Things that worked

Worth recording, because they were untested assumptions until this run:

- **Idempotency.** The output shows every object reporting `already exists - kept` / `PRESERVED`,
  which means this was at least the second invocation and the re-run guards behaved exactly as
  designed. `code_map` in particular reported `PRESERVED` — the property the whole restart story
  depends on.
- **Partial failure did not cascade into corruption.** `anon_run` failing left the other five tables
  intact and the script continued, so re-running after the fix simply fills the gap.
- **`&tbs_data` / `&tbs_index` substitution** worked inside `q'[…]'` quoted DDL.
- **Connecting as SYSDBA and running the script by relative path** worked from the copied tree on a
  different machine, which exercises the `%~dp0`-derived paths that were broken throughout v3.

---

### Actions

| # | Action | Status |
|---|---|---|
| 1 | Rename `mode` → `run_mode` in 4 files | ✅ done |
| 2 | Grant `atrace` SELECT on `code_map` `WITH GRANT OPTION` | ✅ done |
| 3 | Re-run A1 on TANM7881 with the fixed script | ⏳ next |
| 4 | Continue from A2 | ⏳ |

Both fixes are safe to apply to the partially-created schema — the script keeps what exists and
creates only what is missing.
