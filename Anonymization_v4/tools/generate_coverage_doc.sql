-- ============================================================================
-- Generate docs/03_coverage.md from the loaded inventory
-- ============================================================================
--   sqlplus op/<password>@<TNS> @tools/generate_coverage_doc.sql
--
-- Run from the Anonymization_v4 folder - the output path is relative.
--
-- The coverage document is generated rather than written because a hand-written
-- one drifts. In v3 the table list existed in the anonymization scripts, in the
-- scope document and in the verification script, maintained separately; by the
-- time anyone looked, all three disagreed.
--
-- Requires the inventory to be loaded (any run, including a dry run, loads it).
-- Also reports whether each object actually exists on the connected instance,
-- so the output documents this database, not just the intent.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 32767
SET LONGCHUNKSIZE 32767
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON
SET NEWPAGE NONE
SET ECHO OFF

WHENEVER SQLERROR EXIT FAILURE

-- Fail early and clearly rather than emitting an empty document.
DECLARE
   v_n NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_n FROM anon_meta.anon_inventory;
   IF v_n = 0 THEN
      RAISE_APPLICATION_ERROR(-20040,
         'The inventory is empty. Run the anonymization (or a dry run) first - '
      || 'that is what loads config/inventory_op.csv into the database.');
   END IF;
END;
/

SPOOL docs/03_coverage.md

DECLARE
   v_total    NUMBER;
   v_tables   NUMBER;
   v_present  NUMBER;
   v_missing  NUMBER;
   v_custom   NUMBER;
   v_prev_tab VARCHAR2(128) := '~';

   PROCEDURE w(p_text IN VARCHAR2 DEFAULT '') IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE(p_text);
   END w;

   FUNCTION exists_here(p_table IN VARCHAR2, p_column IN VARCHAR2) RETURN VARCHAR2 IS
      v_n PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO v_n
        FROM all_tab_columns
       WHERE owner = 'OP' AND table_name = UPPER(p_table) AND column_name = UPPER(p_column);
      RETURN CASE WHEN v_n > 0 THEN 'yes' ELSE 'no' END;
   END exists_here;

