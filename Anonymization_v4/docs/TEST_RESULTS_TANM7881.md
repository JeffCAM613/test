# Test Results: TANM7881 Anonymization

**Test Date:** 2026-08-13 
**Database:** TANM7881 
**Tester:** (via Copilot) 

---

## Pre-requisites Check

| Check | Result | Notes |
|-------|--------|-------|
| sqlplus available | ✓ PASS | Version 19.28.0.0.0 |
| Database connectivity | ✓ PASS | Connected as OP user |
| Config file created | ✓ PASS | config/anonymization.ini |

---

## Stage A — Install and Compile

### A0. Prerequisites
```
sqlplus -V
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.28.0.0.0
```
**Result:** ✓ PASS

### A1. Metadata schema and engine

**First Run:** ❌ FAIL — MODE reserved word issue 
**After code fix (git pull):** ✓ PASS

```
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.24.0.0.0

=== Metadata schema (anon_meta) ===
user anon_meta already exists - kept
anon_meta.code_map already exists - PRESERVED
anon_meta.code_map_any already exists
anon_meta.anon_inventory already exists
created anon_meta.anon_run <-- NOW CREATED
anon_meta.anon_step_log already exists
anon_meta.verify_result already exists
=== Metadata schema ready ===
```

**Result:** ✓ PASS (after code update)

### A2. Compile check

**First Run:** ❌ FAIL — Package body compilation errors (lines 931-955) 
**After code fix (git pull):** ✓ PASS

```
No errors.
No errors.
```

Object status:
| Object | Type | Status |
|--------|------|--------|
| ANON_ENGINE | PACKAGE | VALID |
| ANON_ENGINE | PACKAGE BODY | VALID |

**Result:** ✓ PASS (after code update)

### A3. Metadata tables check

**Result:** ✓ PASS

```sql
SELECT table_name FROM dba_tables WHERE owner = 'ANON_META';
```

| Table | Status |
|-------|--------|
| ANON_INVENTORY | ✓ EXISTS |
| ANON_RUN | ✓ EXISTS |
| ANON_STEP_LOG | ✓ EXISTS |
| CODE_MAP | ✓ EXISTS |
| CODE_MAP_ANY | ✓ EXISTS |
| VERIFY_RESULT | ✓ EXISTS |

All 6 expected tables present.

---

## Stage B — Baseline Capture

### B1. Source populations and table sizes

**Result:** ✓ PASS

```
====================================================================
Source populations - how many identifiers will be generated
====================================================================

CATEGORY CODES
---------------- ------------
ENTITY 76
PORTFOLIO 32
COUNTERPARTY 761
BANK_ACCOUNT 2,016

====================================================================
The 25 largest tables in the inventory (top 5 shown)
====================================================================

TABLE ROWS (approx) COLUMNS
---------------------------------- ---------------- -------
HISTO_COMPTA 3,702,147 4
HISTO_REGLEMENT 3,346,056 13
HISTO_MOUVEMENT 2,322,570 5
HISTO_OPERATION 1,455,434 28
HISTO_MOUV_SOLDE 830,814 1

TABLES_IN_SCOPE COLUMNS_IN_SCOPE APPROX_ROWS_IN_SCOPE
--------------- ---------------- --------------------
 167 579 115214614
```

### B2. What exists on this instance

**Result:** ✓ PASS

```
====================================================================
Overall
====================================================================

 INVENTORY FOUND MISSING
---------- ---------- ----------
 579 432 147
====================================================================
Tables entirely absent: 6 (CM_CMS_EXCEPTIONS, CM_DEAL_DEAL,
 CM_PAYT_PAYMENT, VAL_CPTYRATING, VUE_AFFILIE_COMPTE, VUE_AFFILIE_TIERS)
Columns absent from existing tables: 79 (version differences)
Columns too narrow: 4 (checkbox columns — correctly left alone)
====================================================================
```

**Note:** 147 missing items are expected (tables/columns from newer versions not present on this instance).

### B3. Sample of real values (before anonymization)

**Result:** ✓ PASS — Baseline captured

**op.tiers (869 rows):**
| CODE | DESCRIPTION |
|------|-------------|
| REAL | OLD REAL FUSION SSE / CLEE |
| SDME | OLD SDME TUP CLEE |
| TEIS | OLD TEISSIER FUSION CLEE |
| CSDE | OLD COMPTOIR SAVOYARD CSDE |
| ELUM | OLD ELECTROLUMEX TUP CLEE |
| TAEE | TAE |
| LINA | ALDIANCE |
| NRAL | OLD N.R.A LYON TUP CLEE |
| CCFA | OLD COMPTOIR DES COURANTS FAIBLES/ITEL |
| SATC | OLD SATEC |

**op.compte_banque (2,016 rows):**
| CODE | DESCRIPTION |
|------|-------------|
| SDFFCCFA | OLD COUR FAIBLES TUP ITEL |
| SDFFSATC | OLD CC de SATEC chez SDFF |
| SDFFAPPR | OLD CC de L'APPRO. ELEC. TUP ROGER |
| SDFFCABU | OLD CC de CABUS&RAULOT FUSION ROGER |
| SDFFCECI | OLD CC de CECCI TUP APPR |
| SDFFCCEN | OLD CC CPT CENTRAL chez SDFF |
| SDFFELEC | OLD CC de ELEC RADIO chez SDFF |
| SDFFBIAN | OLD CC de BIANCHI chez SDFF |
| SDFFDAEM | CC de DAEM chez SDFF |
| SDFFLARY | OLD CC de MACLARY chez SDFF |

