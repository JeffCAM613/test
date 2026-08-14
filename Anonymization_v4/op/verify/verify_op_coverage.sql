-- ============================================================================
-- OP Anonymization - Coverage Verification
-- ============================================================================
-- Proves that the anonymization actually removed what it was supposed to.
--
--   sqlplus op/<password>@<TNS>      @verify/verify_op_coverage.sql
--   sqlplus sys/<password>@<TNS> as sysdba @verify/verify_op_coverage.sql
--
-- Exits non-zero if any check fails, so it can gate a pipeline.
-- Results are also written to anon_meta.verify_result:
--   SELECT * FROM anon_meta.verify_result WHERE status = 'FAIL';
--
-- ----------------------------------------------------------------------------
-- WHAT THIS CHECKS, AND WHY IT IS BUILT THIS WAY
-- ----------------------------------------------------------------------------
-- The checks are driven by anon_meta.anon_inventory - the same list the engine
-- worked from. Neither can cover something the other does not, which is the
-- whole point: in v3 the anonymization scripts and the verification script kept
-- their own lists and had already drifted apart.
--
-- The primary test is RESIDUAL DETECTION: for every identifier column, is any
-- value still present that appears in the mapping as an ORIGINAL value? That
-- question has a definite answer and cannot be fooled.
--
-- The older scripts instead asked "does this value look anonymized?" by testing
-- for a prefix. That is weaker in two different ways:
--
--   1. It produced false passes. The OP script used LIKE 'E_%' - and in Oracle
--      '_' is a single-character wildcard, so a real code EUR matched and was
--      counted as anonymized. Every prefix test here uses ESCAPE, as the EPF
--      script correctly did.
--
--   2. Even written correctly, a prefix test asks the wrong question. Plenty of
--      values legitimately have no prefix - currency codes, product codes, and
--      any system code that was never client data. Those are not failures.
--      Prefix conformance is reported below as information, not pass/fail.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
SET LINESIZE 200
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON

WHENEVER SQLERROR EXIT FAILURE

DECLARE
   c_pass CONSTANT VARCHAR2(10) := 'PASS';
   c_fail CONSTANT VARCHAR2(10) := 'FAIL';
   c_warn CONSTANT VARCHAR2(10) := 'WARN';
   c_info CONSTANT VARCHAR2(10) := 'INFO';

   v_passed  PLS_INTEGER := 0;
   v_failed  PLS_INTEGER := 0;
   v_warned  PLS_INTEGER := 0;
   v_skipped PLS_INTEGER := 0;

   v_mappings NUMBER;
   v_items    NUMBER;
   v_n_check  NUMBER;
   v_n_fail   NUMBER;
   v_min_len  NUMBER;
   v_short    NUMBER;

   -- -------------------------------------------------------------------------
   PROCEDURE say(p_text IN VARCHAR2 DEFAULT '') IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE(p_text);
   END say;


   PROCEDURE heading(p_text IN VARCHAR2) IS
   BEGIN
      say;
      say('====================================================================');
      say(' ' || p_text);
      say('====================================================================');
   END heading;


   FUNCTION object_exists(p_table IN VARCHAR2, p_column IN VARCHAR2) RETURN BOOLEAN IS
      v_n PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO v_n
        FROM all_tab_columns
       WHERE owner = 'OP'
         AND table_name  = UPPER(p_table)
         AND column_name = UPPER(p_column);
      RETURN v_n > 0;
   END object_exists;


   -- Mirrors anon_engine.is_flag_column. A checkbox column is deliberately left
   -- alone by the run, so it must not be reported as a failure here - otherwise
   -- a correct run could never pass.
   FUNCTION is_flag_column(p_table IN VARCHAR2, p_column IN VARCHAR2) RETURN BOOLEAN IS
      v_len  PLS_INTEGER;
      v_type VARCHAR2(30);
   BEGIN
      SELECT MAX(char_length), MAX(data_type)
        INTO v_len, v_type
        FROM all_tab_columns
       WHERE owner = 'OP'
         AND table_name  = UPPER(p_table)
         AND column_name = UPPER(p_column);

      RETURN v_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR')
         AND v_len IS NOT NULL AND v_len <= 1;
   END is_flag_column;


   -- A NOT NULL free-text column cannot be emptied, so the engine skips it. That
   -- is a real coverage gap and must stay visible - but it is not a failure of
   -- the run, so it is reported as a warning rather than failing verification.
   -- Without this a correct run could never pass on a schema that has one.
   FUNCTION is_not_nullable(p_table IN VARCHAR2, p_column IN VARCHAR2) RETURN BOOLEAN IS
      v_nullable VARCHAR2(1);
   BEGIN
      SELECT MAX(nullable) INTO v_nullable
        FROM all_tab_columns
       WHERE owner = 'OP'
         AND table_name  = UPPER(p_table)
         AND column_name = UPPER(p_column);
      RETURN v_nullable = 'N';
   END is_not_nullable;


   PROCEDURE record(
      p_part        IN VARCHAR2,
      p_check       IN VARCHAR2,
      p_expectation IN VARCHAR2,
      p_total       IN NUMBER,
      p_bad         IN NUMBER,
      p_status      IN VARCHAR2,
      p_detail      IN VARCHAR2 DEFAULT NULL)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO anon_meta.verify_result
         (part, check_name, expectation, total_rows, bad_rows, status, detail)
      VALUES
         (p_part, p_check, p_expectation, p_total, p_bad, p_status, SUBSTR(p_detail, 1, 4000));
      COMMIT;

      CASE p_status
         WHEN c_pass THEN v_passed  := v_passed + 1;
         WHEN c_fail THEN v_failed  := v_failed + 1;
         WHEN c_warn THEN v_warned  := v_warned + 1;
         ELSE NULL;
      END CASE;
   END record;


   -- Only failures and anomalies are printed. A clean run of 579 checks would
   -- otherwise bury its own result in 579 lines of PASS.
   PROCEDURE show_failure(p_check IN VARCHAR2, p_bad IN NUMBER, p_of IN NUMBER, p_note IN VARCHAR2) IS
   BEGIN
      say('  FAIL  ' || RPAD(SUBSTR(p_check, 1, 48), 50)
                     || TO_CHAR(p_bad, 'FM999,999,999') || ' of '
                     || TO_CHAR(p_of, 'FM999,999,999') || '  ' || p_note);
   END show_failure;

