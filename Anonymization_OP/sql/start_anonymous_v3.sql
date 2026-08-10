-- ============================================================================
-- OP Anonymization - Orchestrator (Set-Based)
-- ============================================================================
-- PURPOSE: Replaces legacy start_anonymous.sql. Uses set-based MERGE operations
-- instead of iterative pack_anonym calls.
--
-- PARAMETERS (33 positional - same interface as legacy script for bat compatibility):
-- &1 = ORACLE_SID (BASENAME)
-- &2 = SYS password
-- &3 = OP password
-- &4-&10 = Entite params (code, desc, anon1-5) [ignored]
-- &11-&17 = Portefeuille params (code, desc, anon1-5) [ignored]
-- &18-&24 = Tiers params (code, desc, anon1-5) [ignored]
-- &25-&31 = Compte params (code, desc, anon1-5) [ignored]
-- &32 = TBSDATA tablespace name
-- &33 = TBSINDEX tablespace name
-- ============================================================================

define BASENAME = &1
define SYSPASS = &2
define OPPASS = &3
define EntC = &4
define EntD = &5
define Ent1 = &6
define Ent2 = &7
define Ent3 = &8
define Ent4 = &9
define Ent5 = &10
define FoldC = &11
define FoldD = &12
define Fold1 = &13
define Fold2 = &14
define Fold3 = &15
define Fold4 = &16
define Fold5 = &17
define TierC = &18
define TierD = &19
define Tier1 = &20
define Tier2 = &21
define Tier3 = &22
define Tier4 = &23
define Tier5 = &24
define CpteC = &25
define CpteD = &26
define Cpte1 = &27
define Cpte2 = &28
define Cpte3 = &29
define Cpte4 = &30
define Cpte5 = &31
define TBSDATA = &32
define TBSINDEX = &33

conn sys/&SYSPASS@&BASENAME as sysdba; 
set echo off;
set verify off;
set feedback off;
set serveroutput on size unlimited;
spool logs\anonyme_op.log

-- ============================================================================
-- INFRASTRUCTURE SETUP
-- ============================================================================

-- Drop atrace if exists from prior run
BEGIN
 EXECUTE IMMEDIATE 'DROP USER atrace CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

grant select on sys.dba_users to op;
grant select on sys.dba_data_files to op;
grant select on sys.dba_objects to op;
alter system set optimizer_mode=first_rows;
alter system set undo_retention=28800;
alter user OP quota unlimited on &TBSDATA;

create user atrace identified by atrace default tablespace data quota unlimited on &TBSDATA;
grant create table to atrace;
grant create view to atrace;
grant create procedure to atrace;
grant create any table to op;
grant create any index to op;
grant create any view to op;
grant create any procedure to op;
grant drop any table to op;
grant drop any procedure to op;
grant select any table to op;
grant insert any table to op;
grant update any table to op;
grant delete any table to op;
create table atrace.ref_tables_modif(table_name varchar2(80),field_name varchar2(40), old_value varchar2(80), new_value varchar2(80));
create unique index op.ndx_anno on atrace.ref_tables_modif(table_name,field_name,old_value,new_value);
grant select on atrace.ref_tables_modif to op;
grant insert,update,delete on atrace.ref_tables_modif to op;

set termout off
connect op/&OPPASS@&BASENAME
set termout on
set echo off;
set verify off;
set feedback off;
set serveroutput on size unlimited;

-- ============================================================================
-- Create pack_anonym (used for trigger management)
-- ============================================================================
@sql\02pack_anonym_number.sql;

-- ============================================================================
-- DISABLE TRIGGERS (must happen before any data modification)
-- ============================================================================
execute pack_anonym.disable_enable_all_triggers('D');

-- ============================================================================
-- PHASE 1: Pre-clear histo table text fields
-- (Saves 6-8 hours on large instances by avoiding repeated full-table scans)
-- ============================================================================
@sql\05_op_performance_boost.sql;

-- ============================================================================
-- PHASE 2: Drop legacy indexes (frees space + avoids conflicts)
-- ============================================================================

