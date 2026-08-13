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
The 25 largest tables in the inventory
====================================================================

TABLES_IN_SCOPE COLUMNS_IN_SCOPE APPROX_ROWS_IN_SCOPE
--------------- ---------------- --------------------
 0 0
```

**Note:** Inventory shows 0 tables in scope — will be populated during dry run (C1).

### B2. What exists on this instance

**Result:** ✓ PASS

```
====================================================================
Overall
====================================================================

 INVENTORY FOUND MISSING
---------- ---------- ----------
 0 0 0

====================================================================
Tables entirely absent: (none)
Columns absent: (none)
Columns too narrow: (none) <-- GOOD
====================================================================
```

**Note:** Inventory not yet loaded. Will be verified during dry run.

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

**Run 2 (after git pull):** ❌ FAIL — Exit code 1

```
Inventory file: C:\Users\u735031\AppData\Local\Temp\anon_inventory_13783.sql

=== Coverage inventory ===
ERROR:
ORA-01756: quoted string not properly terminated

The generated inventory file has been KEPT for inspection:
 C:\Users\u735031\AppData\Local\Temp\anon_inventory_13783.sql
```

**Inventory file path:** ✓ Correct format (`C:\Users\u735031\AppData\Local\Temp\anon_inventory_13783.sql`)

**First 5 lines of kept file:**
```sql
SET DEFINE OFF
SET FEEDBACK OFF
INSERT INTO anon_meta.anon_inventory (...) VALUES (UPPER('structure'),UPPER('code'),UPPER('CODE'),UPPER('ANY'),'BASE',''=',1);
INSERT INTO anon_meta.anon_inventory (...) VALUES (UPPER('structure'),UPPER('pere'),UPPER('CODE'),UPPER('ANY'),'BASE',''=',2);
INSERT INTO anon_meta.anon_inventory (...) VALUES (UPPER('tiers'),UPPER('code'),UPPER('CODE'),UPPER('ANY'),'BASE',''=',3);
```

**Root Cause Identified:** The `notes` column has `''='` instead of `''` (empty string).

| Expected | Actual |
|----------|--------|
| `'BASE','',1` | `'BASE',''=',1` |

This is a **batch file variable expansion issue** — something is injecting `=` into the empty string quotes during generation.

### C2. Dry run report analysis

**Status:** ⛔ BLOCKED by C1 error

The dry run failed before producing the preflight report.

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
| C - Dry Run | ❌ FAIL | ORA-01756: quoted string not properly terminated |
| D - Execute | ⛔ BLOCKED | Requires Stage C |
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

### Issue #3: Quoted String Not Properly Terminated (BLOCKER)

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

**Fix Required:** Fix the batch file's handling of empty strings when building INSERT statements

---

## Notes

- This is a test/dev database (TANM7881), not production
- Config uses DATA tablespace for both data and index