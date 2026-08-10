-- ============================================================================
-- 10 - Metadata schema (anon_meta)
-- ============================================================================
-- Creates the schema that holds the code mapping, the loaded inventory and the
-- run log. Run as SYS.
--
-- IDEMPOTENT. Existing objects are kept, not recreated. This is deliberate and
-- is the fix for the worst defect in v3, which dropped the whole schema at the
-- start of every run: that regenerated the code mapping with fresh random
-- values, so a run that failed partway left renamed rows whose original values
-- could no longer be recovered. Here the mapping survives, and a re-run resumes
-- against it.
--
-- Parameters: &1 = data tablespace   &2 = index tablespace
-- ============================================================================

DEFINE tbs_data  = &1
DEFINE tbs_index = &2

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF

PROMPT
PROMPT === Metadata schema (anon_meta) ===

-- ----------------------------------------------------------------------------
-- Schema owner
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists FROM dba_users WHERE username = 'ANON_META';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE 'CREATE USER anon_meta IDENTIFIED BY anon_meta '
                     || 'DEFAULT TABLESPACE &tbs_data QUOTA UNLIMITED ON &tbs_data';
      DBMS_OUTPUT.PUT_LINE('  created user anon_meta');
   ELSE
      EXECUTE IMMEDIATE 'ALTER USER anon_meta QUOTA UNLIMITED ON &tbs_data';
      DBMS_OUTPUT.PUT_LINE('  user anon_meta already exists - kept');
   END IF;
END;
/

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE TO anon_meta;

-- ----------------------------------------------------------------------------
-- Privileges the engine needs. The engine is owned by OP and runs as OP, so it
-- must be able to read the dictionary and modify any OP table.
-- ----------------------------------------------------------------------------
GRANT SELECT ON sys.dba_users   TO op;
GRANT SELECT ON sys.dba_objects TO op;
GRANT SELECT ON sys.dba_tab_columns TO op;
GRANT CREATE PROCEDURE TO op;
GRANT SELECT ANY TABLE, INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE TO op;
GRANT ALTER ANY TRIGGER TO op;

-- ----------------------------------------------------------------------------
-- code_map - old identifier to new identifier.
--
-- THE most important table here. It is the only record of what the original
-- values were. It is never dropped by a run; drop it by hand once the copy has
-- been verified and handed over.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'CODE_MAP';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.code_map (
            category   VARCHAR2(20)  NOT NULL,
            old_code   VARCHAR2(80)  NOT NULL,
            new_code   VARCHAR2(80)  NOT NULL,
            created_at DATE DEFAULT SYSDATE NOT NULL,
            CONSTRAINT pk_code_map PRIMARY KEY (category, old_code)
               USING INDEX TABLESPACE &tbs_index
         ) TABLESPACE &tbs_data ]';

      -- Lookup path for every CODE update: WHERE old_code = <column value>
      EXECUTE IMMEDIATE 'CREATE INDEX anon_meta.ix_code_map_old '
                     || 'ON anon_meta.code_map(old_code) TABLESPACE &tbs_index';

      -- Uniqueness of the generated value is guaranteed by construction, but a
      -- constraint costs nothing and turns any generation bug into an immediate
      -- error rather than two entities silently sharing one identity.
      EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX anon_meta.ux_code_map_new '
                     || 'ON anon_meta.code_map(new_code) TABLESPACE &tbs_index';

      DBMS_OUTPUT.PUT_LINE('  created anon_meta.code_map');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.code_map already exists - PRESERVED');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- code_map_any - resolved mapping for lookups not restricted to one category.
--
-- The same code value can exist in two categories, so an unrestricted lookup is
-- ambiguous. v3 resolved that with ROWNUM = 1, which picks an arbitrary row and
-- can pick a different one on each evaluation. Here the winner is decided once,
-- by a fixed category priority, and stored - so the lookup during the run is a
-- primary key hit and the result is stable.
--
-- Rebuilt from code_map every run. Never edited by hand.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'CODE_MAP_ANY';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.code_map_any (
            old_code VARCHAR2(80) NOT NULL,
            new_code VARCHAR2(80) NOT NULL,
            CONSTRAINT pk_code_map_any PRIMARY KEY (old_code)
               USING INDEX TABLESPACE &tbs_index
         ) TABLESPACE &tbs_data ]';
      DBMS_OUTPUT.PUT_LINE('  created anon_meta.code_map_any');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.code_map_any already exists');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- anon_inventory - the loaded coverage definition.
