# 08 — Open questions for the original developer

Decisions taken during the v4 rebuild that are **reversible** and worth confirming with the person
who wrote the original package. Each item states what v2 did, what v4 does, why, and what changing
it would cost.

Nothing here is a bug. These are judgement calls where the original intent matters more than my
reading of the code.

**Status legend:** 🔵 awaiting review · ✅ agreed · ❌ reverted

---

## The context that frames all of this

The original design let an operator choose what to include, through 28 flags in `config.ini`:
`Ent0/EntC/EntD/Ent1-5` and the same for `Fold`, `Tier`, `Cpte`.

By v3, **20 of those 28 did nothing at all**. `Ent1-5`, `Fold1-5`, `Tier1-5` and `Cpte1-5` were
declared in `start_anonymous_v3.sql` as `&6`–`&10` etc. and never referenced by any statement. The
remaining eight (`C` and `D`) were honoured only by `07`/`08`; `06`, which does the bulk of the
work, states at its own line 27 that it ignores them and hardcodes the column list.

So the selection feature had quietly stopped working. v4 rebuilt it. The questions below are about
**how far it should extend**.

---

## Item 1 — The 17 per-entity PII columns 🔵

**Moved on 2026-08-10 from `inventory_op.csv` to `inventory_op_custom.csv`. Still active.**

### What v2 did
Five free-form slots per category. Each held a **column name** to overwrite with that entity's
anonymized code, or `n` to skip:

```ini
Ent1=telephone   Fold1=groupe_1      Tier1=sector        Cpte1=groupe_1
Ent2=fax         Fold2=groupe_2      Tier2=seniority     Cpte2=groupe_2
Ent3=email_adress Fold3=groupe_3     Tier3=telex         Cpte3=groupe_3
Ent4=nom_pp      Fold4=flag_pp       Tier4=type_interne  Cpte4=n
Ent5=prenom_pp   Fold5=dpt_naissance Tier5=n             Cpte5=n
```

`Ent1-5` and `Fold1-5`/`Tier1-5` targeted `op.tiers`; `Cpte1-5` targeted `op.compte_banque`.

### What v3 did
Nothing with them. The 17 populated slots were dead. `06` hardcoded the identical 17 columns at
lines 775–836, which is why nobody noticed — the behaviour matched by coincidence, and editing
`config.ini` had no effect and produced no warning.

### What v4 does
The **column list** moved into the inventory as `SELF_CODE` rows; the **on/off switch** stayed in
the config file as `ANONYMIZE_<CATEGORY>_ATTRIBUTES`. The 17 rows now live in
`inventory_op_custom.csv` because they are a site choice, not vendor behaviour.

### Question
1. Should these 17 be **shipped defaults** (back in `inventory_op.csv`) or **site-specific**
   (where they are now)? They came from one site's `config.ini`; another site may have chosen
   differently.
2. Is per-category on/off enough granularity, or should each column be individually switchable from
   `anonymization.ini` the way the five slots were?

### Cost of changing
Moving rows between the two CSVs: minutes, no code change. Per-column flags in the `.ini`: a
moderate change to the loader and config parsing.

---

## Item 2 — Which flag governs `tiers.adresse1`–`adresse5` 🔵

