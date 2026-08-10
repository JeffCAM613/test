-- ============================================================================
-- Flag impact analysis - which columns each flag actually governs
-- ============================================================================
--   sqlplus op/<password>@<TNS> @tools/analyze_flag_impact.sql
--
-- Run from the Anonymization_v4 folder - output paths are relative.
--
-- ----------------------------------------------------------------------------
-- WHAT IT ANSWERS
--
-- docs/09_flag_impact.md can say for certain what happens to 189 of the 579
-- inventory rows. The other 390 are declared CODE + ANY: they may hold entity,
-- portfolio or counterparty codes, so which flag governs them depends on what
-- is actually in the column on THIS instance.
--
-- This script measures it. For every CODE column it counts how many rows hold a
-- value belonging to each of the four source populations, and how many hold a
-- value belonging to none.
--
-- It deliberately builds ALL FOUR populations regardless of the current
-- configuration - the point is to show what each flag WOULD do, including the
-- ones you have switched off.
--
-- ----------------------------------------------------------------------------
-- READ THE "unmapped" COLUMN
--
-- Values in no population are anonymized by no flag setting, ever. Some are
-- legitimate - currency codes, product codes, system references. A large
-- unmapped count on a column you believe holds client identifiers means the
-- inventory is pointing at a population it does not cover, which is worth
-- knowing before the run rather than after.
--
-- ----------------------------------------------------------------------------
-- COST
--
-- Expect roughly the duration of a dry run.
--
-- For a fast estimate on a very large instance, change SAMPLE_PCT below from 0
-- to e.g. 1. Sampling then applies only to tables above 1,000,000 rows; smaller
-- ones are always counted exactly, and sampled figures are marked in the report.
--
-- READ-ONLY. Safe at any time, including before the first anonymization.
-- ============================================================================

-- 0 = count everything exactly. 1-99 = sample that percentage of large tables.
DEFINE SAMPLE_PCT = 0

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 32767
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON
SET NEWPAGE NONE
SET ECHO OFF

WHENEVER SQLERROR EXIT FAILURE

DECLARE
   v_n NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_n FROM anon_meta.anon_inventory;
   IF v_n = 0 THEN
      RAISE_APPLICATION_ERROR(-20050,
         'The inventory is empty. Run a dry run first - that is what loads the CSVs.');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- Results table. Kept so the analysis can be queried and compared between runs.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM all_tables WHERE owner = 'ANON_META' AND table_name = 'FLAG_IMPACT';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.flag_impact (
            measured_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
            table_name    VARCHAR2(128) NOT NULL,
            column_name   VARCHAR2(128) NOT NULL,
            declared_cat  VARCHAR2(20),
            total_rows    NUMBER,
            n_entity      NUMBER,
            n_portfolio   NUMBER,
            n_counterparty NUMBER,
            n_bank_account NUMBER,
            n_unmapped    NUMBER,
            sampled       VARCHAR2(1)
         )]';
   END IF;
END;
/

DELETE FROM anon_meta.flag_impact;
COMMIT;

-- ----------------------------------------------------------------------------
-- Source populations, built independent of the configuration.
--
-- These are the same four queries generate_code_map uses, minus the generated
-- identifiers - we only need to know which codes belong to which category.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM all_tables WHERE owner = 'ANON_META' AND table_name = 'SOURCE_POPULATION';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.source_population (
            category VARCHAR2(20) NOT NULL,
            code     VARCHAR2(80) NOT NULL,
            CONSTRAINT pk_source_population PRIMARY KEY (category, code)
         )]';
      EXECUTE IMMEDIATE
         'CREATE INDEX anon_meta.ix_source_pop_code ON anon_meta.source_population(code)';
   END IF;
END;
/

DELETE FROM anon_meta.source_population;

INSERT INTO anon_meta.source_population (category, code)
SELECT DISTINCT 'ENTITY', s.code
  FROM op.structure s JOIN op.tiers t ON t.code = s.code
 WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers'
   AND t.flag_portefeuille = 'N' AND s.code IS NOT NULL;

