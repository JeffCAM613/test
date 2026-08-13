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

---

### Defect T3 — aggregate alias shadowed its own column 🔴 BLOCKER — fixed

```
931/17  PL/SQL: SQL Statement ignored
935/27  PL/SQL: ORA-00935: group function is nested too deeply
936/10  PL/SQL: Statement ignored
936/25  PLS-00364: loop index variable 'T' use is invalid
950/17  PL/SQL: SQL Statement ignored
954/27  PL/SQL: ORA-00935: group function is nested too deeply
955/10  PL/SQL: Statement ignored
955/26  PLS-00364: loop index variable 'G' use is invalid
```

**Where:** `op/sql/30_install_engine.sql`, both grouped cursor loops in `apply_inventory`.

**Cause:** the query read

```sql
SELECT table_name, MIN(seq) AS seq
  FROM anon_meta.anon_inventory
 GROUP BY table_name
 ORDER BY MIN(seq)          -- <-- "seq" here resolves to the ALIAS
```

In `ORDER BY`, Oracle resolves an unqualified name to the **select-list alias** before the base
column. The alias `seq` *is* `MIN(seq)`, so `ORDER BY MIN(seq)` became `ORDER BY MIN(MIN(seq))` —
hence `ORA-00935: group function is nested too deeply`.

`PLS-00364` on loop variables `T` and `G` is pure cascade: the cursor query failed to parse, so the
loop record had no type and every `t.table_name` reference was invalid. **Eight reported errors, two
root causes — one per loop.**

**Fix:** dropped the aliased aggregate from the select list entirely. It was never read — the loops
only use `table_name`, `category` and `rule`. `ORDER BY MIN(seq)` on a `GROUP BY` query is valid
without the column being selected, and with no alias in scope the name resolves to the base column.

The rule is now stated in a comment above the loop, since it is easy to reintroduce.

**Audit done as a result:** swept every SQL file for `AGG(x) AS x` shadowing and for aggregates in
`ORDER BY`. The only other one is `monitor_op_progress.sql:66` (`ORDER BY MIN(logged_at)`), whose
select list has no colliding alias — correct as written.

Also ran a package-wide declaration audit while the compiler was unavailable: all 15 package globals
declared, all spec constants declared, all 23 internal procedures and functions defined, and no
undeclared local variables in any procedure.

---

### Actions (updated)

| # | Action | Status |
|---|---|---|
| 1 | Rename `mode` → `run_mode` in 4 files | ✅ done |
| 2 | Grant `atrace` SELECT on `code_map` `WITH GRANT OPTION` | ✅ done |
| 3 | Re-run A1 | ✅ **PASS** — `created anon_meta.anon_run`, all 6 tables present |
| 4 | Remove aggregate-alias shadowing in `apply_inventory` | ✅ done |
| 5 | Re-run A2 — package body must compile `VALID` | ⏳ next |
| 6 | Continue to Stage B (baseline capture) | ⏳ |

---

### A2 — package body compiles ✅

After T3, both `ANON_ENGINE` PACKAGE and PACKAGE BODY report `VALID`, `all_errors` empty.

### Stage B — baseline captured ✅

| Category | Codes |
|---|---:|
| ENTITY | 76 |
| PORTFOLIO | 32 |
| COUNTERPARTY | 761 |
| BANK_ACCOUNT | 2,016 |

`op.tiers` 869 rows, `op.compte_banque` 2,016 rows. Sample values recorded locally by the tester
(real client data — not reproduced here).

`compte_banque` codes are 8 characters (`SDFFCCFA`); `tiers` codes are 4 (`REAL`, `SDME`). Both
comfortably above the 1-character checkbox threshold and below what the target columns must hold, so
neither the flag-column rule nor `MIN_CODE_LENGTH` should exclude anything real. Worth re-checking
against preflight once the dry run gets that far.

**B1/B2 reported 0 tables in scope** — expected. Those scripts read `anon_meta.anon_inventory`, which
is only populated by a run. They were executed before the first dry run, so the inventory was empty.
Re-run them after C1 succeeds to get the real numbers.

---

### Defect T4 — inventory load fails with ORA-01756 🔴 BLOCKER — under investigation

```
=== Coverage inventory ===
ERROR:
ORA-01756: quoted string not properly terminated
```

The batch reported `579 inventory items prepared`, so the CSV parse produced the expected count.
The failure is in SQL*Plus, loading the generated INSERT file.

**Ruled out by inspection:**

- Both CSVs are pure ASCII with **no quote characters at all in data rows** (apostrophes appear only
  in `#` comment lines, which `eol=#` skips).
- Simulating the batch tokenizer exactly — `eol=#`, blank-line skip, `delims=,` with consecutive
  delimiters collapsed, `tokens=1-5*` — produces 579 statements, every one with exactly 12 single
  quotes. No odd counts, no unbalanced strings.
- `DELETE FROM anon_meta.anon_inventory` is the only statement between the `=== Coverage inventory ===`
  banner and the generated file, and it contains no quotes.

So the fault is in the **load plumbing**, not the inventory content.

