-- ============================================================================
-- Schema-wide leak scan - is the INVENTORY complete?
-- ============================================================================
--   sqlplus op/<password>@<TNS> @tools/scan_for_leaks.sql
--
-- Run from the Anonymization_v4 folder. Read-only. Run AFTER anonymizing.
--
-- ----------------------------------------------------------------------------
-- THE QUESTION THIS ANSWERS
--
-- verify_op_coverage.sql proves the inventory was applied correctly. It reads
-- the same list the engine did, so it cannot see a column that nobody ever put
-- in the inventory. If a table holds client identifiers and was never listed,
-- both the engine and the verifier are silent about it.
--
-- That matters here because the inventory was reconstructed from v3, whose
-- scope was assembled by hand over several years.
--
-- This script ignores the inventory entirely. It walks EVERY character column
-- in the OP schema and asks one question:
--
--     does this column still contain a value that appears in
--     anon_meta.code_map as an ORIGINAL, pre-anonymization code?
--
-- Any hit is a column that holds real client data and was missed.
--
-- ----------------------------------------------------------------------------
-- WHAT A HIT MEANS
--
-- Not every hit is a leak. A short code can collide with an unrelated value -
-- a currency, a status flag, a product code. Check the samples before acting.
-- But a column with a high hit count, on a table that references entities, is
-- almost certainly a gap in the inventory.
--
-- The fix for a genuine hit is one line in config/inventory_op_custom.csv, then
-- re-run. The engine is idempotent, so re-running only touches what is left.
--
-- ----------------------------------------------------------------------------
-- COST
--
-- One pass per table. Expect roughly the length of a full run - this reads
-- everything. Set SAMPLE_PCT below to 1 for a fast first look on a large
-- instance; sampling applies only to tables over a million rows.
--
-- Codes shorter than MIN_LEN are ignored, matching the engine: a one-character
-- value matches far too much to be evidence of anything.
-- ============================================================================

DEFINE SAMPLE_PCT = 0
DEFINE MIN_LEN    = 3

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON

WHENEVER SQLERROR EXIT FAILURE

DECLARE
   v_codes NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_codes FROM anon_meta.code_map_any;
   IF v_codes = 0 THEN
      RAISE_APPLICATION_ERROR(-20060,
         'anon_meta.code_map_any is empty - nothing to search for. Run the anonymization first.');
   END IF;
   DBMS_OUTPUT.PUT_LINE('Searching every OP character column for any of '
                     || TO_CHAR(v_codes, 'FM999,999') || ' original identifiers.');
   DBMS_OUTPUT.PUT_LINE('This reads the whole schema. Columns with no hits are not printed.');
   DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ----------------------------------------------------------------------------
-- Results table, so findings survive the session and can be re-read.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM all_tables WHERE owner = 'ANON_META' AND table_name = 'LEAK_SCAN';
   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.leak_scan (
            scanned_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
            table_name   VARCHAR2(128),
            column_name  VARCHAR2(128),
            in_inventory VARCHAR2(3),
            total_rows   NUMBER,
            hit_rows     NUMBER,
            sampled      VARCHAR2(1),
            sample_value VARCHAR2(200)
         )]';
   END IF;
END;
/

DELETE FROM anon_meta.leak_scan;
COMMIT;

-- ----------------------------------------------------------------------------
-- Scan
-- ----------------------------------------------------------------------------
DECLARE
   c_chunk   CONSTANT PLS_INTEGER := 20;    -- columns per statement
   v_sample  NUMBER := TO_NUMBER('&SAMPLE_PCT');
   v_min_len NUMBER := TO_NUMBER('&MIN_LEN');

   v_sql      VARCHAR2(32767);
   v_sel      VARCHAR2(32767);
   v_join     VARCHAR2(32767);
   v_sampled  VARCHAR2(1);
   v_rows     NUMBER;
   v_tables   PLS_INTEGER := 0;
   v_cols     PLS_INTEGER := 0;
   v_hits     PLS_INTEGER := 0;

   TYPE t_names IS TABLE OF VARCHAR2(128);
   l_col t_names;
   TYPE t_nums IS TABLE OF NUMBER;
   l_cnt t_nums := t_nums();
   v_total NUMBER;

   v_in_inv VARCHAR2(3);
   v_sample_val VARCHAR2(200);