### What v2 did
The vendor package cleared the five address lines as part of **`EntD`** — the *description* flag —
alongside `structure.description` and `tiers.description`
([`02pack_anonym_number.sql:105-117`](../../Anonymization_OP/sql/02pack_anonym_number.sql#L105-L117)).
They were never one of the five configurable slots.

### What v4 does
Files them as `SELF_CODE`, so they are gated by `ANONYMIZE_<CATEGORY>_ATTRIBUTES` rather than
`_DESCRIPTION`.

### Why
An address is personal data, not a display label. Grouping it with `telephone` and `nom_pp` seemed
truer to what it is than grouping it with `description`.

### Consequence of the difference
With `DESCRIPTION=y, ATTRIBUTES=n`, v2 would have anonymized addresses and v4 will not. Any other
combination behaves identically.

### Question
Keep the reclassification, or restore v2's grouping under the description flag?

### Cost of changing
Two lines in `inventory_op.csv` — change `SELF_CODE` to `DESCRIPTION` on the five address rows.

---

## Item 3 — How much of the inventory should be optional at all 🔵

**This is the significant one.** Of 579 inventory rows, **only 8 can be switched off by a flag**:

| Rule | Rows | Flag-gated? | Rationale |
|---|---|---|---|
| `CODE` | 462 | **No** | The flags act on the *mapping*, not on this list. A disabled category has no rows in `code_map`, so these statements still run and simply find nothing of that category to substitute. Filtering is **per value**, not per column. |
| `NULL_OUT` | 92 | **No** | Free text is the highest-risk category and the least useful to preserve, so v4 does not make it optional. |
| `DESCRIPTION` | 3 | Yes | `ANONYMIZE_*_DESCRIPTION` |
| `SELF_CODE` | 22 | Yes | `ANONYMIZE_*_ATTRIBUTES` |

### Why `CODE` is gated at the mapping instead of per column

v3 tried per-column gating and got it wrong. `07`/`08` are full of:

```sql
IF '&p_EntC' = 'y' THEN op.merge_codes('mpm_file_bkd', 'entity'); END IF;
```

But `merge_codes` without an entity-type filter substitutes **any** category's code. So with
`EntC=y, TierC=n`, that call still renamed a counterparty code sitting in `mpm_file_bkd.entity` —
the flag set to `n` did not protect it. Getting per-column gating right requires knowing, for each
of 462 columns, which categories can appear in it, and being right every time. Gating the mapping
makes it correct everywhere by construction.

### Questions
1. Was `NULL_OUT` — free text, names, emails, phone numbers, IBAN fragments — ever meant to be
   optional? v4 assumes not.
2. Should any specific table or column be individually excludable through the config file rather
   than by commenting a line in the CSV?
3. Is per-value filtering on `CODE` the right reading of the original intent? It means "disable
   counterparties" leaves counterparty codes untouched **everywhere**, including in columns that
   also hold entity codes — which those columns will still have anonymized.

### Cost of changing
Adding a flag per rule or per section: small. Per-column config flags for 462 columns: not
advisable — that is what the CSV is for.

---

## Item 4 — The `EntC=n` + `EntD=y` combination 🔵

### What v2 did
Allowed it. The description was set to a freshly generated code while the actual code was left
alone, so the label referred to an identifier that existed nowhere.

### What v4 does
Rejects it. A description or attribute flag requires its category to be enabled, because the value
written **is** the anonymized code — without a mapping there is nothing to write.

### Question
Was that combination ever used deliberately? It looks like an accident of the flag design rather
than a feature, but the original developer would know.

### Cost of changing
Small, though it would need a separate identifier generator for categories that are not being
remapped.

---

## Item 5 — 12 columns anonymized twice, the second time to no effect ✅

Recorded for confirmation rather than decision.

`05_op_performance_boost.sql` sets `groupe_1/2/3` to `NULL` on `histo_flux`, `histo_livraison`,
`histo_operation` and `histo_reglement` (orchestrator line 119). `06` then ran `merge_codes` on
those same 12 columns (line 180) — which cannot match a `NULL`. Twelve `PARALLEL(4)` full scans of
the four largest tables in the schema, guaranteed to change nothing.

v4 keeps them as `NULL_OUT` only. That is strictly stronger: a nulled grouping column leaks
nothing, whereas a remapped one still reveals how records were grouped.

**Confirm:** was the intent to null these, or to remap them? If remap, the `NULL_OUT` rows should be
removed instead — but that would weaken anonymization.

---

## Item 6 — Declared column types versus executed behaviour 🔵

`KTP_CTI_ANONYMIZATION_SCOPE.md` types each KTP/CTI column as `E`, `P`, `C`, `E,P,C` or `BA`. But
in `07`/`08` only `BA` columns actually restricted the mapping lookup; every other type searched the
whole mapping regardless of its declared type.

v4 preserves the **executed** behaviour (`category = ANY`) rather than the **declared** type, on the
grounds that under-anonymizing is a leak while over-anonymizing is at worst a mis-map, and only
where the same code value exists in two categories.

### Questions
1. Was the declared type meant to restrict the lookup, and `07`/`08` simply never implemented it?
2. If so, is the risk of leaving a counterparty code in a column typed `E` acceptable?

Specific case worth a look: `tp_data_profile_entity.portfolio` is typed `E` in the scope document
but named `portfolio`, and `08:600-606` gates it on the entity flag. Under `ANY` the ambiguity
stops mattering, but it suggests the type column was not always accurate.

### Cost of changing
Small — change `ANY` to a specific category on the affected rows. The engine already restricts by
category; only the CSV values would change.

---

## Item 7 — Free-text columns that are `NOT NULL` on older schemas 🔵

A `NULL_OUT` column that is `NOT NULL` on a given instance cannot be emptied. v4 reports it in
preflight, skips it at run time rather than failing the whole run with `ORA-01407`, and the verifier
then fails on that column so the gap cannot pass unnoticed.

### Question
For such a column, is the preferred behaviour to (a) leave it and report — current, (b) overwrite it
with a fixed placeholder, or (c) fail the run outright?

Option (b) removes the PII but needs a per-type placeholder convention. Not yet implemented, since
no instance is known to hit this.

---

---

## Item 8 — Checkbox columns: how they are detected, and the gap 🔵

**The one on this list most likely to need the original developer's input.**

### The problem

Several OP columns back checkboxes in the application. They hold single characters — `'O'`/`'N'`
for *oui*/*non*, `'x'` for ticked, and similar. They are control values, not client data. Writing an
anonymized code into one changes what the screen does while concealing nothing, and emptying one
does the same.

v3 did exactly that. `tiers.flag_pp` — a natural-person checkbox — was listed in `config.ini` as
`Fold4`, one of the five configurable portfolio attributes, so every v3 run overwrote it with a
9-character code.

### How v4 detects them

**By declared column width.** A character column of **exactly 1 character** cannot hold a client
identifier — the shortest thing v4 generates is `E_` plus 7 digits — so it is treated as a flag
column and left alone.

The threshold is 1, not 2, on purpose: a `VARCHAR2(2)` column is narrow but can still hold a real
two-character code, and treating it as a checkbox would silently leave client data in place.
Widening the rule trades a data leak for a broken screen, which is the wrong direction. If any
checkbox in this schema is declared `VARCHAR2(2)`, it needs naming explicitly — see question 1
below.

Detection lives in `anon_engine.is_flag_column` and is applied in four places:

| Where | Effect |
|---|---|
| `preflight` | Reported as `CHECKBOX`, not as an error. Without this a `VARCHAR2(1)` column would fail the width check and block the run. |
| `apply_code` | Column skipped |
| `apply_null_out` | Column dropped from the combined statement |
| `apply_self_code` | Column skipped |
| `verify_op_coverage.sql` | Same rule mirrored, so a correct run can pass |

There is a second, value-level guard: `MIN_CODE_LENGTH` (default 2) stops the engine substituting
single-character identifiers. Without it, a real entity code of `'X'` would rewrite every `'X'`
checkbox in the schema — the per-value filtering working against you. Codes skipped this way are
reported by preflight and raised as a `WARN` by the verifier, never silently dropped.

The two settings are aligned on the same assumption — **a checkbox holds exactly one character** —
and guard different things. The width rule excludes whole columns; the length rule catches a
checkbox value sitting in a column too wide to be recognised by width alone.

### The gap

**Width-based detection is a proxy, not a proof.** It catches `VARCHAR2(1)` and `VARCHAR2(2)`. It
does **not** catch a checkbox stored in a wider column — a `VARCHAR2(10)` holding only `'O'` and
`'N'` looks, to the data dictionary, exactly like a code column.

Detecting that would mean profiling the data rather than the definition: sampling distinct values
and inferring "few distinct values, all one character" means a flag. That is doable but it is a
heuristic, and a wrong guess in either direction is bad — anonymizing a checkbox breaks the
application, skipping a real identifier leaks client data.

**`tools/analyze_flag_impact.sql` will surface these.** A wide checkbox column would show a high
`unmapped` share, because `'O'` and `'N'` belong to no source population. That is the practical
detection route today, and it is why the tool is a step in the test checklist rather than optional.

### Questions

1. **Are all checkbox columns in OP exactly one character wide?** If yes, width-based detection is
   complete and nothing more is needed. If any are stored in wider columns, name them and they can
   be excluded explicitly in the inventory.
2. Is there a naming convention for them — `flag_*`, `*_flag`, `is_*`? A name-based rule could
   supplement the width rule cheaply, and would be exact rather than heuristic.
3. Is `MIN_CODE_LENGTH = 2` right for this schema? It is only wrong if genuine entity, portfolio,
   counterparty or bank account codes of a single character exist. Preflight reports how many
   would be affected, so the answer is measurable on the first dry run.

### Cost of changing

Adding named exclusions: one line each in the inventory. A name-pattern rule: small change to
`is_flag_column`. Value profiling: a new preflight pass, and a heuristic to defend.

---

## Summary for the review conversation

| # | Question | Current v4 answer | Reversible? |
|---|---|---|---|
| 1 | Are the 17 PII columns vendor default or site choice? | Site choice — in `inventory_op_custom.csv` | Trivially |
| 2 | Do `adresse1-5` belong to DESCRIPTION or ATTRIBUTES? | ATTRIBUTES | Two lines |
| 3 | Should `NULL_OUT` and `CODE` be switchable? | No — free text always erased; codes filtered per value | Small |
| 4 | Should `EntC=n` + `EntD=y` still work? | No | Moderate |
| 5 | Null or remap the 12 `groupe_*` columns? | Null | Trivially |
| 6 | Should declared `E`/`P`/`C` types restrict the lookup? | No — matches executed v3 behaviour | Small |
| 7 | What to do with `NOT NULL` free-text columns? | Skip and report | Small |
| 8 | **Are all checkbox columns exactly 1 character wide?** | Assumed yes — detection is by declared width, threshold 1 | Small |