**Changes made to isolate it:**

1. **Removed one level of indirection.** The generated file was `@`-included from *inside*
   `20_load_inventory.sql`, which had itself been `@@`-included by the orchestrator, with the path
   arriving through a second `DEFINE` from `&1`. When that fails, the error names neither the file
   nor the line. `20_load_inventory.sql` now only clears the table; the orchestrator runs the
   generated file directly and `21_validate_inventory.sql` validates afterwards.

2. **The resolved path is now echoed** before the load: `PROMPT Inventory file: &inventory_data`.
   This also tests something never yet proven — that SQL\*Plus resolves **multi-digit positional
   parameters**. Everything that has worked so far used `&1`–`&9`; the inventory path arrives as
   `&22`. If `&22` were parsed as `&2` followed by a literal `2`, the path would come out as the SYS
   password with `2` appended.

3. **The generated file is kept when the run fails**, and its location printed, instead of being
   deleted unconditionally. A failed run should leave its inputs behind.

**Next:** re-run C1 and read the `Inventory file:` line, then the first lines of the kept file.

---

### Actions (updated)

| # | Action | Status |
|---|---|---|
| 1 | Rename `mode` → `run_mode` | ✅ |
| 2 | Grant `atrace` SELECT on `code_map` `WITH GRANT OPTION` | ✅ |
| 3 | Re-run A1 | ✅ PASS |
| 4 | Remove aggregate-alias shadowing | ✅ |
| 5 | Re-run A2 | ✅ PASS — both objects VALID |
| 6 | Stage B baseline | ✅ captured |
| 7 | Diagnose ORA-01756 on inventory load | ⏳ **in progress** |
| 8 | Re-run B1/B2 once the inventory loads | ⏳ |

---

### Defect T4 — RESOLVED: cmd leaks substring-replacement text on undefined variables 🔴 BLOCKER

**Root cause found from the generated file**, which the tester recovered. Rows with a note were
correct; rows **without** one were not:

```sql
-- row with a note - correct
... ,'CUSTOM','was Cpte1',577);

-- row with an empty note - BROKEN, three quotes
... ,'BASE',''=',1);
```

`''='` is an odd number of quotes, so the **first** `INSERT` raised `ORA-01756`. Roughly 500 of the
579 rows have no note, so most of the file was malformed.

**Cause:** this line, applied to every row:

```bat
set "NTS=!NTS:'=!"
```

When `NTS` is **undefined**, cmd does not perform the replacement — it emits the
`search=replace` text as a literal. Confirmed by direct experiment on this platform:

```
[raw]         NTS=[]
[after strip] NTS=['=]        <-- from an empty variable
```

So an empty notes field became the literal `'=`, which the template then wrapped in quotes as
`''='`.

**Why the analysis kept missing it:** every check was aimed at the *inventory*, and the inventory was
never at fault. Both CSVs are clean ASCII with no quote characters in any data row, and a simulation
of the tokenizer produced 579 perfectly balanced statements. The corruption was introduced *after*
parsing, by the sanitising step itself. **The fix that mattered was keeping the generated file on
failure** — one look at it identified the cause immediately.

**Fix:** guard the replacement.

```bat
if defined NTS set "NTS=!NTS:'=!"
```

Verified on this platform: empty → `''`, value preserved when present, apostrophe still stripped.

**Wider finding — this affects BOTH substring forms.** A follow-up experiment showed
position-based substring leaks the same way:

```
!UNDEF:~0,1!   ->  ~0,1        (not empty)
!UNDEF:x=y!    ->  x=y         (not empty)
```

An earlier note in this log claimed position substring was safe on undefined variables. **That was
wrong.** Every `!var:...!` expansion in the batch file is now guarded with `if defined`, including
the two `~0,1` uses that were safe only by accident of ordering.

**Rule for this codebase:** never write `!var:...!` without `if defined var` in front of it, for
either form.

---

### Actions (updated)

| # | Action | Status |
|---|---|---|
| 1 | Rename `mode` → `run_mode` | ✅ |
| 2 | Grant `atrace` SELECT on `code_map` `WITH GRANT OPTION` | ✅ |
| 3 | Re-run A1 | ✅ PASS |
| 4 | Remove aggregate-alias shadowing | ✅ |
| 5 | Re-run A2 | ✅ PASS — both objects VALID |
| 6 | Stage B baseline | ✅ captured |
| 7 | Guard all `!var:...!` expansions with `if defined` | ✅ |
| 8 | Re-run C1 dry run | ⏳ next |
| 9 | Re-run B1/B2 once the inventory loads | ⏳ |

---

## Dry run — PASS

```
resolved .......... 427
missing tables .... 68
missing columns ... 79
checkbox columns .. 4   (left alone)
too narrow ........ 0
wrong type ........ 0
not nullable ...... 1
errors ............ 0
rows affected ..... 10,663,242   (would change)
step time ......... 20s
```

579 loaded / 562 shipped / 17 site-specific — all three match. The rule and category breakdown
matches the CSV exactly. 167 tables in scope, ~115M rows.