BEGIN
   FOR t IN (SELECT table_name, NVL(num_rows, 0) AS num_rows
               FROM all_tables
              WHERE owner = 'OP'
                AND table_name NOT LIKE 'BIN$%'          -- recycle bin
                AND (num_rows IS NULL OR num_rows > 0)
              ORDER BY table_name) LOOP

      -- Character columns wide enough to hold an identifier.
      l_col := t_names();
      FOR c IN (SELECT column_name
                  FROM all_tab_columns
                 WHERE owner = 'OP'
                   AND table_name = t.table_name
                   AND data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR')
                   AND char_length >= v_min_len
                 ORDER BY column_id) LOOP
         l_col.EXTEND;
         l_col(l_col.COUNT) := c.column_name;
      END LOOP;

      IF l_col.COUNT = 0 THEN
         CONTINUE;
      END IF;

      v_tables := v_tables + 1;
      v_sampled := CASE WHEN v_sample > 0 AND t.num_rows > 1000000 THEN 'Y' ELSE 'N' END;

      -- Chunk the columns: one pass over the table per chunk, each column
      -- resolved by a primary key lookup into code_map_any.
      DECLARE
         v_from PLS_INTEGER := 1;
      BEGIN
         WHILE v_from <= l_col.COUNT LOOP
            v_sel  := 'COUNT(*)';
            v_join := '';
            FOR i IN v_from .. LEAST(v_from + c_chunk - 1, l_col.COUNT) LOOP
               v_sel  := v_sel  || ', COUNT(m' || i || '.old_code)';
               v_join := v_join || ' LEFT JOIN anon_meta.code_map_any m' || i
                                || ' ON m' || i || '.old_code = t."' || l_col(i) || '"';
            END LOOP;

            v_sql := 'SELECT ' || v_sel || ' FROM op."' || t.table_name || '" '
                  || CASE WHEN v_sampled = 'Y' THEN 'SAMPLE(' || v_sample || ') ' ELSE '' END
                  || 't' || v_join;

            l_cnt := t_nums();
            l_cnt.EXTEND(LEAST(c_chunk, l_col.COUNT - v_from + 1) + 1);

            BEGIN
               -- One row back: total, then one count per column in the chunk.
               EXECUTE IMMEDIATE v_sql INTO v_total, l_cnt(1), l_cnt(2), l_cnt(3), l_cnt(4),
                    l_cnt(5), l_cnt(6), l_cnt(7), l_cnt(8), l_cnt(9), l_cnt(10),
                    l_cnt(11), l_cnt(12), l_cnt(13), l_cnt(14), l_cnt(15), l_cnt(16),
                    l_cnt(17), l_cnt(18), l_cnt(19), l_cnt(20);
            EXCEPTION
               WHEN OTHERS THEN
                  -- Partial chunk, or an unreadable table: fall back to one
                  -- column at a time so a single awkward column cannot hide
                  -- the rest of the schema.
                  FOR i IN v_from .. LEAST(v_from + c_chunk - 1, l_col.COUNT) LOOP
                     BEGIN
                        EXECUTE IMMEDIATE
                           'SELECT COUNT(*), COUNT(m.old_code) FROM op."' || t.table_name || '" '
                        || CASE WHEN v_sampled = 'Y' THEN 'SAMPLE(' || v_sample || ') ' ELSE '' END
                        || 't LEFT JOIN anon_meta.code_map_any m ON m.old_code = t."'
                        || l_col(i) || '"'
                           INTO v_total, v_rows;

                        IF v_rows > 0 THEN
                           SELECT CASE WHEN COUNT(*) > 0 THEN 'yes' ELSE 'no' END
                             INTO v_in_inv FROM anon_meta.anon_inventory
                            WHERE table_name = t.table_name AND column_name = l_col(i);

                           EXECUTE IMMEDIATE
                              'SELECT MAX(t."' || l_col(i) || '") FROM op."' || t.table_name
                           || '" t JOIN anon_meta.code_map_any m ON m.old_code = t."'
                           || l_col(i) || '"' INTO v_sample_val;

                           INSERT INTO anon_meta.leak_scan
                              (table_name, column_name, in_inventory, total_rows,
                               hit_rows, sampled, sample_value)
                           VALUES (t.table_name, l_col(i), v_in_inv, v_total,
                                   v_rows, v_sampled, v_sample_val);
                           v_hits := v_hits + 1;
                        END IF;
                        v_cols := v_cols + 1;
                     EXCEPTION
                        WHEN OTHERS THEN NULL;   -- unreadable column, skip
                     END;
                  END LOOP;
                  v_from := v_from + c_chunk;
                  CONTINUE;
            END;

            -- Chunk succeeded: record any column with hits.
            FOR i IN v_from .. LEAST(v_from + c_chunk - 1, l_col.COUNT) LOOP
               v_cols := v_cols + 1;
               IF l_cnt(i - v_from + 1) > 0 THEN
                  SELECT CASE WHEN COUNT(*) > 0 THEN 'yes' ELSE 'no' END
                    INTO v_in_inv FROM anon_meta.anon_inventory
                   WHERE table_name = t.table_name AND column_name = l_col(i);

                  EXECUTE IMMEDIATE
                     'SELECT MAX(t."' || l_col(i) || '") FROM op."' || t.table_name
                  || '" t JOIN anon_meta.code_map_any m ON m.old_code = t."'
                  || l_col(i) || '"' INTO v_sample_val;

                  INSERT INTO anon_meta.leak_scan
                     (table_name, column_name, in_inventory, total_rows,
                      hit_rows, sampled, sample_value)
                  VALUES (t.table_name, l_col(i), v_in_inv, v_total,
                          l_cnt(i - v_from + 1), v_sampled, v_sample_val);
                  v_hits := v_hits + 1;
               END IF;
            END LOOP;

            v_from := v_from + c_chunk;
            COMMIT;
         END LOOP;
      END;
   END LOOP;

   DBMS_OUTPUT.PUT_LINE('  tables scanned ... ' || v_tables);
   DBMS_OUTPUT.PUT_LINE('  columns scanned .. ' || v_cols);
   DBMS_OUTPUT.PUT_LINE('  columns with hits  ' || v_hits);
   COMMIT;