⚠️ **Note:** This is real client data — keep local, do not share.

---

## Stage C — Dry Run

### C1. Dry run execution

**Run 2 (after git pull for Issue #3):** ✓ PASS — Exit code 0

```
=== Coverage inventory ===
loaded ............ 579 items
shipped ......... 562
site-specific ... 17

NULL_OUT NONE 92
CODE ANY 390
CODE BANK_ACCOUNT 72
DESCRIPTION ANY 2
DESCRIPTION BANK_ACCOUNT 1
SELF_CODE ANY 5
SELF_CODE BANK_ACCOUNT 3
SELF_CODE COUNTERPARTY 4
SELF_CODE ENTITY 5
SELF_CODE PORTFOLIO 5
```

### C2. Dry run report analysis

**Result:** ✓ PASS

```
Run id .............. 1
Mode ................ DRYRUN (no changes will be made)
Categories .......... ENTITY,PORTFOLIO,COUNTERPARTY,BANK_ACCOUNT
Descriptions ........ ENTITY,PORTFOLIO,COUNTERPARTY,BANK_ACCOUNT
PII attributes ...... ENTITY,PORTFOLIO,COUNTERPARTY,BANK_ACCOUNT
Parallel degree ..... 4

--- Preflight -------------------------------------------------
CHECKBOX ventiler_corresp_bqe.tiers_entite (VARCHAR2(1)) - will be left alone
CHECKBOX val_ssi_account.tiers_entite (VARCHAR2(1)) - will be left alone
CHECKBOX val_ssi_corresp.tiers_entite (VARCHAR2(1)) - will be left alone
NOT NULL histo_pricing_groupe.description (cannot be emptied)
CHECKBOX tiers.flag_pp (VARCHAR2(1)) - will be left alone

resolved .......... 427
missing tables .... 68
missing columns ... 79
checkbox columns .. 4 (left alone)
too narrow ........ 0 <-- PASS
wrong type ........ 0 <-- PASS
not nullable ...... 1

==============================================================
Run 1 summary (DRYRUN)
==============================================================
applied ........... 0
no rows matched ... 0
skipped ........... 304 (not present on this instance)
disabled .......... 0 (excluded by configuration)
errors ............ 0
rows affected ..... 10,663,242
step time ......... 20s
==============================================================

====================================================================
 DRY RUN COMPLETE - no changes were made.
 Re-run without /dryrun to execute.
====================================================================
```

**Key Validations:**
| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Loaded items | 579 | 579 | ✓ PASS |
| Shipped | 562 | 562 | ✓ PASS |
| Site-specific | 17 | 17 | ✓ PASS |
| checkbox columns | tiers.flag_pp minimum | 4 (incl. flag_pp) | ✓ PASS |
| too narrow | 0 | 0 | ✓ PASS |
| wrong type | 0 | 0 | ✓ PASS |
| errors | 0 | 0 | ✓ PASS |

---

## Stage D — Execute (NOT YET - requires approval)

*Will not proceed without explicit approval*

---

## Stage E — Verify

*Pending Stage D completion*

---

## Summary

| Stage | Status | Notes |
|-------|--------|-------|
| A - Install | ✓ PASS | A1 ✓, A2 ✓ (after fix), A3 ✓ |
| B - Baseline | ✓ PASS | 869 tiers, 2016 compte_banque captured |
| C - Dry Run | ✓ PASS | 10.6M rows would change, 0 errors |
| D - Execute | ⏳ READY | Awaiting approval |
| E - Verify | ⏳ PENDING | |

---

## Issues Found

### Issue #1: MODE Reserved Word — RESOLVED

**Location:** `op/sql/10_create_metadata_schema.sql` 
**Error:** `ORA-00904: "MODE": invalid identifier` 
**Cause:** The column name `MODE` is an Oracle reserved word 
**Resolution:** Fixed in code update (git pull 2026-08-13)

### Issue #2: ANON_ENGINE Package Body Compilation Errors — RESOLVED

**Location:** `op/sql/30_install_engine.sql` 
**Errors:**
- Line 931-936: `ORA-00935: group function is nested too deeply` + `PLS-00364: loop index variable 'T' use is invalid`
- Line 950-955: Same errors with loop index variable 'G'

**Cause:** PL/SQL syntax issues in the engine package body 
**Resolution:** Fixed in code update (git pull 2026-08-13)

### Issue #3: Quoted String Not Properly Terminated — RESOLVED

**Location:** `op/run_op_anonymization.bat` (inventory SQL generator) 
**Error:** `ORA-01756: quoted string not properly terminated` 
**Phase:** Coverage inventory loading 

**Root Cause:** Batch file variable expansion corruption. Empty notes field generates `''='` instead of `''`.

**Evidence:**
```sql
-- Generated (wrong):
VALUES (...,'BASE',''=',1);

-- Expected:
VALUES (...,'BASE','',1);
```

**Resolution:** Fixed in code update (git pull 2026-08-13)

---

## Notes

- This is a test/dev database (TANM7881), not production
- Config uses DATA tablespace for both data and index