The counts reconcile: 427 resolved + 68 missing-table rows + 79 missing-column rows + 4 checkbox
+ 1 not-nullable = 579. The 6 absent tables (`CM_DEAL_DEAL`, `CM_PAYT_PAYMENT`,
`CM_CMS_EXCEPTIONS`, `VAL_CPTYRATING`, `VUE_AFFILIE_COMPTE`, `VUE_AFFILIE_TIERS`) account for the 68
rows — `cm_deal_deal` alone holds 32 of them.

---

### Finding T5 — three inventory rows are misclassified 🟠 no action needed, but worth knowing

Preflight flagged four checkbox columns. One was expected. **Three were not:**

```
CHECKBOX ventiler_corresp_bqe.tiers_entite  (VARCHAR2(1)) - will be left alone
CHECKBOX val_ssi_account.tiers_entite       (VARCHAR2(1)) - will be left alone
CHECKBOX val_ssi_corresp.tiers_entite       (VARCHAR2(1)) - will be left alone
CHECKBOX tiers.flag_pp                      (VARCHAR2(1)) - will be left alone
```

`tiers.flag_pp` is the known case — a natural-person checkbox that the old `config.ini` listed as
an anonymizable attribute via `Fold4`.

The three `tiers_entite` columns are more interesting. They are declared `CODE` / `ANY` in the
inventory, inherited from v3's `merge_codes` calls — meaning v3 treated them as **references to an
entity or counterparty code**. But they are `VARCHAR2(1)` on this instance, and codes here are 4
characters (`REAL`, `SDME`) or 8 (`SDFFCCFA`). **A one-character column cannot hold any of them.**

The name reads differently in that light: `tiers_entite` is almost certainly a **discriminator** —
`'T'` or `'E'`, saying which kind of thing the neighbouring column refers to — not a reference
itself.

**No action taken.** The engine already skips them, so behaviour is correct either way, and the
checkbox rule caught the misclassification without needing the inventory to be right. Recorded for
the developer review as evidence that the width rule earns its place: it found three rows that
sixteen years of the previous tool had been feeding into `merge_codes`.

If a code of one character had ever existed, v3 would have overwritten these discriminators
schema-wide.

---

### Finding T6 — one free-text column cannot be emptied 🟠 verifier adjusted

```
NOT NULL histo_pricing_groupe.description (cannot be emptied)
```

`histo_pricing_groupe.description` is `NULL_OUT` in the inventory but `NOT NULL` on this schema. The
engine skips it rather than failing the run with `ORA-01407`, as designed.

**But the verifier would have failed on it**, because PART 2 asserts every `NULL_OUT` column is
entirely empty. A correct run would have reported `FAIL` — which is both wrong and the kind of thing
that trains people to ignore verification output.

**Fixed:** PART 2 now detects `NOT NULL` columns and reports them as `WARN` with the reason and the
remedy, consistent with how checkbox columns are handled. The gap stays visible; it no longer fails
a run that behaved correctly.

**The gap is real:** the free text in that column is still there. Options are to change its rule to
`SELF_CODE` so it is overwritten rather than emptied, or accept it knowingly. See
[08_open_questions.md](08_open_questions.md) item 7.

---

### Defect T7 — first EXECUTE attempt lost its connection 🔵 environmental, re-run

```
Inventory file: C:\Users\...\anon_inventory_5830.sql
=== Coverage inventory ===
ERROR:
ORA-03114: not connected to ORACLE
```

**Not a code defect.** `ORA-03114` means the session was gone. The script had already connected as
SYS, created the metadata schema, reconnected as OP and compiled the package (`No errors.` twice) —
all of which require a live session. It then died on the first statement afterwards.

**Nothing was changed.** The failure came before the inventory load, which is before `start_run` and
long before any DML. No run row, no mapping change, no data touched.

Usual causes: the server process crashed, the session was killed, a profile idle limit expired, or
the network dropped. Worth checking the alert log around the timestamp for `ORA-00600` / `ORA-07445`
or a shutdown.

**Change made:** the orchestrator now asserts its connection immediately after connecting as OP:

```sql
SELECT 'Connected as ' || USER || ' on ' || ... FROM dual;
```

`SET TERMOUT OFF` around the `CONNECT` hides a failed logon, and SQL*Plus does not reliably treat one
as a `SQLERROR` — so without this a bad connect surfaces later as `ORA-03114` on whatever statement
runs next, naming the wrong culprit. Now the run states which user and instance it is on before
doing anything.

---

### Actions (updated)

| # | Action | Status |
|---|---|---|
| 1–7 | T1–T4 fixes | ✅ |
| 8 | Dry run C1/C2 | ✅ **PASS** — 0 errors, 10.6M rows would change |
| 9 | Verifier: treat NOT NULL free-text as WARN not FAIL | ✅ |
| 10 | Orchestrator: assert connection after connecting as OP | ✅ |
| 11 | Re-run Stage D (EXECUTE) after the ORA-03114 drop | ⏳ next |
| 12 | Stage E verify | ⏳ |