PROMPT
PROMPT ====================================================================
PROMPT Phase 2: Dropping legacy indexes
PROMPT ====================================================================

DECLARE
 v_dropped NUMBER := 0;
 v_skipped NUMBER := 0;
 TYPE t_idx IS TABLE OF VARCHAR2(30);
 l_indexes t_idx := t_idx(
 'NDX_COMPTE_BQE_1', 'NDX_HIS_COURTAGE1',
 'NDX_HIS_FLX1', 'NDX_HIS_FLX2', 'NDX_HIS_FLX3',
 'NDX_HIS_LIV1', 'NDX_HIS_LIV2', 'NDX_HIS_LIV3',
 'NDX_HIS_MATIERE1', 'NDX_HIS_MATIERE2', 'NDX_HIS_MATIERE3',
 'NDX_HIS_MOUV_1',
 'NDX_HIS_OP_UP1', 'NDX_HIS_OP_UP2', 'NDX_HIS_OP_UP3', 'NDX_HIS_OP_UP4',
 'NDX_HIS_OP_UP5', 'NDX_HIS_OP_UP6', 'NDX_HIS_OP_UP7', 'NDX_HIS_OP_UP8',
 'NDX_HIS_OP_UP9', 'NDX_HIS_OP_UP10', 'NDX_HIS_OP_UP11', 'NDX_HIS_OP_UP12',
 'NDX_HIS_OP_UP13', 'NDX_HIS_OP_UP14', 'NDX_HIS_OP_UP15', 'NDX_HIS_OP_UP16',
 'NDX_HIS_OP_UP17', 'NDX_HIS_OP_UP18', 'NDX_HIS_OP_UP19', 'NDX_HIS_OP_UP20',
 'NDX_IMP_EVE1', 'NDX_IMP_EVE2', 'NDX_IMP_EVE3', 'NDX_IMP_EVE4', 'NDX_IMP_EVE5',
 'NDX_HIS_EV_UP1', 'NDX_HIS_EV_UP2', 'NDX_HIS_EV_UP3', 'NDX_HIS_EV_UP4', 'NDX_HIS_EV_UP5',
 'NDX_HIS_COMPTA_UP1', 'NDX_HIS_COMPTA_UP2', 'NDX_HIS_COMPTA_UP3', 'NDX_HIS_COMPTA_UP4',
 'NDX_HIS_REG_UP1', 'NDX_HIS_REG_UP2', 'NDX_HIS_REG_UP3', 'NDX_HIS_REG_UP4',
 'NDX_HIS_REG_UP5', 'NDX_HIS_REG_UP6', 'NDX_HIS_REG_UP7', 'NDX_HIS_REG_CPTY'
 );
BEGIN
 FOR i IN 1..l_indexes.COUNT LOOP
 BEGIN
 EXECUTE IMMEDIATE 'DROP INDEX ' || l_indexes(i);
 v_dropped := v_dropped + 1;
 EXCEPTION
 WHEN OTHERS THEN
 v_skipped := v_skipped + 1;
 END;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE(' Indexes dropped: ' || v_dropped || ' | Already absent: ' || v_skipped);
END;
/

-- ============================================================================
-- PHASE 3: Set-Based Code Anonymization
-- ============================================================================

PROMPT
PROMPT ====================================================================
PROMPT Phase 3: Set-Based Code Anonymization
PROMPT ====================================================================
PROMPT
VARIABLE v_op_phase3_start VARCHAR2(30)
BEGIN :v_op_phase3_start := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'); END;
/

set timing off
set serveroutput on size unlimited
@sql\06_op_setbased_anonym.sql &BASENAME &EntC &EntD &FoldC &FoldD &TierC &TierD &CpteC &CpteD &TBSDATA
set timing off

-- ============================================================================
-- PHASE 3B: KTP/CTI Tables Anonymization
-- ============================================================================

PROMPT
PROMPT ====================================================================
PROMPT Phase 3B: KTP/CTI Tables Anonymization
PROMPT ====================================================================
PROMPT

set serveroutput on size unlimited
@sql\07_ktp_cti_anonym.sql &EntC &FoldC &TierC &CpteC
set timing off

