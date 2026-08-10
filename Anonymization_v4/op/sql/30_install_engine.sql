-- ============================================================================
-- 30 - anon_engine package
-- ============================================================================
-- The whole anonymization engine. Everything it does is driven by
-- anon_meta.anon_inventory; there are no hardcoded table or column names.
--
-- Run as OP. The package is owned by OP so that it can modify OP tables under
-- definer rights without needing privileges granted through a role.
-- ============================================================================

SET DEFINE OFF
SET FEEDBACK OFF
SET ECHO OFF

CREATE OR REPLACE PACKAGE op.anon_engine AS

   -- Prefixes for generated identifiers. Kept from v3 so anonymized data looks
   -- the same as it always has.
   c_prefix_entity       CONSTANT VARCHAR2(4) := 'E_';
   c_prefix_portfolio    CONSTANT VARCHAR2(4) := 'P_';
   c_prefix_counterparty CONSTANT VARCHAR2(4) := 'T_';
   c_prefix_bank_account CONSTANT VARCHAR2(4) := 'CB_';

   -- Number of digits after the prefix. 7 gives room for 10M codes per
   -- category; widest generated value is CB_ + 7 = 10 characters.
   c_code_digits CONSTANT PLS_INTEGER := 7;

   -- Single-character columns are checkbox and flag columns in this schema -
   -- 'O'/'N' for oui/non, 'x' for ticked, and similar. Writing an anonymized
   -- code into one would corrupt application behaviour without concealing
   -- anything, so they are skipped and reported rather than treated as an error.
   --
   -- Deliberately 1 and not 2: a two-character column is narrow, but it can
   -- still hold a real code, and treating it as a checkbox would silently leave
   -- client data in place. Widening this trades a leak for a broken screen.
   c_flag_column_width CONSTANT PLS_INTEGER := 1;

   -- Tables at or above this row count get a PARALLEL hint. Below it the
   -- coordination overhead outweighs the benefit.
   c_parallel_threshold CONSTANT NUMBER := 100000;

   -- Set the run parameters. Flags are 'Y'/'N' (case-insensitive); anything
   -- that is not a yes is treated as no.
   PROCEDURE configure(
      p_mode                IN VARCHAR2,            -- EXECUTE | DRYRUN
      p_entity              IN VARCHAR2,
      p_portfolio           IN VARCHAR2,
      p_counterparty        IN VARCHAR2,
      p_bank_account        IN VARCHAR2,
      p_entity_desc         IN VARCHAR2,
      p_portfolio_desc      IN VARCHAR2,
      p_counterparty_desc   IN VARCHAR2,
      p_bank_account_desc   IN VARCHAR2,
      p_entity_attr         IN VARCHAR2 DEFAULT 'Y',
      p_portfolio_attr      IN VARCHAR2 DEFAULT 'Y',
      p_counterparty_attr   IN VARCHAR2 DEFAULT 'Y',
      p_bank_account_attr   IN VARCHAR2 DEFAULT 'Y',
      p_parallel_degree     IN VARCHAR2 DEFAULT '4',
      p_fail_on_missing     IN VARCHAR2 DEFAULT 'N',
      p_min_code_length     IN VARCHAR2 DEFAULT '2');

   PROCEDURE start_run;
   PROCEDURE finish_run(p_status IN VARCHAR2, p_error IN VARCHAR2 DEFAULT NULL);
   FUNCTION  current_run_id RETURN NUMBER;

   -- Resolve every inventory row against the data dictionary and check that
   -- generated codes fit. Raises if anything would make the run fail.
   -- A dry run stops after this.
   PROCEDURE preflight;

   -- Build the identifier mapping for the enabled categories.
   -- An existing mapping is REUSED, never regenerated - that is what makes a
   -- failed run resumable.
   PROCEDURE generate_code_map;

   -- Walk the inventory and apply it.
   PROCEDURE apply_inventory;

   PROCEDURE set_triggers(p_enable IN BOOLEAN);

   PROCEDURE print_summary;

END anon_engine;
/

SHOW ERRORS