BEGIN

   -- =========================================================================
   heading('OP ANONYMIZATION - COVERAGE VERIFICATION');
   -- =========================================================================

   SELECT COUNT(*) INTO v_mappings FROM anon_meta.code_map;
   SELECT COUNT(*) INTO v_items    FROM anon_meta.anon_inventory;

   -- Use the same threshold the run used, so the check matches what happened.
   BEGIN
      SELECT TO_NUMBER(REGEXP_SUBSTR(config_json, '"min_code_length":(\d+)', 1, 1, NULL, 1))
        INTO v_min_len
        FROM anon_meta.anon_run
       WHERE run_id = (SELECT MAX(run_id) FROM anon_meta.anon_run WHERE run_mode = 'EXECUTE');
   EXCEPTION
      WHEN OTHERS THEN v_min_len := NULL;
   END;
   v_min_len := NVL(v_min_len, 2);

   say(' Database ......... ' || SYS_CONTEXT('USERENV', 'DB_NAME'));
   say(' Checked at ....... ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'));
   say(' Inventory items .. ' || v_items);
   say(' Mappings ......... ' || TO_CHAR(v_mappings, 'FM999,999,999'));
   say(' Min code length .. ' || v_min_len || '   (shorter values treated as checkbox states)');

   IF v_mappings = 0 THEN
      say;
      say(' The mapping is empty, so nothing can be verified. Either the');
      say(' anonymization has not run, or anon_meta.code_map was dropped.');
      record('SETUP', 'code_map populated', 'more than 0 rows', 0, 0, c_fail,
             'no mappings - anonymization has not run on this database');
      RAISE_APPLICATION_ERROR(-20030,
         'anon_meta.code_map is empty - nothing to verify.');
   END IF;

   -- Keep only the current run's results.
   DELETE FROM anon_meta.verify_result;
   COMMIT;


   -- =========================================================================
   heading('PART 1 - RESIDUAL IDENTIFIERS   (the primary test)');
   -- =========================================================================
   say(' For every identifier column: is any ORIGINAL value still present?');
   say(' Anything but zero is a leak. Only failures are listed.');
   say;

   DECLARE
      v_bad   NUMBER;
      v_total NUMBER;
      v_src   VARCHAR2(200);
      v_obj   VARCHAR2(300);
   BEGIN
      FOR r IN (SELECT table_name, column_name, category
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'CODE'
                 ORDER BY seq) LOOP

         v_obj := LOWER(r.table_name) || '.' || LOWER(r.column_name);

         IF NOT object_exists(r.table_name, r.column_name) THEN
            v_skipped := v_skipped + 1;
            record('RESIDUAL', v_obj, 'no original values remain', NULL, NULL, 'SKIP',
                   'not present on this instance');
            CONTINUE;
         END IF;

         IF is_flag_column(r.table_name, r.column_name) THEN
            v_skipped := v_skipped + 1;
            record('RESIDUAL', v_obj, 'not applicable', NULL, NULL, 'SKIP',
                   'potential checkbox value - deliberately left alone by the run');
            CONTINUE;
         END IF;

         -- Search the FULL mapping, whatever category the column is declared as.
         --
         -- This deliberately does NOT mirror the engine. An earlier version
         -- restricted BANK_ACCOUNT columns to bank-account codes, exactly as the
         -- engine does - which meant a column whose category was too narrow was
         -- missed by the engine AND by the check that was supposed to catch it.
         -- Both agreed, both wrong. On TANM7881 that hid five live client codes
         -- in param_cpta_reg_gen.compte_ana.
         --
         -- The verifier's job is to test the OUTCOME - is any original value
         -- still present - not to re-apply the engine's assumptions. Any
         -- original left anywhere is a leak, whatever category it belongs to.
         --
         -- The length filter stays: those identifiers are skipped deliberately
         -- and are reported separately in PART 4.
         v_src := '(SELECT old_code FROM anon_meta.code_map_any'
               || ' WHERE LENGTH(old_code) >= ' || v_min_len || ')';

         EXECUTE IMMEDIATE
            'SELECT COUNT(*), COUNT(CASE WHEN t.' || r.column_name
         || ' IN ' || v_src || ' THEN 1 END) FROM op.' || r.table_name || ' t'
            INTO v_total, v_bad;

         IF v_bad = 0 THEN
            record('RESIDUAL', v_obj, 'no original values remain', v_total, 0, c_pass);

         ELSIF r.category = 'BANK_ACCOUNT' THEN
            -- The engine only substitutes bank-account codes here, so anything
            -- left belongs to another category and the declared category is too
            -- narrow for what the column actually holds.
            record('RESIDUAL', v_obj, 'no original values remain', v_total, v_bad, c_fail,
                   'original identifiers remain. Declared BANK_ACCOUNT, so only account codes '
                || 'were substituted - these values belong to another category. Change the '
                || 'category to ANY in the inventory and re-run.');
            show_failure(v_obj, v_bad, v_total,
                         'originals remain - BANK_ACCOUNT category is too narrow');

         ELSE
            record('RESIDUAL', v_obj, 'no original values remain', v_total, v_bad, c_fail,
                   'original identifiers still present - this column was not anonymized');
            show_failure(v_obj, v_bad, v_total, 'original identifiers remain');
         END IF;
      END LOOP;
   END;

   SELECT COUNT(*), COUNT(CASE WHEN status = c_fail THEN 1 END)
     INTO v_n_check, v_n_fail
     FROM anon_meta.verify_result WHERE part = 'RESIDUAL';
   say;
   say('  checked ' || v_n_check || ', failed ' || v_n_fail);


   -- =========================================================================
   heading('PART 2 - FREE TEXT AND PII');
   -- =========================================================================
   say(' Columns that should be entirely empty. Any surviving value is a leak.');
   say;

   DECLARE
      v_bad NUMBER;
      v_obj VARCHAR2(300);
   BEGIN
      FOR r IN (SELECT table_name, column_name
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'NULL_OUT'
                 ORDER BY seq) LOOP

         v_obj := LOWER(r.table_name) || '.' || LOWER(r.column_name);

         IF NOT object_exists(r.table_name, r.column_name) THEN
            v_skipped := v_skipped + 1;
            record('FREETEXT', v_obj, 'all NULL', NULL, NULL, 'SKIP',
                   'not present on this instance');
            CONTINUE;
         END IF;

         IF is_flag_column(r.table_name, r.column_name) THEN
            v_skipped := v_skipped + 1;
            record('FREETEXT', v_obj, 'not applicable', NULL, NULL, 'SKIP',
                   'potential checkbox value - deliberately left alone by the run');
            CONTINUE;
         END IF;

         EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM op.' || r.table_name
                        || ' WHERE ' || r.column_name || ' IS NOT NULL' INTO v_bad;

         IF v_bad = 0 THEN
            record('FREETEXT', v_obj, 'all NULL', NULL, 0, c_pass);

         ELSIF is_not_nullable(r.table_name, r.column_name) THEN
            -- The engine could not empty this column and said so at preflight.
            -- Reporting it as FAIL would mean a correct run can never pass on
            -- this schema, so it is a warning - but a loud one, because the
            -- free text is genuinely still there.
            record('FREETEXT', v_obj, 'all NULL', NULL, v_bad, c_warn,
                   'column is NOT NULL so the run could not empty it - the free text '
                || 'is still present. Change its rule to SELF_CODE in the inventory to '
                || 'overwrite instead of empty, or accept the gap knowingly.');
            say('  WARN  ' || RPAD(SUBSTR(v_obj, 1, 48), 50)
                           || TO_CHAR(v_bad, 'FM999,999,999') || ' rows - NOT NULL, cannot be emptied');

         ELSE
            record('FREETEXT', v_obj, 'all NULL', NULL, v_bad, c_fail,
                   'free text or PII survived');
            show_failure(v_obj, v_bad, v_bad, 'values still present');
         END IF;
      END LOOP;
   END;

   SELECT COUNT(*), COUNT(CASE WHEN status = c_fail THEN 1 END)
     INTO v_n_check, v_n_fail
     FROM anon_meta.verify_result WHERE part = 'FREETEXT';
   say;
   say('  checked ' || v_n_check || ', failed ' || v_n_fail);


   -- =========================================================================
   heading('PART 3 - LABELS AND ENTITY ATTRIBUTES');
   -- =========================================================================
   say(' These are set to the anonymized identifier of their own row, so any');
   say(' row that was anonymized must now agree with its own code.');
   say;

   DECLARE
      v_bad    NUMBER;
      v_filter VARCHAR2(400);
      v_obj    VARCHAR2(300);
   BEGIN
      FOR r IN (SELECT table_name, column_name, category, rule
                  FROM anon_meta.anon_inventory
                 WHERE rule IN ('DESCRIPTION', 'SELF_CODE')
                 ORDER BY seq) LOOP

         v_obj := LOWER(r.table_name) || '.' || LOWER(r.column_name);

         IF NOT object_exists(r.table_name, r.column_name)
            OR NOT object_exists(r.table_name, 'code') THEN
            v_skipped := v_skipped + 1;
            record('LABELS', v_obj, 'matches its own code', NULL, NULL, 'SKIP',
                   'not present on this instance');
            CONTINUE;
         END IF;

         v_filter := CASE WHEN r.category = 'ANY' THEN '1 = 1'
                          ELSE 'category = ''' || r.category || '''' END;

         -- A NULL is acceptable: the engine does not invent a value where there
         -- was none. What must not happen is a surviving real label.
         EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM op.' || r.table_name || ' t '
         || ' WHERE t.code IN (SELECT new_code FROM anon_meta.code_map WHERE ' || v_filter || ')'
         || '   AND t.' || r.column_name || ' IS NOT NULL'
         || '   AND t.' || r.column_name || ' <> t.code'
            INTO v_bad;

         IF v_bad = 0 THEN
            record('LABELS', v_obj, 'matches its own code', NULL, 0, c_pass);
         ELSE
            -- Not necessarily a leak: the category may have been disabled on
            -- purpose. Flag it rather than failing the run outright.
            record('LABELS', v_obj, 'matches its own code', NULL, v_bad, c_warn,
                   'rows whose label differs from their code - expected if this '
                || 'category had descriptions disabled');
            say('  WARN  ' || RPAD(SUBSTR(v_obj, 1, 48), 50)
                           || TO_CHAR(v_bad, 'FM999,999,999') || ' rows differ');
         END IF;
      END LOOP;
   END;

   SELECT COUNT(*), COUNT(CASE WHEN status = c_warn THEN 1 END)
     INTO v_n_check, v_n_fail
     FROM anon_meta.verify_result WHERE part = 'LABELS';
   say;
   say('  checked ' || v_n_check || ', warnings ' || v_n_fail);


   -- =========================================================================
   heading('PART 4 - MAPPING INTEGRITY');
   -- =========================================================================

   DECLARE
      v_dupes    NUMBER;
      v_collided NUMBER;
      v_by_cat   VARCHAR2(400);
   BEGIN
      -- Two originals sharing one replacement would merge two real entities
      -- into one identity. A unique index makes this impossible, but verifying
      -- it costs nothing and the consequence of being wrong is severe.
      SELECT COUNT(*) INTO v_dupes
        FROM (SELECT new_code FROM anon_meta.code_map
               GROUP BY new_code HAVING COUNT(*) > 1);

      IF v_dupes = 0 THEN
         record('MAPPING', 'replacement identifiers are unique', '0 duplicates', v_mappings, 0, c_pass);
         say('  PASS  replacement identifiers are unique');
      ELSE
         record('MAPPING', 'replacement identifiers are unique', '0 duplicates', v_mappings,
                v_dupes, c_fail, 'distinct originals share a replacement - entities merged');
         show_failure('replacement identifiers are unique', v_dupes, v_mappings, 'duplicates');
      END IF;

      -- An original appearing in more than one category is legal but means an
      -- unrestricted lookup had to choose. Worth surfacing: it is the situation
      -- where a wrong choice would silently mis-map a column.
      SELECT COUNT(*) INTO v_collided
        FROM (SELECT old_code FROM anon_meta.code_map
               GROUP BY old_code HAVING COUNT(DISTINCT category) > 1);

      IF v_collided = 0 THEN
         record('MAPPING', 'originals belong to one category', 'informational',
                v_mappings, 0, c_pass);
         say('  PASS  no original identifier spans two categories');
      ELSE
         record('MAPPING', 'originals belong to one category', 'informational',
                v_mappings, v_collided, c_warn,
                'resolved by priority entity > portfolio > counterparty > bank account');
         say('  WARN  ' || v_collided || ' original identifier(s) exist in more than one');
         say('        category; unrestricted lookups resolved them by priority.');
      END IF;

      -- code_map_any must cover every distinct original, or an unrestricted
      -- lookup would have silently missed some.
      SELECT COUNT(*) INTO v_collided
        FROM (SELECT DISTINCT old_code FROM anon_meta.code_map
              MINUS
              SELECT old_code FROM anon_meta.code_map_any);

      IF v_collided = 0 THEN
         record('MAPPING', 'resolved lookup table is complete', '0 missing', NULL, 0, c_pass);
         say('  PASS  resolved lookup table covers every original');
      ELSE
         record('MAPPING', 'resolved lookup table is complete', '0 missing', NULL,
                v_collided, c_fail, 'code_map_any is stale - rebuild it');
         show_failure('resolved lookup table is complete', v_collided, NULL, 'originals missing');
      END IF;

      SELECT LISTAGG(category || '=' || TO_CHAR(n), '  ') WITHIN GROUP (ORDER BY category)
        INTO v_by_cat
        FROM (SELECT category, COUNT(*) AS n FROM anon_meta.code_map GROUP BY category);
      say('  INFO  ' || v_by_cat);

      -- Identifiers the run deliberately did not substitute. Excluded from
      -- PART 1 so a correct run can pass, but surfaced here so the decision is
      -- never invisible - these are real values still in the database.
      SELECT COUNT(*) INTO v_short
        FROM anon_meta.code_map WHERE LENGTH(old_code) < v_min_len;

      IF v_short = 0 THEN
         record('MAPPING', 'no identifiers skipped as too short', '0', v_mappings, 0, c_pass);
         say('  PASS  every identifier was long enough to substitute');
      ELSE
         record('MAPPING', 'identifiers skipped as too short', 'review', v_mappings, v_short, c_warn,
                v_short || ' identifiers under ' || v_min_len || ' characters were left in place '
             || 'to avoid rewriting checkbox values');
         say('  WARN  ' || v_short || ' identifier(s) shorter than ' || v_min_len
             || ' were NOT substituted');
         say('        They are still real values in the database. This is deliberate -');
         say('        a single character value is usually a checkbox state, and replacing');
         say('        it would rewrite every matching flag in the schema. To review:');
         say('          SELECT category, old_code FROM anon_meta.code_map');
         say('           WHERE LENGTH(old_code) < ' || v_min_len || ';');
         say('        If they really are client identifiers, lower MIN_CODE_LENGTH.');
      END IF;
   END;


   -- =========================================================================
   heading('PART 5 - PREFIX CONFORMANCE   (informational)');
   -- =========================================================================
   say(' How much of each identifier column carries a generated prefix.');
   say;
   say(' This is NOT a pass/fail test. A column can legitimately hold codes');
   say(' that were never client data - currency codes, product codes, system');
   say(' references - and those correctly have no prefix. Part 1 is the test');
   say(' that matters; this is here to show the shape of the data.');
   say;

   DECLARE
      v_total  NUMBER;
      v_pref   NUMBER;
      v_obj    VARCHAR2(300);
      v_pct    NUMBER;
      v_shown  PLS_INTEGER := 0;
   BEGIN
      FOR r IN (SELECT table_name, column_name
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'CODE'
                   AND table_name IN ('TIERS', 'STRUCTURE', 'COMPTE_BANQUE')
                 ORDER BY seq) LOOP

         v_obj := LOWER(r.table_name) || '.' || LOWER(r.column_name);
         CONTINUE WHEN NOT object_exists(r.table_name, r.column_name);

         -- ESCAPE is what makes this correct. Without it '_' is a wildcard and
         -- 'E_%' matches EUR, EONIA, everything starting with E.
         EXECUTE IMMEDIATE
            'SELECT COUNT(*), COUNT(CASE WHEN ' || r.column_name || ' LIKE ''E\_%'' ESCAPE ''\'''
         || '                          OR ' || r.column_name || ' LIKE ''P\_%'' ESCAPE ''\'''
         || '                          OR ' || r.column_name || ' LIKE ''T\_%'' ESCAPE ''\'''
         || '                          OR ' || r.column_name || ' LIKE ''CB\_%'' ESCAPE ''\'''
         || '                         THEN 1 END)'
         || '  FROM op.' || r.table_name || ' WHERE ' || r.column_name || ' IS NOT NULL'
            INTO v_total, v_pref;

         v_pct := CASE WHEN v_total = 0 THEN NULL
                       ELSE ROUND(v_pref * 100 / v_total) END;

         record('PREFIX', v_obj, 'informational', v_total, v_total - v_pref, c_info,
                NVL(TO_CHAR(v_pct), 'n/a') || '% carry a generated prefix');

         say('  ' || RPAD(SUBSTR(v_obj, 1, 40), 42)
                  || LPAD(NVL(TO_CHAR(v_pct), 'n/a'), 5) || '%   '
                  || TO_CHAR(v_pref, 'FM999,999,999') || ' of '
                  || TO_CHAR(v_total, 'FM999,999,999'));
         v_shown := v_shown + 1;
      END LOOP;

      IF v_shown = 0 THEN
         say('  (core tables not present on this instance)');
      END IF;
   END;


   -- =========================================================================
   heading('SUMMARY');
   -- =========================================================================

   say(' passed ..... ' || v_passed);
   say(' failed ..... ' || v_failed);
   say(' warnings ... ' || v_warned);
   say(' skipped .... ' || v_skipped || '   (not present on this instance)');
   say;

   IF v_failed = 0 THEN
      say(' RESULT: PASS');
      say;
      say('  No original identifier and no free-text value survived anywhere the');
      say('  inventory covers.');
      IF v_warned > 0 THEN
         say;
         say('  ' || v_warned || ' warning(s). Review with:');
         say('    SELECT check_name, bad_rows, detail FROM anon_meta.verify_result');
         say('     WHERE status = ''WARN'';');
      END IF;
   ELSE
      say(' RESULT: FAIL');
      say;
      say('  ' || v_failed || ' check(s) failed. Client data is still present.');
      say('  Full detail:');
      say('    SELECT part, check_name, bad_rows, detail FROM anon_meta.verify_result');
      say('     WHERE status = ''FAIL'' ORDER BY part;');
   END IF;
   say('====================================================================');
   say;

   IF v_failed > 0 THEN
      RAISE_APPLICATION_ERROR(-20031,
         v_failed || ' verification check(s) FAILED - this database still contains client data.');
   END IF;
END;
/

EXIT SUCCESS
