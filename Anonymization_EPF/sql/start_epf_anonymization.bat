@echo off
setlocal enabledelayedexpansion

REM ========================================================================
REM DRY RUN MODE: Pass /dryrun to preview without executing SQL
REM ========================================================================
set DRYRUN=0
for %%A in (%*) do (
 if /I "%%~A"=="/dryrun" set DRYRUN=1
)

cls
set ROOT=%~dp0

echo.
echo ====================================================================
echo EPF/OPPAYMENTS Database Anonymization Script
echo ====================================================================
if %DRYRUN%==1 (
echo.
echo *** DRY RUN MODE - No database changes will be made ***
)
echo.
echo This script anonymizes OPPAYMENTS schema data:
echo - Code fields (cascaded from OP tiers/compte_banque mappings)
echo - BIC/SWIFT components (bank, country, location, branch codes)
echo - Payment amounts (nominal_1/2, bulk totals)
echo - User identifiers (admin_user + 15 cascade tables)
echo - Free-text fields (beneficiary desc, addresses, comments)
echo - Reference data (REF_TIERS, REF_BANK_BRANCHE)
echo - SWIFT message fields (83J company names)
echo - Audit trail (IP addresses)
echo - OP schema BIC/BBAN gap fix
echo.
echo PREREQUISITE: OP anonymization must be completed FIRST.
echo The EPF code cascade (Phase B) relies on atrace.ref_tables_modif
echo being populated by the OP pack_anonym procedure.
echo.
echo ====================================================================
echo.

:Credentials
if defined ORACLE_SID (
 echo [inherited] ORACLE_SID = !ORACLE_SID!
) else (
 set /P ORACLE_SID=Enter DB Oracle SID:
)
if "!ORACLE_SID!" == "" (
 echo ERROR: You did not capture a valid database name
 goto end
)

if defined SYSPWD (
 echo [inherited] SYS password set
) else (
 set /P SYSPWD=Enter Password for SYS:
)
if "!SYSPWD!" == "" (
 echo ERROR: You did not capture a valid password for SYS
 goto end
)

if defined OPPWD (
 echo [inherited] OP password set
) else (
 set /P OPPWD=Enter Password for OP:
)
if "!OPPWD!" == "" (
 echo ERROR: You did not capture a valid password for OP
 goto end
)

if defined EPFPWD (
 echo [inherited] OPPAYMENTS password set
) else (
 set /P EPFPWD=Enter Password for OPPAYMENTS:
)
if "!EPFPWD!" == "" (
 echo ERROR: You did not capture a valid password for OPPAYMENTS
 goto end
)

if defined TBSDATA (
 echo [inherited] TBSDATA = !TBSDATA!
) else (
 set /P TBSDATA=Enter tablespace name for DATA:
)
if "!TBSDATA!" == "" (
 echo ERROR: You did not capture a valid tablespace name for DATA
 goto end
)

if defined TBSINDEX (
 echo [inherited] TBSINDEX = !TBSINDEX!
) else (
 set /P TBSINDEX=Enter tablespace name for INDEX:
)
if "!TBSINDEX!" == "" (
 echo ERROR: You did not capture a valid tablespace name for INDEX
 goto end
)

echo.
echo ====================================================================
echo Configuration Summary
echo ====================================================================
echo Database SID: %ORACLE_SID%
echo Data TBS: %TBSDATA%
echo Index TBS: %TBSINDEX%
echo ====================================================================
echo.

REM Skip confirmation if running in inherited/orchestrated mode (parent already confirmed)
if defined EPF_AUTO_CONFIRM (
 echo [auto] Skipping confirmation - running in orchestrated mode.
 goto run_epf
)
set /P CONFIRM=Proceed with EPF anonymization? (y/n):
if /I "%CONFIRM%" NEQ "y" goto end

:run_epf
cd /D "%ROOT%"