CREATE OR REPLACE PACKAGE BODY op.anon_engine AS

   -- ---------------------------------------------------------------- state --
   g_run_id            NUMBER;
   g_mode              VARCHAR2(10) := 'DRYRUN';
   g_dry_run           BOOLEAN      := TRUE;
   g_cat_enabled       VARCHAR2(200);   -- categories whose codes are mapped
   g_desc_enabled      VARCHAR2(200);   -- categories whose descriptions are overwritten
   g_attr_enabled      VARCHAR2(200);   -- categories whose PII attributes are overwritten
   g_parallel_degree   PLS_INTEGER  := 4;
   g_fail_on_missing   BOOLEAN      := FALSE;
   g_min_code_length   PLS_INTEGER  := 2;

   g_count_ok          PLS_INTEGER := 0;
   g_count_noop        PLS_INTEGER := 0;
   g_count_skipped     PLS_INTEGER := 0;
   g_count_disabled    PLS_INTEGER := 0;
   g_count_error       PLS_INTEGER := 0;
   g_rows_total        NUMBER      := 0;


   -- =========================================================================
   -- Helpers
   -- =========================================================================

   FUNCTION is_yes(p_value IN VARCHAR2) RETURN BOOLEAN IS
   BEGIN
      RETURN UPPER(NVL(TRIM(p_value), 'N')) IN ('Y', 'YES', 'TRUE', '1', 'O');
   END is_yes;


   -- Log one step. Autonomous so entries are visible from another session while
   -- the run is still going, and survive a rollback of the work they describe.
   PROCEDURE log_step(
      p_phase   IN VARCHAR2,
      p_object  IN VARCHAR2,
      p_rule    IN VARCHAR2,
      p_status  IN VARCHAR2,
      p_rows    IN NUMBER   DEFAULT NULL,
      p_ms      IN NUMBER   DEFAULT NULL,
      p_message IN VARCHAR2 DEFAULT NULL)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO anon_meta.anon_step_log
         (run_id, phase, object_name, rule, status, rows_affected, elapsed_ms, message)
      VALUES
         (g_run_id, p_phase, p_object, p_rule, p_status, p_rows, p_ms, SUBSTR(p_message, 1, 4000));
      COMMIT;

      CASE p_status
         WHEN 'OK'       THEN g_count_ok       := g_count_ok + 1;
         WHEN 'NOOP'     THEN g_count_noop     := g_count_noop + 1;
         WHEN 'SKIPPED'  THEN g_count_skipped  := g_count_skipped + 1;
         WHEN 'DISABLED' THEN g_count_disabled := g_count_disabled + 1;
         WHEN 'ERROR'    THEN g_count_error    := g_count_error + 1;
         ELSE NULL;
      END CASE;

      g_rows_total := g_rows_total + NVL(p_rows, 0);
   END log_step;


   PROCEDURE say(p_text IN VARCHAR2) IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE(p_text);
   END say;


   -- Report one inventory item on screen in a fixed-width form so a long run
   -- stays readable.
   PROCEDURE report(p_object IN VARCHAR2, p_status IN VARCHAR2, p_rows IN NUMBER DEFAULT NULL) IS
      v_detail VARCHAR2(60);
   BEGIN
      v_detail := CASE
                     WHEN p_status = 'OK'     THEN TO_CHAR(p_rows, 'FM999,999,999') || ' rows'
                     WHEN p_status = 'DRYRUN' THEN TO_CHAR(p_rows, 'FM999,999,999') || ' rows would change'
                     WHEN p_status = 'NOOP'   THEN 'no rows matched'
                     ELSE ''
                  END;
      say('    ' || RPAD(SUBSTR(p_object, 1, 52), 54) || RPAD(p_status, 10) || v_detail);
   END report;


   FUNCTION column_exists(p_table IN VARCHAR2, p_column IN VARCHAR2) RETURN BOOLEAN IS
      v_count PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO v_count
        FROM all_tab_columns
       WHERE owner = 'OP'
         AND table_name  = UPPER(p_table)
         AND column_name = UPPER(p_column);
      RETURN v_count > 0;
   END column_exists;


   -- Deliberately resolved through all_tab_columns rather than all_tables: the
   -- inventory includes a few updatable views (vue_affilie_tiers,
   -- vue_affilie_compte), and all_tables does not list views, so an all_tables
   -- check would silently skip them.
   FUNCTION table_exists(p_table IN VARCHAR2) RETURN BOOLEAN IS
      v_count PLS_INTEGER;
   BEGIN
      SELECT COUNT(*) INTO v_count
        FROM all_tab_columns
       WHERE owner = 'OP' AND table_name = UPPER(p_table) AND ROWNUM = 1;
      RETURN v_count > 0;
   END table_exists;


   -- A checkbox or flag column: 'O'/'N' for oui/non, 'x' for ticked, and the
   -- like. Too narrow to hold any client identifier, and the application reads
   -- them as control values - writing an anonymized code or a NULL into one
   -- changes what the screen does, not what it reveals.
   --
   -- Detected by declared width rather than by inspecting values, so it costs
   -- nothing and is decided the same way in preflight and at run time.
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
         AND v_len IS NOT NULL
         AND v_len <= c_flag_column_width;
   END is_flag_column;


   -- PARALLEL hint, but only where it pays. Missing statistics are treated as
   -- "probably big" - the tables that matter here are the ones nobody has
   -- gathered stats on recently.
   FUNCTION parallel_hint(p_table IN VARCHAR2) RETURN VARCHAR2 IS
      v_rows NUMBER;
   BEGIN
      IF g_parallel_degree <= 1 THEN
         RETURN '';
      END IF;

      SELECT MAX(num_rows) INTO v_rows
        FROM all_tables
       WHERE owner = 'OP' AND table_name = UPPER(p_table);

      IF v_rows IS NULL OR v_rows >= c_parallel_threshold THEN
         RETURN '/*+ PARALLEL(' || g_parallel_degree || ') */ ';
      END IF;
      RETURN '';
   END parallel_hint;


   -- Quote a comma-separated category list for use in an IN clause.
   FUNCTION quoted_list(p_csv IN VARCHAR2) RETURN VARCHAR2 IS
      v_out VARCHAR2(400);
   BEGIN
      IF p_csv IS NULL THEN
         RETURN '''__NONE__''';          -- matches nothing
      END IF;

      SELECT LISTAGG('''' || part || '''', ',') WITHIN GROUP (ORDER BY lvl)
        INTO v_out
        FROM (SELECT LEVEL AS lvl,
                     TRIM(REGEXP_SUBSTR(p_csv, '[^,]+', 1, LEVEL)) AS part
                FROM dual
             CONNECT BY REGEXP_SUBSTR(p_csv, '[^,]+', 1, LEVEL) IS NOT NULL);

      RETURN NVL(v_out, '''__NONE__''');
   END quoted_list;


   FUNCTION elapsed_ms(p_start IN NUMBER) RETURN NUMBER IS
   BEGIN
      -- DBMS_UTILITY.GET_TIME counts hundredths of a second.
      RETURN (DBMS_UTILITY.GET_TIME - p_start) * 10;
   END elapsed_ms;


   -- =========================================================================
   -- Lifecycle
   -- =========================================================================

   PROCEDURE configure(
      p_mode                IN VARCHAR2,
      p_entity              IN VARCHAR2,
      p_portfolio           IN VARCHAR2,
      p_counterparty        IN VARCHAR2,
      p_bank_account        IN VARCHAR2,
      p_entity_desc         IN VARCHAR2,
      p_portfolio_desc      IN VARCHAR2,
      p_counterparty_desc   IN VARCHAR2,
      p_bank_account_desc   IN VARCHAR2,
      p_entity_attr         IN VARCHAR2 DEFAULT 'Y',
      p_portfolio_attr      IN VARCHAR2 DEFAULT 'Y',
      p_counterparty_attr   IN VARCHAR2 DEFAULT 'Y',
      p_bank_account_attr   IN VARCHAR2 DEFAULT 'Y',
      p_parallel_degree     IN VARCHAR2 DEFAULT '4',
      p_fail_on_missing     IN VARCHAR2 DEFAULT 'N',
      p_min_code_length     IN VARCHAR2 DEFAULT '2')
   IS
      PROCEDURE add(p_list IN OUT VARCHAR2, p_value IN VARCHAR2) IS
      BEGIN
         p_list := CASE WHEN p_list IS NULL THEN p_value ELSE p_list || ',' || p_value END;
      END add;
   BEGIN
      g_mode    := CASE WHEN UPPER(p_mode) = 'EXECUTE' THEN 'EXECUTE' ELSE 'DRYRUN' END;
      g_dry_run := (g_mode = 'DRYRUN');

      g_cat_enabled  := NULL;
      g_desc_enabled := NULL;
      g_attr_enabled := NULL;

      IF is_yes(p_entity)       THEN add(g_cat_enabled, 'ENTITY');       END IF;
      IF is_yes(p_portfolio)    THEN add(g_cat_enabled, 'PORTFOLIO');    END IF;
      IF is_yes(p_counterparty) THEN add(g_cat_enabled, 'COUNTERPARTY'); END IF;
      IF is_yes(p_bank_account) THEN add(g_cat_enabled, 'BANK_ACCOUNT'); END IF;

      -- Descriptions and attributes are gated separately, as they were in the
      -- original vendor package: EntD controlled the description, Ent1-Ent5
      -- controlled the extra attribute columns, and either could be used
      -- without the other.
      --
      -- Both still require the category itself to be enabled, because both
      -- write the row's anonymized code and without a mapping there is no such
      -- code to write.
      IF is_yes(p_entity)       AND is_yes(p_entity_desc)       THEN add(g_desc_enabled, 'ENTITY');       END IF;
      IF is_yes(p_portfolio)    AND is_yes(p_portfolio_desc)    THEN add(g_desc_enabled, 'PORTFOLIO');    END IF;
      IF is_yes(p_counterparty) AND is_yes(p_counterparty_desc) THEN add(g_desc_enabled, 'COUNTERPARTY'); END IF;
      IF is_yes(p_bank_account) AND is_yes(p_bank_account_desc) THEN add(g_desc_enabled, 'BANK_ACCOUNT'); END IF;

      IF is_yes(p_entity)       AND is_yes(p_entity_attr)       THEN add(g_attr_enabled, 'ENTITY');       END IF;
      IF is_yes(p_portfolio)    AND is_yes(p_portfolio_attr)    THEN add(g_attr_enabled, 'PORTFOLIO');    END IF;
      IF is_yes(p_counterparty) AND is_yes(p_counterparty_attr) THEN add(g_attr_enabled, 'COUNTERPARTY'); END IF;
      IF is_yes(p_bank_account) AND is_yes(p_bank_account_attr) THEN add(g_attr_enabled, 'BANK_ACCOUNT'); END IF;

      g_parallel_degree := GREATEST(1, LEAST(32, TO_NUMBER(NVL(TRIM(p_parallel_degree), '4'))));
      g_fail_on_missing := is_yes(p_fail_on_missing);
      g_min_code_length := GREATEST(1, TO_NUMBER(NVL(TRIM(p_min_code_length), '2')));

      IF g_cat_enabled IS NULL THEN
         RAISE_APPLICATION_ERROR(-20010,
            'No category is enabled. Set at least one ANONYMIZE_* flag to y in the config file, '
         || 'otherwise this run would do nothing.');
      END IF;
   END configure;


   PROCEDURE start_run IS
   BEGIN
      SELECT anon_meta.seq_anon_run.NEXTVAL INTO g_run_id FROM dual;

      INSERT INTO anon_meta.anon_run (run_id, mode, status, db_name, os_user, config_json)
      VALUES (g_run_id, g_mode, 'RUNNING',
              SYS_CONTEXT('USERENV', 'DB_NAME'),
              SYS_CONTEXT('USERENV', 'OS_USER'),
              '{"categories":"'  || g_cat_enabled
           || '","descriptions":"' || NVL(g_desc_enabled, '')
           || '","attributes":"'   || NVL(g_attr_enabled, '')
           || '","parallel":'       || g_parallel_degree
           || ',"min_code_length":' || g_min_code_length || '}');
      COMMIT;

      say('');
      say('  Run id .............. ' || g_run_id);
      say('  Mode ................ ' || g_mode ||
          CASE WHEN g_dry_run THEN '   (no changes will be made)' ELSE '' END);
      say('  Categories .......... ' || g_cat_enabled);
      say('  Descriptions ........ ' || NVL(g_desc_enabled, '(none)'));
      say('  PII attributes ...... ' || NVL(g_attr_enabled, '(none)'));
      say('  Parallel degree ..... ' || g_parallel_degree);
      say('');
   END start_run;


   PROCEDURE finish_run(p_status IN VARCHAR2, p_error IN VARCHAR2 DEFAULT NULL) IS
   BEGIN
      UPDATE anon_meta.anon_run
         SET status      = p_status,
             finished_at = SYSTIMESTAMP,
             error_text  = SUBSTR(p_error, 1, 4000)
       WHERE run_id = g_run_id;
      COMMIT;
   END finish_run;


   FUNCTION current_run_id RETURN NUMBER IS
   BEGIN
      RETURN g_run_id;
   END current_run_id;


   -- =========================================================================
   -- Preflight
   -- =========================================================================

   PROCEDURE preflight IS
      v_missing_table  PLS_INTEGER := 0;
      v_missing_column PLS_INTEGER := 0;
      v_too_narrow     PLS_INTEGER := 0;
      v_wrong_type     PLS_INTEGER := 0;
      v_not_nullable   PLS_INTEGER := 0;
      v_checkbox       PLS_INTEGER := 0;
      v_short_codes    PLS_INTEGER := 0;
      v_ok             PLS_INTEGER := 0;
      v_width          PLS_INTEGER;
      v_type           VARCHAR2(30);
      v_nullable       VARCHAR2(1);
      v_needed         PLS_INTEGER;
      v_object         VARCHAR2(300);
   BEGIN
      say('  --- Preflight -------------------------------------------------');

      -- Widest identifier this run can generate.
      v_needed := LENGTH(c_prefix_bank_account) + c_code_digits;

      FOR r IN (SELECT table_name, column_name, rule, category
                  FROM anon_meta.anon_inventory
                 ORDER BY seq) LOOP

         v_object := LOWER(r.table_name) || '.' || LOWER(r.column_name);

         IF NOT table_exists(r.table_name) THEN
            v_missing_table := v_missing_table + 1;
            log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL, 'table not found');

         ELSIF NOT column_exists(r.table_name, r.column_name) THEN
            v_missing_column := v_missing_column + 1;
            log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL, 'column not found');

         ELSE
            -- A column that will receive a generated identifier has to be able
            -- to hold one: character typed, and wide enough. v3 checked
            -- neither, so a mismatch surfaced as ORA-12899 or ORA-01722
            -- partway through a run that could not then be resumed.
            IF r.rule IN ('CODE', 'DESCRIPTION', 'SELF_CODE') THEN
               SELECT MAX(char_length), MAX(data_type)
                 INTO v_width, v_type
                 FROM all_tab_columns
                WHERE owner = 'OP'
                  AND table_name  = UPPER(r.table_name)
                  AND column_name = UPPER(r.column_name);

               -- DESCRIPTION and SELF_CODE copy the row's own code column, so
               -- an older schema without one cannot support them.
               IF r.rule IN ('DESCRIPTION', 'SELF_CODE')
                  AND NOT column_exists(r.table_name, 'code') THEN
                  v_missing_column := v_missing_column + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL,
                           'table has no code column to copy from');

               -- Checked before the width test, because a checkbox column is
               -- "too narrow" in the literal sense but is not an error - it is
               -- a column that must be left alone.
               ELSIF is_flag_column(r.table_name, r.column_name) THEN
                  v_checkbox := v_checkbox + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL,
                           'potential checkbox value - ' || v_type || '(' || v_width
                        || ') holds control values such as O/N/x, not identifiers');
                  say('    CHECKBOX    ' || v_object || '  (' || v_type || '('
                      || v_width || ')) - will be left alone');

               ELSIF v_type NOT IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
                  v_wrong_type := v_wrong_type + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'ERROR', NULL, NULL,
                           'column is ' || v_type || '; a generated identifier is text');
                  say('    WRONG TYPE  ' || v_object || '  (' || v_type || ')');

               ELSIF v_width < v_needed THEN
                  v_too_narrow := v_too_narrow + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'ERROR', NULL, NULL,
                           'column holds ' || v_width || ' chars; generated identifiers need up to '
                        || v_needed);
                  say('    TOO NARROW  ' || v_object || '  (' || v_width || ' < ' || v_needed || ')');

               ELSE
                  v_ok := v_ok + 1;
               END IF;

            ELSE
               -- NULL_OUT. A NOT NULL column cannot be emptied, so the PII in
               -- it would survive the run. Older schemas sometimes made columns
               -- mandatory that later versions relaxed, so this is reported
               -- rather than fatal - but it is a real coverage gap and the
               -- verifier will fail on it, so it cannot pass unnoticed.
               IF is_flag_column(r.table_name, r.column_name) THEN
                  v_checkbox := v_checkbox + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL,
                           'potential checkbox value - not erased');
                  say('    CHECKBOX    ' || v_object || ' - will be left alone');
                  CONTINUE;
               END IF;

               SELECT MAX(nullable) INTO v_nullable
                 FROM all_tab_columns
                WHERE owner = 'OP'
                  AND table_name  = UPPER(r.table_name)
                  AND column_name = UPPER(r.column_name);

               IF v_nullable = 'N' THEN
                  v_not_nullable := v_not_nullable + 1;
                  log_step('PREFLIGHT', v_object, r.rule, 'SKIPPED', NULL, NULL,
                           'column is NOT NULL so it cannot be emptied - PII would survive');
                  say('    NOT NULL    ' || v_object || '  (cannot be emptied)');
               ELSE
                  v_ok := v_ok + 1;
               END IF;
            END IF;
         END IF;
      END LOOP;

      -- Codes too short to be substituted safely. Reported so that a site with
      -- genuinely short identifiers can lower MIN_CODE_LENGTH rather than
      -- silently leaving them in place.
      SELECT COUNT(*) INTO v_short_codes
        FROM anon_meta.code_map
       WHERE LENGTH(old_code) < g_min_code_length;

      say('    resolved .......... ' || v_ok);
      say('    missing tables .... ' || v_missing_table);
      say('    missing columns ... ' || v_missing_column);
      say('    checkbox columns .. ' || v_checkbox || '   (left alone)');
      say('    too narrow ........ ' || v_too_narrow);
      say('    wrong type ........ ' || v_wrong_type);
      say('    not nullable ...... ' || v_not_nullable);
      say('');

      IF v_short_codes > 0 THEN
         say('    ' || v_short_codes || ' identifier(s) are shorter than ' || g_min_code_length
             || ' characters and will NOT be');
         say('    substituted. A single character value is a checkbox state far more');
         say('    often than a client identifier, and replacing it would rewrite every');
         say('    matching flag in the schema. If these really are client identifiers,');
         say('    lower MIN_CODE_LENGTH in anonymization.ini and re-run. To see them:');
         say('      SELECT category, old_code FROM anon_meta.code_map');
         say('       WHERE LENGTH(old_code) < ' || g_min_code_length || ';');
         say('');
      END IF;

      IF v_not_nullable > 0 THEN
         say('    ' || v_not_nullable || ' free-text column(s) are NOT NULL and will be left as they');
         say('    are. Change their rule to SELF_CODE in the inventory if the value');
         say('    must be overwritten rather than emptied.');
         say('');
      END IF;

      IF v_too_narrow + v_wrong_type > 0 THEN
         RAISE_APPLICATION_ERROR(-20011,
            (v_too_narrow + v_wrong_type) || ' column(s) cannot hold a generated identifier '
         || '(' || v_too_narrow || ' too narrow, ' || v_wrong_type || ' wrong type). '
         || 'Nothing has been changed. The list is in anon_meta.anon_step_log: '
         || 'SELECT object_name, message FROM anon_meta.anon_step_log '
         || 'WHERE run_id = ' || g_run_id || ' AND status = ''ERROR'';');
      END IF;

      IF g_fail_on_missing AND (v_missing_table + v_missing_column) > 0 THEN
         RAISE_APPLICATION_ERROR(-20012,
            (v_missing_table + v_missing_column) || ' inventory item(s) do not exist on this '
         || 'instance and FAIL_ON_MISSING_OBJECT=y. Nothing has been changed.');
      END IF;
   END preflight;


   -- =========================================================================
   -- Mapping generation
   -- =========================================================================

   PROCEDURE generate_one_category(
      p_category IN VARCHAR2,
      p_prefix   IN VARCHAR2,
      p_source   IN VARCHAR2)
   IS
      v_existing PLS_INTEGER;
      v_created  PLS_INTEGER;
      v_start    NUMBER := DBMS_UTILITY.GET_TIME;
   BEGIN
      IF INSTR(',' || g_cat_enabled || ',', ',' || p_category || ',') = 0 THEN
         log_step('MAPPING', p_category, 'CODE', 'DISABLED');
         report(p_category, 'DISABLED');
         RETURN;
      END IF;

      SELECT COUNT(*) INTO v_existing FROM anon_meta.code_map WHERE category = p_category;

      -- Reuse. Regenerating would orphan every value already written by an
      -- earlier run - the defect that made v3 unrecoverable after a failure.
      IF v_existing > 0 THEN
         log_step('MAPPING', p_category, 'CODE', 'NOOP', v_existing, elapsed_ms(v_start),
                  'existing mapping reused');
         say('    ' || RPAD(p_category, 54) || RPAD('REUSED', 10)
                    || TO_CHAR(v_existing, 'FM999,999,999') || ' existing mappings');
         RETURN;
      END IF;

      IF g_dry_run THEN
         -- Count exactly what the real statement would insert: distinct,
         -- non-null. A plain COUNT(*) would overstate it wherever the source
         -- query returns a code more than once.
         EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM (SELECT DISTINCT code FROM ('
                        || p_source || ') WHERE code IS NOT NULL)' INTO v_created;
         log_step('MAPPING', p_category, 'CODE', 'DRYRUN', v_created, elapsed_ms(v_start));
         report(p_category, 'DRYRUN', v_created);
         RETURN;
      END IF;

      -- Deterministic and set-based: uniqueness comes from ROW_NUMBER, so there
      -- is no collision probe and no retry loop, and the same input always
      -- produces the same mapping.
      EXECUTE IMMEDIATE
         'INSERT INTO anon_meta.code_map (category, old_code, new_code) '
      || 'SELECT ''' || p_category || ''', src_code, '''
      ||    p_prefix || ''' || LPAD(ROW_NUMBER() OVER (ORDER BY src_code), '
      ||    c_code_digits || ', ''0'') '
      || '  FROM (SELECT DISTINCT code AS src_code FROM (' || p_source || ') WHERE code IS NOT NULL)';

      v_created := SQL%ROWCOUNT;
      COMMIT;

      log_step('MAPPING', p_category, 'CODE',
               CASE WHEN v_created > 0 THEN 'OK' ELSE 'NOOP' END,
               v_created, elapsed_ms(v_start));
      report(p_category, CASE WHEN v_created > 0 THEN 'OK' ELSE 'NOOP' END, v_created);
   END generate_one_category;


   PROCEDURE generate_code_map IS
      v_total   PLS_INTEGER;
      v_missing VARCHAR2(400);
   BEGIN
      say('  --- Identifier mapping ----------------------------------------');

      -- The four source queries below reference these directly. Everything else
      -- in the engine tolerates a missing object, but if the schema cannot even
      -- describe its own entities there is nothing to anonymize - so say which
      -- piece is absent rather than letting a raw ORA-00942 surface from inside
      -- a dynamic statement.
      IF NOT column_exists('structure', 'code')            THEN v_missing := v_missing || ' structure.code';            END IF;
      IF NOT column_exists('structure', 'structure')       THEN v_missing := v_missing || ' structure.structure';       END IF;
      IF NOT column_exists('structure', 'ecran')           THEN v_missing := v_missing || ' structure.ecran';           END IF;
      IF NOT column_exists('tiers', 'code')                THEN v_missing := v_missing || ' tiers.code';                END IF;
      IF NOT column_exists('tiers', 'flag_portefeuille')   THEN v_missing := v_missing || ' tiers.flag_portefeuille';   END IF;
      IF NOT column_exists('compte_banque', 'code')        THEN v_missing := v_missing || ' compte_banque.code';        END IF;

      IF v_missing IS NOT NULL THEN
         RAISE_APPLICATION_ERROR(-20013,
            'The core entity tables are not shaped as expected on this instance. Missing:'
         || v_missing || '. Identifiers are derived from these, so nothing can be mapped. '
         || 'Nothing has been changed.');
      END IF;

      generate_one_category('ENTITY', c_prefix_entity,
         q'[SELECT s.code FROM op.structure s JOIN op.tiers t ON t.code = s.code
             WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'N']');

      generate_one_category('PORTFOLIO', c_prefix_portfolio,
         q'[SELECT s.code FROM op.structure s JOIN op.tiers t ON t.code = s.code
             WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'O']');

      generate_one_category('COUNTERPARTY', c_prefix_counterparty,
         q'[SELECT code FROM op.structure WHERE structure = 'Compte' AND ecran = 'w_tiers']');

      generate_one_category('BANK_ACCOUNT', c_prefix_bank_account,
         q'[SELECT code FROM op.compte_banque]');

      IF g_dry_run THEN
         say('');
         RETURN;
      END IF;

      -- code_map_any resolves a lookup that is not restricted to one category.
      --
      -- The same code value can exist in more than one category, so an
      -- unrestricted lookup is ambiguous. v3 resolved it with ROWNUM = 1, which
      -- picks an arbitrary row and can pick a different one each time. Here the
      -- winner is chosen once, by a fixed priority, and materialised - which
      -- also means the per-row lookup is a primary key hit rather than an
      -- analytic function evaluated repeatedly.
      DELETE FROM anon_meta.code_map_any;
      INSERT INTO anon_meta.code_map_any (old_code, new_code)
      SELECT old_code, new_code
        FROM (SELECT old_code, new_code,
                     ROW_NUMBER() OVER (
                        PARTITION BY old_code
                        ORDER BY CASE category
                                    WHEN 'ENTITY'       THEN 1
                                    WHEN 'PORTFOLIO'    THEN 2
                                    WHEN 'COUNTERPARTY' THEN 3
                                    ELSE 4
                                 END) AS rn
                FROM anon_meta.code_map)
       WHERE rn = 1;
      COMMIT;

      SELECT COUNT(*) INTO v_total FROM anon_meta.code_map;
      say('    ' || RPAD('total', 54) || RPAD('', 10) || TO_CHAR(v_total, 'FM999,999,999') || ' mappings');
      say('');
   END generate_code_map;


   -- =========================================================================
   -- Applying the inventory
   -- =========================================================================

   -- One CODE column: substitute mapped identifiers.
   PROCEDURE apply_code(p_table IN VARCHAR2, p_column IN VARCHAR2, p_category IN VARCHAR2) IS
      v_object VARCHAR2(300) := LOWER(p_table) || '.' || LOWER(p_column);
      v_start  NUMBER := DBMS_UTILITY.GET_TIME;
      v_sql    VARCHAR2(4000);
      v_source VARCHAR2(200);
      v_rows   NUMBER;
   BEGIN
      IF NOT column_exists(p_table, p_column) THEN
         log_step('CODE', v_object, 'CODE', 'SKIPPED', NULL, NULL, 'object not found');
         report(v_object, 'SKIPPED');
         RETURN;
      END IF;

      IF is_flag_column(p_table, p_column) THEN
         log_step('CODE', v_object, 'CODE', 'SKIPPED', NULL, NULL,
                  'potential checkbox value - column is too narrow to hold an identifier');
         report(v_object, 'CHECKBOX');
         RETURN;
      END IF;

      -- BANK_ACCOUNT columns must look only at bank account codes. Without the
      -- restriction, a value that also exists as a counterparty code would be
      -- rewritten using the counterparty mapping.
      --
      -- The length filter keeps very short codes out of the substitution
      -- entirely. A single-character value is a checkbox state far more often
      -- than it is a client identifier, and substituting it would rewrite every
      -- 'O' and 'x' in the schema that happens to match.
      --
      -- This is the second line of defence. The first is is_flag_column above,
      -- which excludes whole columns by declared width; this one catches a
      -- checkbox value sitting in a column too wide to be recognised that way.
      IF p_category = 'BANK_ACCOUNT' THEN
         v_source := '(SELECT old_code, new_code FROM anon_meta.code_map '
                  || ' WHERE category = ''BANK_ACCOUNT'''
                  || '   AND LENGTH(old_code) >= ' || g_min_code_length || ')';
      ELSE
         v_source := '(SELECT old_code, new_code FROM anon_meta.code_map_any '
                  || ' WHERE LENGTH(old_code) >= ' || g_min_code_length || ')';
      END IF;

      IF g_dry_run THEN
         v_sql := 'SELECT COUNT(*) FROM op.' || p_table || ' t '
               || 'WHERE t.' || p_column || ' IN (SELECT old_code FROM ' || v_source || ')';
         EXECUTE IMMEDIATE v_sql INTO v_rows;
         log_step('CODE', v_object, 'CODE', 'DRYRUN', v_rows, elapsed_ms(v_start));
         report(v_object, 'DRYRUN', v_rows);
         RETURN;
      END IF;

      -- A correlated UPDATE rather than a MERGE: MERGE cannot update a column
      -- that appears in its ON clause (ORA-38104).
      v_sql := 'UPDATE ' || parallel_hint(p_table) || 'op.' || p_table || ' t '
            || '   SET t.' || p_column || ' = (SELECT m.new_code FROM ' || v_source || ' m '
            || '                                WHERE m.old_code = t.' || p_column || ') '
            || ' WHERE t.' || p_column || ' IN (SELECT old_code FROM ' || v_source || ')';

      EXECUTE IMMEDIATE v_sql;
      v_rows := SQL%ROWCOUNT;
      COMMIT;

      log_step('CODE', v_object, 'CODE',
               CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows, elapsed_ms(v_start));
      report(v_object, CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows);

   EXCEPTION
      WHEN OTHERS THEN
         log_step('CODE', v_object, 'CODE', 'ERROR', NULL, elapsed_ms(v_start), SQLERRM);
         say('    ERROR on ' || v_object || ': ' || SQLERRM);
         RAISE;
   END apply_code;


   -- All NULL_OUT columns of one table, in a single statement.
   --
   -- Grouping matters: histo_reglement has four such columns and is one of the
   -- largest tables in the schema. Four separate statements would mean four
   -- full scans.
   PROCEDURE apply_null_out(p_table IN VARCHAR2) IS
      v_start    NUMBER := DBMS_UTILITY.GET_TIME;
      v_set      VARCHAR2(4000);
      v_where    VARCHAR2(4000);
      v_cols     VARCHAR2(1000);
      v_sql      VARCHAR2(8000);
      v_rows     NUMBER;
      v_present  PLS_INTEGER := 0;
      v_object   VARCHAR2(300);
      v_nullable VARCHAR2(1);
   BEGIN
      IF NOT table_exists(p_table) THEN
         FOR r IN (SELECT column_name FROM anon_meta.anon_inventory
                    WHERE table_name = p_table AND rule = 'NULL_OUT') LOOP
            log_step('NULL_OUT', LOWER(p_table) || '.' || LOWER(r.column_name), 'NULL_OUT',
                     'SKIPPED', NULL, NULL, 'table not found');
         END LOOP;
         report(LOWER(p_table) || '.*', 'SKIPPED');
         RETURN;
      END IF;

      FOR r IN (SELECT column_name FROM anon_meta.anon_inventory
                 WHERE table_name = p_table AND rule = 'NULL_OUT'
                 ORDER BY seq) LOOP

         IF NOT column_exists(p_table, r.column_name) THEN
            log_step('NULL_OUT', LOWER(p_table) || '.' || LOWER(r.column_name), 'NULL_OUT',
                     'SKIPPED', NULL, NULL, 'column not found');
            CONTINUE;
         END IF;

         -- Emptying a checkbox column changes what the application does without
         -- concealing anything: 'O' and 'x' are control values, not client data.
         IF is_flag_column(p_table, r.column_name) THEN
            log_step('NULL_OUT', LOWER(p_table) || '.' || LOWER(r.column_name), 'NULL_OUT',
                     'SKIPPED', NULL, NULL, 'potential checkbox value - not erased');
            CONTINUE;
         END IF;

         -- Leaving a NOT NULL column out of the statement rather than letting
         -- the UPDATE fail with ORA-01407 and take the whole run with it.
         -- Preflight has already reported this; the verifier will fail on the
         -- column, so the gap is visible rather than silent.
         SELECT MAX(nullable) INTO v_nullable
           FROM all_tab_columns
          WHERE owner = 'OP'
            AND table_name  = UPPER(p_table)
            AND column_name = UPPER(r.column_name);

         IF v_nullable = 'N' THEN
            log_step('NULL_OUT', LOWER(p_table) || '.' || LOWER(r.column_name), 'NULL_OUT',
                     'SKIPPED', NULL, NULL, 'column is NOT NULL - cannot be emptied');
            CONTINUE;
         END IF;

         v_present := v_present + 1;
         v_set   := v_set   || CASE WHEN v_set   IS NULL THEN '' ELSE ', ' END
                            || r.column_name || ' = NULL';
         v_where := v_where || CASE WHEN v_where IS NULL THEN '' ELSE ' OR ' END
                            || r.column_name || ' IS NOT NULL';
         v_cols  := v_cols  || CASE WHEN v_cols  IS NULL THEN '' ELSE ',' END
                            || LOWER(r.column_name);
      END LOOP;

      IF v_present = 0 THEN
         RETURN;
      END IF;

      v_object := LOWER(p_table) || '.[' || v_cols || ']';

      IF g_dry_run THEN
         EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM op.' || p_table || ' WHERE ' || v_where INTO v_rows;
         log_step('NULL_OUT', v_object, 'NULL_OUT', 'DRYRUN', v_rows, elapsed_ms(v_start));
         report(v_object, 'DRYRUN', v_rows);
         RETURN;
      END IF;

      v_sql := 'UPDATE ' || parallel_hint(p_table) || 'op.' || p_table
            || ' SET ' || v_set || ' WHERE ' || v_where;

      EXECUTE IMMEDIATE v_sql;
      v_rows := SQL%ROWCOUNT;
      COMMIT;

      log_step('NULL_OUT', v_object, 'NULL_OUT',
               CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows, elapsed_ms(v_start));
      report(v_object, CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows);

   EXCEPTION
      WHEN OTHERS THEN
         log_step('NULL_OUT', v_object, 'NULL_OUT', 'ERROR', NULL, elapsed_ms(v_start), SQLERRM);
         say('    ERROR on ' || v_object || ': ' || SQLERRM);
         RAISE;
   END apply_null_out;


   -- DESCRIPTION and SELF_CODE columns of one table sharing one category, in a
   -- single statement.
   --
   -- Both rules do the same thing: set the column to the anonymized identifier
   -- of the row itself. By this point the code column already holds the new
   -- value, so the assignment is simply "column = code" - no lookup needed.
   PROCEDURE apply_self_code(
      p_table    IN VARCHAR2,
      p_category IN VARCHAR2,
      p_rule     IN VARCHAR2)
   IS
      v_start   NUMBER := DBMS_UTILITY.GET_TIME;
      v_set     VARCHAR2(4000);
      v_needs_change VARCHAR2(4000);
      v_cols    VARCHAR2(1000);
      v_filter  VARCHAR2(400);
      v_gate    VARCHAR2(200);
      v_sql     VARCHAR2(8000);
      v_rows    NUMBER;
      v_present PLS_INTEGER := 0;
      v_object  VARCHAR2(300);
   BEGIN
      v_object := LOWER(p_table) || '.[' || LOWER(p_rule) || '/' || LOWER(p_category) || ']';

      IF NOT table_exists(p_table) OR NOT column_exists(p_table, 'code') THEN
         log_step(p_rule, v_object, p_rule, 'SKIPPED', NULL, NULL,
                  'table or its code column not found');
         report(v_object, 'SKIPPED');
         RETURN;
      END IF;

      -- DESCRIPTION and SELF_CODE are gated by different flags, mirroring the
      -- original EntD versus Ent1-Ent5 split.
      v_gate := CASE WHEN p_rule = 'SELF_CODE' THEN g_attr_enabled ELSE g_desc_enabled END;

      IF p_category = 'ANY' THEN
         IF v_gate IS NULL THEN
            log_step(p_rule, v_object, p_rule, 'DISABLED');
            report(v_object, 'DISABLED');
            RETURN;
         END IF;
         v_filter := 'category IN (' || quoted_list(v_gate) || ')';
      ELSE
         IF INSTR(',' || NVL(v_gate, '') || ',', ',' || p_category || ',') = 0 THEN
            log_step(p_rule, v_object, p_rule, 'DISABLED');
            report(v_object, 'DISABLED');
            RETURN;
         END IF;
         v_filter := 'category = ''' || p_category || '''';
      END IF;

      FOR r IN (SELECT column_name FROM anon_meta.anon_inventory
                 WHERE table_name = p_table AND rule = p_rule AND category = p_category
                 ORDER BY seq) LOOP

         IF NOT column_exists(p_table, r.column_name) THEN
            log_step(p_rule, LOWER(p_table) || '.' || LOWER(r.column_name), p_rule,
                     'SKIPPED', NULL, NULL, 'column not found');
            CONTINUE;
         END IF;

         -- tiers.flag_pp is the case this exists for: a natural-person checkbox
         -- that the old config.ini listed as an anonymizable attribute. Writing
         -- P_0000123 into it would break the screen and conceal nothing.
         IF is_flag_column(p_table, r.column_name) THEN
            log_step(p_rule, LOWER(p_table) || '.' || LOWER(r.column_name), p_rule,
                     'SKIPPED', NULL, NULL, 'potential checkbox value - not overwritten');
            CONTINUE;
         END IF;

         v_present := v_present + 1;
         v_set := v_set || CASE WHEN v_set IS NULL THEN '' ELSE ', ' END
                        || 't.' || r.column_name || ' = t.code';

         -- "This column still needs changing", OR-joined across the columns of
         -- the statement. Two jobs:
         --
         --   SELF_CODE leaves an already-empty column empty - a NULL phone
         --   number is not PII and filling it in would invent data.
         --
         --   Both rules exclude rows already holding the right value, so a
         --   re-run reports NOOP instead of rewriting every row to what it
         --   already says. That is what makes re-running after a failure cheap
         --   as well as safe.
         IF p_rule = 'SELF_CODE' THEN
            v_needs_change := v_needs_change
                           || CASE WHEN v_needs_change IS NULL THEN '' ELSE ' OR ' END
                           || '(t.' || r.column_name || ' IS NOT NULL AND t.'
                           || r.column_name || ' <> t.code)';
         ELSE
            v_needs_change := v_needs_change
                           || CASE WHEN v_needs_change IS NULL THEN '' ELSE ' OR ' END
                           || '(t.' || r.column_name || ' IS NULL OR t.'
                           || r.column_name || ' <> t.code)';
         END IF;

         v_cols := v_cols || CASE WHEN v_cols IS NULL THEN '' ELSE ',' END
                          || LOWER(r.column_name);
      END LOOP;

      IF v_present = 0 THEN
         RETURN;
      END IF;

      v_object := LOWER(p_table) || '.[' || v_cols || ']';

      -- Only rows that were actually anonymized: a code still absent from the
      -- mapping belongs to a system row that must keep its real label.
      v_sql := ' FROM op.' || p_table || ' t'
            || ' WHERE t.code IN (SELECT new_code FROM anon_meta.code_map WHERE ' || v_filter || ')'
            || CASE WHEN v_needs_change IS NOT NULL THEN ' AND (' || v_needs_change || ')' ELSE '' END;

      IF g_dry_run THEN
         EXECUTE IMMEDIATE 'SELECT COUNT(*)' || v_sql INTO v_rows;
         log_step(p_rule, v_object, p_rule, 'DRYRUN', v_rows, elapsed_ms(v_start));
         report(v_object, 'DRYRUN', v_rows);
         RETURN;
      END IF;

      v_sql := 'UPDATE ' || parallel_hint(p_table) || 'op.' || p_table || ' t SET ' || v_set
            || ' WHERE t.code IN (SELECT new_code FROM anon_meta.code_map WHERE ' || v_filter || ')'
            || CASE WHEN v_needs_change IS NOT NULL THEN ' AND (' || v_needs_change || ')' ELSE '' END;

      EXECUTE IMMEDIATE v_sql;
      v_rows := SQL%ROWCOUNT;
      COMMIT;

      log_step(p_rule, v_object, p_rule,
               CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows, elapsed_ms(v_start));
      report(v_object, CASE WHEN v_rows > 0 THEN 'OK' ELSE 'NOOP' END, v_rows);

   EXCEPTION
      WHEN OTHERS THEN
         log_step(p_rule, v_object, p_rule, 'ERROR', NULL, elapsed_ms(v_start), SQLERRM);
         say('    ERROR on ' || v_object || ': ' || SQLERRM);
         RAISE;
   END apply_self_code;


   PROCEDURE apply_inventory IS
   BEGIN
      -- Order is not arbitrary.
      --
      -- 1. NULL_OUT first. Clearing the free text on the big history tables up
      --    front is what keeps the whole run inside 20-40 minutes.
      -- 2. CODE second.
      -- 3. DESCRIPTION and SELF_CODE last: they read the code column, which
      --    only holds its new value once step 2 has run.

      say('  --- Free text and PII -----------------------------------------');
      FOR t IN (SELECT table_name, MIN(seq) AS seq
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'NULL_OUT'
                 GROUP BY table_name
                 ORDER BY MIN(seq)) LOOP
         apply_null_out(t.table_name);
      END LOOP;
      say('');

      say('  --- Identifiers -----------------------------------------------');
      FOR r IN (SELECT table_name, column_name, category
                  FROM anon_meta.anon_inventory
                 WHERE rule = 'CODE'
                 ORDER BY seq) LOOP
         apply_code(r.table_name, r.column_name, r.category);
      END LOOP;
      say('');

      say('  --- Labels and entity attributes ------------------------------');
      FOR g IN (SELECT table_name, category, rule, MIN(seq) AS seq
                  FROM anon_meta.anon_inventory
                 WHERE rule IN ('DESCRIPTION', 'SELF_CODE')
                 GROUP BY table_name, category, rule
                 ORDER BY MIN(seq)) LOOP
         apply_self_code(g.table_name, g.category, g.rule);
      END LOOP;
      say('');
   END apply_inventory;


   -- =========================================================================
   -- Triggers
   -- =========================================================================

   PROCEDURE set_triggers(p_enable IN BOOLEAN) IS
      v_action  VARCHAR2(10) := CASE WHEN p_enable THEN 'ENABLE' ELSE 'DISABLE' END;
      v_done    PLS_INTEGER := 0;
      v_failed  PLS_INTEGER := 0;
      v_start   NUMBER := DBMS_UTILITY.GET_TIME;
   BEGIN
      FOR t IN (SELECT trigger_name FROM all_triggers WHERE owner = 'OP') LOOP
         BEGIN
            EXECUTE IMMEDIATE 'ALTER TRIGGER op."' || t.trigger_name || '" ' || v_action;
            v_done := v_done + 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_failed := v_failed + 1;
         END;
      END LOOP;

      log_step('TRIGGERS', v_action, NULL,
               CASE WHEN v_failed = 0 THEN 'OK' ELSE 'NOOP' END,
               v_done, elapsed_ms(v_start),
               CASE WHEN v_failed > 0 THEN v_failed || ' could not be altered' END);

      say('    triggers ' || LOWER(v_action) || 'd: ' || v_done
          || CASE WHEN v_failed > 0 THEN '   (' || v_failed || ' failed)' ELSE '' END);
   END set_triggers;


   -- =========================================================================
   -- Summary
   -- =========================================================================

   PROCEDURE print_summary IS
      v_elapsed NUMBER;
   BEGIN
      SELECT NVL(SUM(elapsed_ms), 0) / 1000 INTO v_elapsed
        FROM anon_meta.anon_step_log WHERE run_id = g_run_id;

      say('');
      say('  ==============================================================');
      say('   Run ' || g_run_id || ' summary (' || g_mode || ')');
      say('  ==============================================================');
      say('    applied ........... ' || g_count_ok);
      say('    no rows matched ... ' || g_count_noop);
      say('    skipped ........... ' || g_count_skipped || '   (not present on this instance)');
      say('    disabled .......... ' || g_count_disabled || '   (excluded by configuration)');
      say('    errors ............ ' || g_count_error);
      say('    rows affected ..... ' || TO_CHAR(g_rows_total, 'FM999,999,999,999'));
      say('    step time ......... ' || TO_CHAR(ROUND(v_elapsed), 'FM999,999') || 's');
      say('  ==============================================================');

      IF g_count_noop > 0 THEN
         say('');
         say('    ' || g_count_noop || ' item(s) matched no rows. That is expected for a');
         say('    column that was already clean, but on a column you expected to');
         say('    change it means the name is wrong or the mapping is empty:');
         say('      SELECT object_name FROM anon_meta.anon_step_log');
         say('       WHERE run_id = ' || g_run_id || ' AND status = ''NOOP'';');
      END IF;
      say('');
   END print_summary;

END anon_engine;
/

SHOW ERRORS

SET DEFINE ON