-- ============================================================================
-- PHASE 3C: CTI Tables Anonymization
-- ============================================================================

PROMPT
PROMPT ====================================================================
PROMPT Phase 3C: CTI Tables Anonymization
PROMPT ====================================================================
PROMPT

set serveroutput on size unlimited
@sql\08_cti_anonym.sql &EntC &FoldC &TierC &CpteC
set timing off

-- ============================================================================
-- PHASE 3D: Custom Inclusions (future extensions from inclusions.csv)
-- ============================================================================

PROMPT
PROMPT ====================================================================
PROMPT Phase 3D: Custom Inclusions (from inclusions.csv)
PROMPT ====================================================================
PROMPT

set serveroutput on size unlimited
@sql\09_inclusions_anonym.sql &EntC &FoldC &TierC &CpteC
set timing off

-- Cleanup: Drop merge_codes procedure (created by 06_op_setbased_anonym.sql)
BEGIN
 EXECUTE IMMEDIATE 'DROP PROCEDURE op.merge_codes';
 DBMS_OUTPUT.PUT_LINE(' merge_codes procedure dropped');
EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -4043 THEN NULL; -- already doesn't exist
 ELSE RAISE;
 END IF;
END;
/

-- Cleanup: Drop generate_unique_mappings procedure (created by 06_op_setbased_anonym.sql)
BEGIN
 EXECUTE IMMEDIATE 'DROP PROCEDURE op.generate_unique_mappings';
 DBMS_OUTPUT.PUT_LINE(' generate_unique_mappings procedure dropped');
EXCEPTION
 WHEN OTHERS THEN
 IF SQLCODE = -4043 THEN NULL; -- already doesn't exist
 ELSE RAISE;
 END IF;
END;
/

-- ============================================================================
-- PHASE 4: Cleanup + Re-enable Triggers
-- ============================================================================
set termout off
connect sys/&SYSPASS@&BASENAME as sysdba
set termout on
set echo off;
set verify off;
set feedback off;
set serveroutput on size unlimited;

PROMPT
PROMPT ====================================================================
PROMPT Phase 4: Cleanup (drop anon triggers, re-enable OP triggers)
PROMPT ====================================================================

-- Drop anon triggers IF they exist (from a prior partial run)
DECLARE
 v_dropped NUMBER := 0;
 v_skipped NUMBER := 0;
BEGIN
 FOR i IN 1..30 LOOP
 BEGIN
 EXECUTE IMMEDIATE 'DROP TRIGGER op.anon_' || i;
 v_dropped := v_dropped + 1;
 EXCEPTION
 WHEN OTHERS THEN
 v_skipped := v_skipped + 1;
 END;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE(' Anon triggers dropped: ' || v_dropped || ' | Already absent: ' || v_skipped);
END;
/

-- Re-enable all OP triggers (critical for normal application operation)
execute op.pack_anonym.disable_enable_all_triggers('E');

DECLARE
 v_elapsed NUMBER;
BEGIN
 v_elapsed := ROUND((CAST(SYSTIMESTAMP AS DATE) - TO_DATE(:v_op_phase3_start, 'YYYY-MM-DD HH24:MI:SS')) * 86400);
 DBMS_OUTPUT.PUT_LINE('');
 IF v_elapsed >= 3600 THEN
 DBMS_OUTPUT.PUT_LINE(' Total anonymization runtime: ' || TRUNC(v_elapsed/3600) || 'h ' || TRUNC(MOD(v_elapsed,3600)/60) || 'm ' || MOD(v_elapsed,60) || 's');
 ELSIF v_elapsed >= 60 THEN
 DBMS_OUTPUT.PUT_LINE(' Total anonymization runtime: ' || TRUNC(v_elapsed/60) || 'm ' || MOD(v_elapsed,60) || 's');
 ELSE
 DBMS_OUTPUT.PUT_LINE(' Total anonymization runtime: ' || v_elapsed || 's');
 END IF;
END;
/

PROMPT
PROMPT ====================================================================
PROMPT OP Anonymization COMPLETE
PROMPT ====================================================================

set echo off;
spool off;
EXIT;