INSERT INTO anon_meta.source_population (category, code)
SELECT DISTINCT 'PORTFOLIO', s.code
  FROM op.structure s JOIN op.tiers t ON t.code = s.code
 WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers'
   AND t.flag_portefeuille = 'O' AND s.code IS NOT NULL;

INSERT INTO anon_meta.source_population (category, code)
SELECT DISTINCT 'COUNTERPARTY', code
  FROM op.structure
 WHERE structure = 'Compte' AND ecran = 'w_tiers' AND code IS NOT NULL;

INSERT INTO anon_meta.source_population (category, code)
SELECT DISTINCT 'BANK_ACCOUNT', code
  FROM op.compte_banque WHERE code IS NOT NULL;

COMMIT;

-- ----------------------------------------------------------------------------
-- Measure. One statement per table covering all of its CODE columns.
-- ----------------------------------------------------------------------------
DECLARE
   v_sample   NUMBER := TO_NUMBER('&SAMPLE_PCT');
   v_sql      VARCHAR2(32767);
   v_rows     NUMBER;
   v_sampled  VARCHAR2(1);
   v_tables   PLS_INTEGER := 0;
   v_measured PLS_INTEGER := 0;
   v_skipped  PLS_INTEGER := 0;

   TYPE t_names IS TABLE OF VARCHAR2(128);
   l_cols t_names;

   FUNCTION col_exists(p_t VARCHAR2, p_c VARCHAR2) RETURN BOOLEAN IS
      v_found PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO v_found FROM all_tab_columns
       WHERE owner = 'OP' AND table_name = UPPER(p_t) AND column_name = UPPER(p_c);
      RETURN v_found > 0;
   END;