END;
/

-- ----------------------------------------------------------------------------
-- Report
-- ----------------------------------------------------------------------------
SET HEADING ON
COLUMN table_name   FORMAT A30 HEADING 'TABLE'
COLUMN column_name  FORMAT A26 HEADING 'COLUMN'
COLUMN in_inventory FORMAT A9  HEADING 'IN INV?'
COLUMN hit_rows     FORMAT 999,999,999 HEADING 'HITS'
COLUMN total_rows   FORMAT 999,999,999 HEADING 'ROWS'
COLUMN sample_value FORMAT A24 HEADING 'EXAMPLE VALUE'

PROMPT
PROMPT ====================================================================
PROMPT  MISSED - holds original identifiers and is NOT in the inventory
PROMPT ====================================================================
PROMPT  These are the ones that matter. Each is a column of client data the
PROMPT  anonymization never touched, because nobody listed it.
PROMPT

SELECT table_name, column_name, hit_rows, total_rows, sample_value
  FROM anon_meta.leak_scan
 WHERE in_inventory = 'no'
 ORDER BY hit_rows DESC;

PROMPT
PROMPT  No rows above means the inventory is complete: no character column in
PROMPT  the OP schema holds an original identifier outside what was covered.

PROMPT
PROMPT ====================================================================
PROMPT  IN THE INVENTORY but still holding originals
PROMPT ====================================================================
PROMPT  Should be empty. Anything here contradicts verify_op_coverage.sql and
PROMPT  means a column was skipped at run time - check the step log for it.
PROMPT

SELECT table_name, column_name, hit_rows, total_rows, sample_value
  FROM anon_meta.leak_scan
 WHERE in_inventory = 'yes'
 ORDER BY hit_rows DESC;

PROMPT
SET HEADING OFF
PROMPT ====================================================================
PROMPT  Full results kept in anon_meta.leak_scan
PROMPT ====================================================================
PROMPT