--
-- Truncated and reloaded from the CSVs at the start of every run, so editing a
-- CSV is enough to change what happens. See config/inventory_op.csv.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'ANON_INVENTORY';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.anon_inventory (
            table_name  VARCHAR2(128) NOT NULL,
            column_name VARCHAR2(128) NOT NULL,
            rule        VARCHAR2(20)  NOT NULL,
            category    VARCHAR2(20)  NOT NULL,
            source      VARCHAR2(10)  DEFAULT 'BASE' NOT NULL,
            notes       VARCHAR2(500),
            seq         NUMBER,
            CONSTRAINT pk_anon_inventory PRIMARY KEY (table_name, column_name)
               USING INDEX TABLESPACE &tbs_index,
            CONSTRAINT ck_anon_inv_rule CHECK
               (rule IN ('CODE','NULL_OUT','DESCRIPTION','SELF_CODE')),
            CONSTRAINT ck_anon_inv_cat CHECK
               (category IN ('ANY','ENTITY','PORTFOLIO','COUNTERPARTY','BANK_ACCOUNT','NONE'))
         ) TABLESPACE &tbs_data ]';
      DBMS_OUTPUT.PUT_LINE('  created anon_meta.anon_inventory');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.anon_inventory already exists');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- anon_run - one row per run.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'ANON_RUN';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.anon_run (
            run_id       NUMBER        NOT NULL,
            mode         VARCHAR2(10)  NOT NULL,
            status       VARCHAR2(20)  NOT NULL,
            started_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
            finished_at  TIMESTAMP,
            db_name      VARCHAR2(30),
            os_user      VARCHAR2(60),
            config_json  VARCHAR2(2000),
            error_text   VARCHAR2(4000),
            CONSTRAINT pk_anon_run PRIMARY KEY (run_id)
               USING INDEX TABLESPACE &tbs_index,
            CONSTRAINT ck_anon_run_mode   CHECK (mode IN ('EXECUTE','DRYRUN')),
            CONSTRAINT ck_anon_run_status CHECK (status IN ('RUNNING','COMPLETED','FAILED'))
         ) TABLESPACE &tbs_data ]';
      EXECUTE IMMEDIATE 'CREATE SEQUENCE anon_meta.seq_anon_run START WITH 1 INCREMENT BY 1 NOCACHE';
      DBMS_OUTPUT.PUT_LINE('  created anon_meta.anon_run');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.anon_run already exists');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- anon_step_log - one row per inventory item per run.
--
-- Written by an autonomous transaction so entries appear immediately and
-- survive a rollback of the work they describe. This is what makes a run
-- observable from a second session while it is still going, and what makes a
-- failed run diagnosable afterwards.
--
-- status:
--   OK        applied, n rows changed
--   NOOP      applied, 0 rows changed - already clean, or nothing matched.
--             Worth looking at: on a column you expected to change, this is the
--             signal that the column name is wrong or the mapping is empty.
--             v3 printed nothing at all in this case.
--   SKIPPED   table or column does not exist here (ORA-00942 / ORA-00904)
--   DISABLED  excluded by configuration
--   DRYRUN    would have changed n rows; nothing was written
--   ERROR     anything else - the run fails
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'ANON_STEP_LOG';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.anon_step_log (
            run_id        NUMBER        NOT NULL,
            logged_at     TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
            phase         VARCHAR2(40)  NOT NULL,
            object_name   VARCHAR2(300),
            rule          VARCHAR2(20),
            status        VARCHAR2(20)  NOT NULL,
            rows_affected NUMBER,
            elapsed_ms    NUMBER,
            message       VARCHAR2(4000)
         ) TABLESPACE &tbs_data ]';
      EXECUTE IMMEDIATE 'CREATE INDEX anon_meta.ix_step_log_run '
                     || 'ON anon_meta.anon_step_log(run_id, logged_at) TABLESPACE &tbs_index';
      DBMS_OUTPUT.PUT_LINE('  created anon_meta.anon_step_log');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.anon_step_log already exists');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- verify_result - one row per verification check.
--
-- Written by op/verify/verify_op_coverage.sql. Kept so that a failure can be
-- queried afterwards rather than scraped out of terminal scrollback:
--   SELECT * FROM anon_meta.verify_result WHERE status = 'FAIL';
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists
     FROM dba_tables WHERE owner = 'ANON_META' AND table_name = 'VERIFY_RESULT';

   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE q'[
         CREATE TABLE anon_meta.verify_result (
            checked_at   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
            part         VARCHAR2(60) NOT NULL,
            check_name   VARCHAR2(300),
            expectation  VARCHAR2(200),
            total_rows   NUMBER,
            bad_rows     NUMBER,
            status       VARCHAR2(10) NOT NULL,
            detail       VARCHAR2(4000)
         ) TABLESPACE &tbs_data ]';
      DBMS_OUTPUT.PUT_LINE('  created anon_meta.verify_result');
   ELSE
      DBMS_OUTPUT.PUT_LINE('  anon_meta.verify_result already exists');
   END IF;
END;
/

-- ----------------------------------------------------------------------------
-- ref_tables_modif - compatibility view for the EPF pipeline.
--
-- EPF phase B reads atrace.ref_tables_modif to cascade OP renames into
-- OPPAYMENTS. Until EPF is ported (see epf/README.md) it still expects that
-- schema and shape, so expose the mapping in the old form rather than making
-- the EPF scripts a special case in the engine.
-- ----------------------------------------------------------------------------
DECLARE
   v_exists NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_exists FROM dba_users WHERE username = 'ATRACE';
   IF v_exists = 0 THEN
      EXECUTE IMMEDIATE 'CREATE USER atrace IDENTIFIED BY atrace '
                     || 'DEFAULT TABLESPACE &tbs_data QUOTA UNLIMITED ON &tbs_data';
      EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO atrace';
      DBMS_OUTPUT.PUT_LINE('  created user atrace (EPF compatibility)');
   END IF;
END;
/

CREATE OR REPLACE VIEW atrace.ref_tables_modif AS
SELECT CASE category WHEN 'BANK_ACCOUNT' THEN 'compte_banque' ELSE 'tiers' END AS table_name,
       'code'   AS field_name,
       old_code AS old_value,
       new_code AS new_value
  FROM anon_meta.code_map;

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.code_map        TO op;
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.code_map_any    TO op;
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.anon_inventory  TO op;
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.anon_run        TO op;
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.anon_step_log   TO op;
GRANT SELECT, INSERT, UPDATE, DELETE ON anon_meta.verify_result   TO op;
GRANT SELECT                          ON anon_meta.seq_anon_run   TO op;
GRANT SELECT                          ON atrace.ref_tables_modif  TO op;

PROMPT === Metadata schema ready ===
PROMPT