BEGIN
   DBMS_OUTPUT.PUT_LINE('Measuring CODE columns against the four source populations...');

   FOR t IN (SELECT DISTINCT table_name
               FROM anon_meta.anon_inventory
              WHERE rule = 'CODE'
              ORDER BY table_name) LOOP

      l_cols := t_names();
      FOR c IN (SELECT column_name, category
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'CODE' AND table_name = t.table_name
                 ORDER BY seq) LOOP
         IF col_exists(t.table_name, c.column_name) THEN
            l_cols.EXTEND;
            l_cols(l_cols.COUNT) := c.column_name;
         END IF;
      END LOOP;

      IF l_cols.COUNT = 0 THEN
         v_skipped := v_skipped + 1;
         CONTINUE;
      END IF;

      v_tables := v_tables + 1;

      -- Sample only where it is worth it; small tables are counted exactly.
      SELECT MAX(num_rows) INTO v_rows
        FROM all_tables WHERE owner = 'OP' AND table_name = t.table_name;

      IF v_sample > 0 AND v_rows IS NOT NULL AND v_rows > 1000000 THEN
         v_sampled := 'Y';
      ELSE
         v_sampled := 'N';
      END IF;

      FOR i IN 1 .. l_cols.COUNT LOOP
         -- n_unmapped is counted directly rather than derived by subtraction:
         -- the same code can legitimately belong to two categories, in which
         -- case the four counts overlap and n_total minus them would go
         -- negative. Counting rows where all four joins missed is exact.
         v_sql := 'INSERT INTO anon_meta.flag_impact '
               || '(table_name, column_name, declared_cat, total_rows, n_entity, n_portfolio, '
               || ' n_counterparty, n_bank_account, n_unmapped, sampled) '
               || 'SELECT ''' || t.table_name || ''', ''' || l_cols(i) || ''', '
               || '       (SELECT category FROM anon_meta.anon_inventory '
               || '         WHERE table_name = ''' || t.table_name || ''''
               || '           AND column_name = ''' || l_cols(i) || '''), '
               || '       n_total, n_e, n_p, n_c, n_b, n_u, '
               || '       ''' || v_sampled || ''' '
               || '  FROM (SELECT COUNT(*) AS n_total, '
               || '               COUNT(e.code) AS n_e, COUNT(p.code) AS n_p, '
               || '               COUNT(c.code) AS n_c, COUNT(b.code) AS n_b, '
               || '               COUNT(CASE WHEN e.code IS NULL AND p.code IS NULL '
               || '                           AND c.code IS NULL AND b.code IS NULL '
               || '                          THEN 1 END) AS n_u '
               -- Oracle puts the sample clause between the table and its
               -- alias: FROM op.x SAMPLE(1) t, not FROM op.x t SAMPLE(1).
               || '          FROM op.' || t.table_name || ' '
               || CASE WHEN v_sampled = 'Y' THEN 'SAMPLE(' || v_sample || ') ' ELSE '' END
               || 't '
               || '          LEFT JOIN anon_meta.source_population e '
               || '                 ON e.code = t.' || l_cols(i) || ' AND e.category = ''ENTITY'' '
               || '          LEFT JOIN anon_meta.source_population p '
               || '                 ON p.code = t.' || l_cols(i) || ' AND p.category = ''PORTFOLIO'' '
               || '          LEFT JOIN anon_meta.source_population c '
               || '                 ON c.code = t.' || l_cols(i) || ' AND c.category = ''COUNTERPARTY'' '
               || '          LEFT JOIN anon_meta.source_population b '
               || '                 ON b.code = t.' || l_cols(i) || ' AND b.category = ''BANK_ACCOUNT'' '
               || '         WHERE t.' || l_cols(i) || ' IS NOT NULL)';

         BEGIN
            EXECUTE IMMEDIATE v_sql;
            v_measured := v_measured + 1;
         EXCEPTION
            WHEN OTHERS THEN
               DBMS_OUTPUT.PUT_LINE('  skipped ' || LOWER(t.table_name) || '.'
                                 || LOWER(l_cols(i)) || ': ' || SQLERRM);
         END;
      END LOOP;

      COMMIT;
   END LOOP;

   DBMS_OUTPUT.PUT_LINE('  tables measured .. ' || v_tables);
   DBMS_OUTPUT.PUT_LINE('  columns measured . ' || v_measured);
   DBMS_OUTPUT.PUT_LINE('  tables absent .... ' || v_skipped);
END;
/

-- ----------------------------------------------------------------------------
-- Report
-- ----------------------------------------------------------------------------
SPOOL docs/09_flag_impact_measured.md

DECLARE
   v_prev VARCHAR2(128) := '~';

   PROCEDURE w(p IN VARCHAR2 DEFAULT '') IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE(p);
   END;

   FUNCTION pct(p_part IN NUMBER, p_total IN NUMBER) RETURN VARCHAR2 IS
   BEGIN
      IF NVL(p_total, 0) = 0 THEN RETURN '-'; END IF;
      RETURN TO_CHAR(ROUND(p_part * 100 / p_total)) || '%';
   END;
BEGIN
   w('# 09b — Flag impact, measured');
   w;
   w('> **Generated.** Do not edit by hand.  ');
   w('> Produced by `tools/analyze_flag_impact.sql` on `'
     || SYS_CONTEXT('USERENV', 'DB_NAME') || '` at '
     || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') || '.  ');
   w('> Companion to [09_flag_impact.md](09_flag_impact.md), which explains the model.');
   w;
   w('For every identifier column, how many rows hold a value of each category — and therefore');
   w('exactly what each flag would leave behind. Measured with all four populations built, so the');
   w('numbers are independent of your current configuration.');
   w;
   w('`unmapped` values belong to no source population and are anonymized by **no** flag setting.');
   w;

   -- Headline: which columns are wholly governed by a single flag.
   w('## Columns governed by exactly one flag');
   w;
   w('All of their values belong to one category, so that flag is a clean on/off switch for the');
   w('whole column.');
   w;
   w('| Table | Column | Sole category | Rows | Turning that flag off leaves |');
   w('|---|---|---|---:|---|');
   FOR r IN (SELECT table_name, column_name, total_rows,
                    n_entity, n_portfolio, n_counterparty, n_bank_account, n_unmapped
               FROM anon_meta.flag_impact
              WHERE total_rows > 0
                AND n_unmapped = 0
                AND (CASE WHEN n_entity       > 0 THEN 1 ELSE 0 END
                   + CASE WHEN n_portfolio    > 0 THEN 1 ELSE 0 END
                   + CASE WHEN n_counterparty > 0 THEN 1 ELSE 0 END
                   + CASE WHEN n_bank_account > 0 THEN 1 ELSE 0 END) = 1
              ORDER BY total_rows DESC) LOOP
      w('| `' || LOWER(r.table_name) || '` | `' || LOWER(r.column_name) || '` | `'
        || CASE WHEN r.n_entity       > 0 THEN 'ENTITY'
                WHEN r.n_portfolio    > 0 THEN 'PORTFOLIO'
                WHEN r.n_counterparty > 0 THEN 'COUNTERPARTY'
                ELSE 'BANK_ACCOUNT' END
        || '` | ' || TO_CHAR(r.total_rows, 'FM999,999,999') || ' | all '
        || TO_CHAR(r.total_rows, 'FM999,999,999') || ' rows unanonymized |');
   END LOOP;
   w;

   -- Columns holding values no flag can touch.
   w('## Columns holding unmapped values');
   w;
   w('These values are in none of the four source populations, so no configuration anonymizes');
   w('them. Often legitimate — currency, product and system codes. Worth checking any column here');
   w('that you believe holds client identifiers.');
   w;
   w('| Table | Column | Rows | Unmapped | Share |');
   w('|---|---|---:|---:|---:|');
   FOR r IN (SELECT table_name, column_name, total_rows, n_unmapped
               FROM anon_meta.flag_impact
              WHERE n_unmapped > 0
              ORDER BY n_unmapped DESC
              FETCH FIRST 40 ROWS ONLY) LOOP
      w('| `' || LOWER(r.table_name) || '` | `' || LOWER(r.column_name) || '` | '
        || TO_CHAR(r.total_rows, 'FM999,999,999') || ' | '
        || TO_CHAR(r.n_unmapped, 'FM999,999,999') || ' | '
        || pct(r.n_unmapped, r.total_rows) || ' |');
   END LOOP;
   w;

   -- Full breakdown.
   w('## Full breakdown');
   w;
   FOR r IN (SELECT table_name, column_name, declared_cat, total_rows,
                    n_entity, n_portfolio, n_counterparty, n_bank_account, n_unmapped, sampled
               FROM anon_meta.flag_impact
              ORDER BY table_name, column_name) LOOP

      IF r.table_name <> v_prev THEN
         w;
         w('### `' || LOWER(r.table_name) || '`');
         w;
         w('| Column | Declared | Rows | Entity | Portfolio | Cpty | Account | Unmapped |');
         w('|---|---|---:|---:|---:|---:|---:|---:|');
         v_prev := r.table_name;
      END IF;

      w('| `' || LOWER(r.column_name) || '` | `' || r.declared_cat || '` | '
        || TO_CHAR(r.total_rows, 'FM999,999,999')
        || CASE WHEN r.sampled = 'Y' THEN ' *(sampled)*' ELSE '' END || ' | '
        || pct(r.n_entity, r.total_rows)       || ' | '
        || pct(r.n_portfolio, r.total_rows)    || ' | '
        || pct(r.n_counterparty, r.total_rows) || ' | '
        || pct(r.n_bank_account, r.total_rows) || ' | '
        || pct(r.n_unmapped, r.total_rows)     || ' |');
   END LOOP;

   w;
   w('---');
   w;
   w('_Regenerate:_ `sqlplus op/<password>@<TNS> @tools/analyze_flag_impact.sql`');
END;
/

SPOOL OFF

PROMPT
PROMPT Wrote docs/09_flag_impact_measured.md
PROMPT Also queryable: SELECT * FROM anon_meta.flag_impact;
PROMPT

EXIT SUCCESS