BEGIN
   SELECT COUNT(*), COUNT(DISTINCT table_name) INTO v_total, v_tables
     FROM anon_meta.anon_inventory;
   SELECT COUNT(*) INTO v_custom FROM anon_meta.anon_inventory WHERE source = 'CUSTOM';

   SELECT COUNT(*),
          COUNT(*) - COUNT(CASE WHEN c.column_name IS NOT NULL THEN 1 END)
     INTO v_present, v_missing
     FROM anon_meta.anon_inventory i
     LEFT JOIN all_tab_columns c
       ON c.owner = 'OP'
      AND c.table_name  = i.table_name
      AND c.column_name = i.column_name;
   v_present := v_present - v_missing;

   -- ---------------------------------------------------------------- header --
   w('# 03 - Coverage');
   w;
   w('> **This file is generated.** Do not edit it by hand.');
   w('>');
   w('> Source of truth: `config/inventory_op.csv` (+ `config/inventory_op_custom.csv`)  ');
   w('> Generator: `tools/generate_coverage_doc.sql`  ');
   w('> Generated: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
                     || ' against `' || SYS_CONTEXT('USERENV', 'DB_NAME') || '`');
   w;
   w('Every column below is anonymized by a run. Nothing else in the OP schema is');
   w('touched. The engine, the dry run and the verifier all read this same list, so');
   w('this document cannot disagree with what the tool actually does.');
   w;

   -- --------------------------------------------------------------- summary --
   w('## Summary');
   w;
   w('| | Count |');
   w('|---|---|');
   w('| Columns anonymized | ' || v_total || ' |');
   w('| Tables affected | ' || v_tables || ' |');
   w('| Present on this instance | ' || v_present || ' |');
   w('| Not present on this instance | ' || v_missing || ' |');
   w('| Site-specific additions | ' || v_custom || ' |');
   w;

   w('### By treatment');
   w;
   w('| Rule | Columns | What happens |');
   w('|---|---|---|');
   FOR r IN (SELECT rule, COUNT(*) AS n FROM anon_meta.anon_inventory
              GROUP BY rule
              ORDER BY DECODE(rule,'CODE',1,'NULL_OUT',2,'DESCRIPTION',3,4)) LOOP
      w('| `' || r.rule || '` | ' || r.n || ' | ' ||
        CASE r.rule
           WHEN 'CODE'        THEN 'Identifier replaced using the code mapping'
           WHEN 'NULL_OUT'    THEN 'Set to NULL. Always applied, never configurable'
           WHEN 'DESCRIPTION' THEN 'Label replaced with the anonymized code of its own row'
           WHEN 'SELF_CODE'   THEN 'PII attribute replaced with the anonymized code of its own row'
        END || ' |');
   END LOOP;
   w;

   w('### By category');
   w;
   w('| Category | Columns | Meaning |');
   w('|---|---|---|');
   FOR r IN (SELECT category, COUNT(*) AS n FROM anon_meta.anon_inventory
              GROUP BY category ORDER BY category) LOOP
      w('| `' || r.category || '` | ' || r.n || ' | ' ||
        CASE r.category
           WHEN 'ANY'          THEN 'May hold an entity, portfolio or counterparty code'
           WHEN 'BANK_ACCOUNT' THEN 'References `compte_banque.code`; mapping restricted to bank accounts'
           WHEN 'ENTITY'       THEN 'Owned by an entity row'
           WHEN 'PORTFOLIO'    THEN 'Owned by a portfolio row'
           WHEN 'COUNTERPARTY' THEN 'Owned by a counterparty row'
           WHEN 'NONE'         THEN 'Free text; not category-dependent'
        END || ' |');
   END LOOP;
   w;

   -- ------------------------------------------------------- identifier form --
   w('## Generated identifiers');
   w;
   w('| Category | Prefix | Example | Source of the original codes |');
   w('|---|---|---|---|');
   w('| Entity | `E_` | `E_0000001` | `structure` join `tiers`, `structure=''Entite''`, `flag_portefeuille=''N''` |');
   w('| Portfolio | `P_` | `P_0000001` | same, `flag_portefeuille=''O''` |');
   w('| Counterparty | `T_` | `T_0000001` | `structure`, `structure=''Compte''`, `ecran=''w_tiers''` |');
   w('| Bank account | `CB_` | `CB_0000001` | `compte_banque` |');
   w;
   w('Identifiers are assigned in sorted order of the original code, so the same');
   w('source data always produces the same mapping. The mapping is kept in');
   w('`anon_meta.code_map`.');
   w;

   IF v_missing > 0 THEN
      w('## Not present on this instance');
      w;
      w('The inventory covers several KTP/CTI versions. These ' || v_missing || ' items do not');
      w('exist here and are reported as `SKIPPED` rather than failing the run.');
      w;
      w('| Table | Column | Rule |');
      w('|---|---|---|');
      FOR r IN (SELECT i.table_name, i.column_name, i.rule
                  FROM anon_meta.anon_inventory i
                  LEFT JOIN all_tab_columns c
                    ON c.owner = 'OP'
                   AND c.table_name  = i.table_name
                   AND c.column_name = i.column_name
                 WHERE c.column_name IS NULL
                 ORDER BY i.table_name, i.column_name) LOOP
         w('| `' || LOWER(r.table_name) || '` | `' || LOWER(r.column_name)
           || '` | `' || r.rule || '` |');
      END LOOP;
      w;
   END IF;

   -- ------------------------------------------------------- full column list --
   w('## Full column list');
   w;
   w('Ordered as the engine processes it. `Here` says whether the object exists on');
   w('this instance.');
   w;

   FOR r IN (SELECT table_name, column_name, rule, category, source, notes
               FROM anon_meta.anon_inventory
              ORDER BY table_name, DECODE(rule,'CODE',1,'NULL_OUT',2,'DESCRIPTION',3,4),
                       column_name) LOOP

      IF r.table_name <> v_prev_tab THEN
         w;
         w('### `' || LOWER(r.table_name) || '`');
         w;
         w('| Column | Rule | Category | Here | Notes |');
         w('|---|---|---|---|---|');
         v_prev_tab := r.table_name;
      END IF;

      w('| `' || LOWER(r.column_name) || '` | `' || r.rule || '` | `' || r.category
        || '` | ' || exists_here(r.table_name, r.column_name) || ' | '
        || CASE WHEN r.source = 'CUSTOM' THEN '**site-specific.** ' END
        || NVL(r.notes, '') || ' |');
   END LOOP;

   w;
   w('---');
   w;
   w('_Regenerate after changing any inventory CSV:_');
   w('`sqlplus op/<password>@<TNS> @tools/generate_coverage_doc.sql`');
END;
/

SPOOL OFF

PROMPT
PROMPT Wrote docs/03_coverage.md
PROMPT

EXIT SUCCESS