REM ========================================================================
REM DRY RUN MODE: Show row counts and exit without executing
REM ========================================================================
if %DRYRUN%==1 (
 echo.
 echo ====================================================================
 echo [DRY RUN] EPF ANONYMIZATION PLAN
 echo ====================================================================
 echo.
 echo SQL Files to Execute ^(in order^):
 echo.
 echo Phase A - Code Cascades ^(from OP mappings^):
 echo - sql\anonymize_epf_itr1.sql
 echo - sql\anonymize_epf_itr2.sql
 echo.
 echo Phase B - Reference Data:
 echo - sql\anonymize_epf_phase7_refdata.sql
 echo.
 echo Phase C - SWIFT/Audit:
 echo - sql\anonymize_epf_phase8_swift_audit.sql
 echo.
 echo Phase D - BIC/BBAN Fix:
 echo - sql\anonymize_epf_phase9_op_bic_bban.sql
 echo.
 echo BIC Component Scripts:
 echo - sql\bic\1_Anonymize_Bank_Codes.sql
 echo - sql\bic\2_Anonymize_Country_Codes.sql
 echo - sql\bic\3_Anonymize_Location_Codes.sql
 echo - sql\bic\4_Anonymize_Branch_Codes.sql
 echo - sql\bic\5_Anonymize_payment_amounts.sql
 echo.
 echo Fetching row counts from database...
 echo.
 
 REM Build temp SQL file for row counts
 set "DRYRUN_SQLFILE=%TEMP%\epf_dryrun_%RANDOM%.sql"
 
 echo SET PAGESIZE 0 FEEDBACK OFF HEADING OFF > "!DRYRUN_SQLFILE!"
 echo SELECT ' admin_user: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.admin_user; >> "!DRYRUN_SQLFILE!"
 echo SELECT ' payment: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.payment; >> "!DRYRUN_SQLFILE!"
 echo SELECT ' bulk_payment: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.bulk_payment; >> "!DRYRUN_SQLFILE!"
 echo SELECT ' payment_audit: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.payment_audit; >> "!DRYRUN_SQLFILE!"
 echo SELECT ' approbation_group_users: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.approbation_group_users; >> "!DRYRUN_SQLFILE!"
 echo SELECT ' ref_tiers: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM oppayments.ref_tiers; >> "!DRYRUN_SQLFILE!"
 echo EXIT; >> "!DRYRUN_SQLFILE!"
 
 sqlplus -S op/!OPPWD!@!ORACLE_SID! @"!DRYRUN_SQLFILE!"
 
 echo.
 echo Checking OP mapping prerequisites...
 echo.
 
 REM Build temp SQL file for prerequisite check (handles missing table gracefully)
 set "PREREQ_SQLFILE=%TEMP%\epf_prereq_%RANDOM%.sql"
 
 echo SET PAGESIZE 0 FEEDBACK OFF HEADING OFF SERVEROUTPUT ON > "!PREREQ_SQLFILE!"
 echo DECLARE >> "!PREREQ_SQLFILE!"
 echo v_count NUMBER; >> "!PREREQ_SQLFILE!"
 echo v_exists NUMBER; >> "!PREREQ_SQLFILE!"
 echo BEGIN >> "!PREREQ_SQLFILE!"
 echo SELECT COUNT^(*^) INTO v_exists FROM all_tables WHERE owner='ATRACE' AND table_name='REF_TABLES_MODIF'; >> "!PREREQ_SQLFILE!"
 echo IF v_exists = 0 THEN >> "!PREREQ_SQLFILE!"
 echo DBMS_OUTPUT.PUT_LINE^(' atrace.ref_tables_modif: 0 mappings [TABLE NOT CREATED - run OP first]'^); >> "!PREREQ_SQLFILE!"
 echo ELSE >> "!PREREQ_SQLFILE!"
 echo EXECUTE IMMEDIATE 'SELECT COUNT^(*^) FROM atrace.ref_tables_modif' INTO v_count; >> "!PREREQ_SQLFILE!"
 echo DBMS_OUTPUT.PUT_LINE^(' atrace.ref_tables_modif: ' ^|^| TO_CHAR^(v_count, '999,999,999'^) ^|^| ' mappings'^); >> "!PREREQ_SQLFILE!"
 echo END IF; >> "!PREREQ_SQLFILE!"
 echo END; >> "!PREREQ_SQLFILE!"
 echo / >> "!PREREQ_SQLFILE!"
 echo EXIT; >> "!PREREQ_SQLFILE!"
 
 sqlplus -S op/!OPPWD!@!ORACLE_SID! @"!PREREQ_SQLFILE!"
 
 REM Cleanup temp files
 del "!DRYRUN_SQLFILE!" 2>nul
 del "!PREREQ_SQLFILE!" 2>nul
 echo.
 echo Tables to Anonymize ^(OPPAYMENTS schema^):
 echo - admin_user ^(code, names, email, phone, addresses^)
 echo - payment ^(entity/benef codes, descriptions, comments^)
 echo - bulk_payment ^(entity_code, portfolio_code, account_code^)
 echo - payment_audit ^(user_id cascades^)
 echo - approbation_group_users ^(user_id cascades^)
 echo - ref_tiers ^(description^)
 echo - ref_bank_branche ^(BIC components^)
 echo.
 echo Mapping Tables Created:
 echo - atrace.ref_tables_modif_epf ^(EPF-specific mappings^)
 echo - atrace.epf_anonymization_map ^(BIC component mappings^)
 echo.
 echo Estimated Runtime: 30-60 minutes ^(when executed^)
 echo.
 echo ====================================================================
 echo [DRY RUN COMPLETE] - No database changes were made
 echo Re-run without /dryrun to execute.
 echo ====================================================================
 goto end
)

REM Create logs folder
if not exist "%ROOT%logs" mkdir "%ROOT%logs"

echo.
echo Starting EPF anonymization at %DATE% %TIME%...
echo Logs: %ROOT%logs\anonyme_epf.log
echo.

echo Running EPF anonymization (all phases A-H)...
sqlplus /nolog @sql\start_anonymous_epf.sql %ORACLE_SID% %SYSPWD% %OPPWD% !EPFPWD! %TBSDATA% %TBSINDEX%

echo.
echo ====================================================================
echo EPF anonymization completed at %DATE% %TIME%
echo ====================================================================
echo.
echo Log file: %ROOT%logs\anonyme_epf.log
echo.

:end
echo.
pause