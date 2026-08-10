@echo off
setlocal enabledelayedexpansion

REM ========================================================================
REM DRY RUN MODE: Pass /dryrun to preview without executing SQL
REM ========================================================================
set DRYRUN=0
for %%A in (%*) do (
 if /I "%%~A"=="/dryrun" set DRYRUN=1
)

REM If called from the orchestrator (run_full_anonymization.bat), credentials
REM are already in the environment. Preserve them before config.ini loading.
if defined EPF_AUTO_CONFIRM (
 set "_SAVED_SID=!ORACLE_SID!"
 set "_SAVED_SYSPWD=!SYSPWD!"
 set "_SAVED_OPPWD=!OPPWD!"
 set "_SAVED_TBSDATA=!TBSDATA!"
 set "_SAVED_TBSINDEX=!TBSINDEX!"
)

cls
set ROOT=%~dp0

echo.
echo.
echo ============ KTP database anonymization script ===================
if %DRYRUN%==1 (
echo ============ *** DRY RUN MODE - NO CHANGES *** ===================
) else (
echo ============ ===================
)
echo == This script is intended to change sensitive client ==
echo == information by transforming either the code, the ==
echo == description or other user specified fields into random codes ==
echo == Information that can be anonymized is : Entities, folders ==
echo == Counterparties and Bank accounts (all tables are concerned) ==
echo == If you choose to anonymize Entities, Folder or counterparties,==
echo == adresse1 to adresse5 will also be anonymized by default ==
echo == You will need Name of DATA ^& INDEX tablespaces ==
echo ============ OP and SYS passwords =============
echo ====================================================================
echo.

REM ========================================================================
REM CONFIG FILE SUPPORT
REM If config.ini exists in the same folder, load values from it.
REM Any value left blank or containing '<' (placeholder) will be prompted.
REM ========================================================================
set CONFIG_FILE=%ROOT%config.ini
set CONFIG_LOADED=0

if exist "%CONFIG_FILE%" (
 echo Loading configuration from: config.ini
 echo.
 for /f "usebackq eol=@ tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
 set "%%A=%%B"
 )
 set CONFIG_LOADED=1
) else (
 echo No config.ini found - running in interactive mode.
 echo TIP: Copy config_template.ini to config.ini for non-interactive runs.
 echo.
)

REM Restore orchestrator-provided credentials (overrides config.ini blanks)
if defined EPF_AUTO_CONFIRM (
 if defined _SAVED_SID set "ORACLE_SID=!_SAVED_SID!"
 if defined _SAVED_SYSPWD set "SYSPWD=!_SAVED_SYSPWD!"
 if defined _SAVED_OPPWD set "OPPWD=!_SAVED_OPPWD!"
 if defined _SAVED_TBSDATA set "TBSDATA=!_SAVED_TBSDATA!"
 if defined _SAVED_TBSINDEX set "TBSINDEX=!_SAVED_TBSINDEX!"
)

REM ========================================================================
REM VALIDATE / PROMPT: For each variable, if it's empty or a placeholder,
REM prompt the user interactively. Otherwise, use the loaded value.
REM ========================================================================

REM --- ENTITIES ---
call :check_or_prompt Ent0 "Do you want to anonymize Entities (y/n) ?"
if /I "!Ent0!" NEQ "y" (
 echo Entities will not be anonymized
 set EntC=n
 set EntD=n
 set Ent1=n
 set Ent2=n
 set Ent3=n
 set Ent4=n
 set Ent5=n
) else (
 call :check_or_prompt EntC " Entities - anonymize code (y/n) ?"
 call :check_or_prompt EntD " Entities - anonymize description (y/n) ?"
 call :check_or_prompt Ent1 " Entities - 1st extra field (n to skip)"
 call :check_or_prompt Ent2 " Entities - 2nd extra field (n to skip)"
 call :check_or_prompt Ent3 " Entities - 3rd extra field (n to skip)"
 call :check_or_prompt Ent4 " Entities - 4th extra field (n to skip)"
 call :check_or_prompt Ent5 " Entities - 5th extra field (n to skip)"
)

REM --- FOLDERS ---
call :check_or_prompt Fold0 "Do you want to anonymize Folders (y/n) ?"
if /I "!Fold0!" NEQ "y" (
 echo Folders will not be anonymized
 set FoldC=n
 set FoldD=n
 set Fold1=n
 set Fold2=n
 set Fold3=n
 set Fold4=n
 set Fold5=n
) else (
 call :check_or_prompt FoldC " Folders - anonymize code (y/n) ?"
 call :check_or_prompt FoldD " Folders - anonymize description (y/n) ?"
 call :check_or_prompt Fold1 " Folders - 1st extra field (n to skip)"
 call :check_or_prompt Fold2 " Folders - 2nd extra field (n to skip)"
 call :check_or_prompt Fold3 " Folders - 3rd extra field (n to skip)"
 call :check_or_prompt Fold4 " Folders - 4th extra field (n to skip)"
 call :check_or_prompt Fold5 " Folders - 5th extra field (n to skip)"
)

REM --- COUNTERPARTIES (TIERS) ---
call :check_or_prompt Tier0 "Do you want to anonymize Counterparties (y/n) ?"
if /I "!Tier0!" NEQ "y" (
 echo Counterparties will not be anonymized
 set TierC=n
 set TierD=n
 set Tier1=n
 set Tier2=n
 set Tier3=n
 set Tier4=n
 set Tier5=n
) else (
 call :check_or_prompt TierC " Tiers - anonymize code (y/n) ?"
 call :check_or_prompt TierD " Tiers - anonymize description (y/n) ?"
 call :check_or_prompt Tier1 " Tiers - 1st extra field (n to skip)"
 call :check_or_prompt Tier2 " Tiers - 2nd extra field (n to skip)"
 call :check_or_prompt Tier3 " Tiers - 3rd extra field (n to skip)"
 call :check_or_prompt Tier4 " Tiers - 4th extra field (n to skip)"
 call :check_or_prompt Tier5 " Tiers - 5th extra field (n to skip)"
)

REM --- BANK ACCOUNTS ---
call :check_or_prompt Cpte0 "Do you want to anonymize Bank Accounts (y/n) ?"
if /I "!Cpte0!" NEQ "y" (
 echo Bank Accounts will not be anonymized
 set CpteC=n
 set CpteD=n
 set Cpte1=n
 set Cpte2=n
 set Cpte3=n
 set Cpte4=n
 set Cpte5=n
) else (
 call :check_or_prompt CpteC " Accounts - anonymize code (y/n) ?"
 call :check_or_prompt CpteD " Accounts - anonymize description (y/n) ?"
 call :check_or_prompt Cpte1 " Accounts - 1st extra field (n to skip)"
 call :check_or_prompt Cpte2 " Accounts - 2nd extra field (n to skip)"
 call :check_or_prompt Cpte3 " Accounts - 3rd extra field (n to skip)"
 call :check_or_prompt Cpte4 " Accounts - 4th extra field (n to skip)"
 call :check_or_prompt Cpte5 " Accounts - 5th extra field (n to skip)"
)

REM --- Check if anything was selected ---
if /I "!Ent0!" NEQ "y" if /I "!Fold0!" NEQ "y" if /I "!Cpte0!" NEQ "y" if /I "!Tier0!" NEQ "y" (
 echo.
 echo ERROR: Nothing selected for anonymization.
 goto end
)

REM --- DATABASE CREDENTIALS ---
echo.
echo --- Database Connection ---
call :check_or_prompt ORACLE_SID " Enter DB Oracle SID"
if "!ORACLE_SID!" == "" (
 echo ERROR: You did not capture a valid database name
 goto end
)

call :check_or_prompt_secret SYSPWD " Enter Password for SYS"
if "!SYSPWD!" == "" (
 echo ERROR: You did not capture a valid password for SYS
 goto end
)

call :check_or_prompt_secret OPPWD " Enter Password for OP"
if "!OPPWD!" == "" (
 echo ERROR: You did not capture a valid password for OP
 goto end
)

call :check_or_prompt TBSDATA " Enter tablespace name for DATA"
if "!TBSDATA!" == "" (
 echo ERROR: You did not capture a valid tablespace name for DATA
 goto end
)

call :check_or_prompt TBSINDEX " Enter tablespace name for INDEX"
if "!TBSINDEX!" == "" (
 echo ERROR: You did not capture a valid tablespace name for INDEX
 goto end
)

REM ========================================================================
REM SET DEFAULTS: Replace any remaining empty values with 'n'
REM ========================================================================
if "!EntC!" == "" set EntC=n
if "!EntD!" == "" set EntD=n
if "!Ent1!" == "" set Ent1=n
if "!Ent2!" == "" set Ent2=n
if "!Ent3!" == "" set Ent3=n
if "!Ent4!" == "" set Ent4=n
if "!Ent5!" == "" set Ent5=n
if "!FoldC!" == "" set FoldC=n
if "!FoldD!" == "" set FoldD=n
if "!Fold1!" == "" set Fold1=n
if "!Fold2!" == "" set Fold2=n
if "!Fold3!" == "" set Fold3=n
if "!Fold4!" == "" set Fold4=n
if "!Fold5!" == "" set Fold5=n
if "!TierC!" == "" set TierC=n
if "!TierD!" == "" set TierD=n
if "!Tier1!" == "" set Tier1=n
if "!Tier2!" == "" set Tier2=n
if "!Tier3!" == "" set Tier3=n
if "!Tier4!" == "" set Tier4=n
if "!Tier5!" == "" set Tier5=n
if "!CpteC!" == "" set CpteC=n
if "!CpteD!" == "" set CpteD=n
if "!Cpte1!" == "" set Cpte1=n
if "!Cpte2!" == "" set Cpte2=n
if "!Cpte3!" == "" set Cpte3=n
if "!Cpte4!" == "" set Cpte4=n
if "!Cpte5!" == "" set Cpte5=n

REM ========================================================================
REM SUMMARY
REM ========================================================================
echo.
echo ====================================================================
echo Configuration Summary:
echo ====================================================================
echo Database: !ORACLE_SID!
echo Tablespaces: DATA=!TBSDATA! INDEX=!TBSINDEX!
echo Entities: !Ent0! (code=!EntC! desc=!EntD! fields: !Ent1! !Ent2! !Ent3! !Ent4! !Ent5!)
echo Folders: !Fold0! (code=!FoldC! desc=!FoldD! fields: !Fold1! !Fold2! !Fold3! !Fold4! !Fold5!)
echo Counterparties: !Tier0! (code=!TierC! desc=!TierD! fields: !Tier1! !Tier2! !Tier3! !Tier4! !Tier5!)
echo Bank Accounts: !Cpte0! (code=!CpteC! desc=!CpteD! fields: !Cpte1! !Cpte2! !Cpte3! !Cpte4! !Cpte5!)
echo ====================================================================
echo.

REM ========================================================================
REM DRY RUN MODE: Show row counts and exit without executing
REM ========================================================================
if %DRYRUN%==1 (
 echo ====================================================================
 echo [DRY RUN] OP ANONYMIZATION PLAN
 echo ====================================================================
 echo.
 echo SQL Files to Execute:
 echo 1. sql\01_manage_tblspace.sql - Tablespace setup
 echo 2. sql\02pack_anonym_number.sql - Anonymization package
 echo 3. sql\03anon_triggers.sql - Cascade triggers
 echo 4. sql\06_op_setbased_anonym.sql - Set-based anonymization
 echo 5. sql\04drop_anon_triggers.sql - Cleanup triggers
 echo.
 echo Fetching row counts from database...
 echo.
 
 REM Build temp SQL file for row counts
 REM Using actual OP schema table queries from 06_op_setbased_anonym.sql
 set "DRYRUN_SQLFILE=%TEMP%\op_dryrun_%RANDOM%.sql"
 
 echo SET PAGESIZE 0 FEEDBACK OFF HEADING OFF > "!DRYRUN_SQLFILE!"
 
 if /I "!Ent0!"=="y" (
 echo SELECT ' [x] Entities: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM structure s JOIN tiers t ON t.code = s.code WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'N'; >> "!DRYRUN_SQLFILE!"
 ) else (
 echo [ ] Entities: SKIPPED
 )
 
 if /I "!Fold0!"=="y" (
 echo SELECT ' [x] Portfolios: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM structure s JOIN tiers t ON t.code = s.code WHERE s.structure = 'Entite' AND s.ecran = 'w_tiers' AND t.flag_portefeuille = 'O'; >> "!DRYRUN_SQLFILE!"
 ) else (
 echo [ ] Portfolios: SKIPPED
 )
 
 if /I "!Tier0!"=="y" (
 echo SELECT ' [x] Counterparties: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM structure WHERE structure = 'Compte' AND ecran = 'w_tiers'; >> "!DRYRUN_SQLFILE!"
 ) else (
 echo [ ] Counterparties: SKIPPED
 )
 
 if /I "!Cpte0!"=="y" (
 echo SELECT ' [x] Bank Accounts: ' ^|^| TO_CHAR^(COUNT^(*^), '999,999,999'^) ^|^| ' rows' FROM compte_banque; >> "!DRYRUN_SQLFILE!"
 ) else (
 echo [ ] Bank Accounts: SKIPPED
 )
 
 echo EXIT; >> "!DRYRUN_SQLFILE!"
 
 REM Execute read-only query to get row counts
 sqlplus -S op/!OPPWD!@!ORACLE_SID! @"!DRYRUN_SQLFILE!"
 
 REM Cleanup temp file
 del "!DRYRUN_SQLFILE!" 2>nul
 
 echo.
 echo Mapping Table Output:
 echo - atrace.ref_tables_modif ^(cascades to EPF^)
 echo.
 echo Estimated Runtime: 20-40 minutes ^(when executed^)
 echo.
 echo ====================================================================
 echo [DRY RUN COMPLETE] - No database changes were made
 echo Re-run without /dryrun to execute.
 echo ====================================================================
 goto end
)

if defined EPF_AUTO_CONFIRM (
 echo [auto-confirm] Skipping confirmation - called from orchestrator.
 goto execution
)

set /P CONFIRM= Proceed with anonymization? (y/n):
if /I "!CONFIRM!" NEQ "y" goto end

cd /D "%ROOT%"

REM Create logs folder
if not exist "%ROOT%logs" mkdir "%ROOT%logs"

echo.
echo Starting set-based anonymization... Expected runtime: 20-40 minutes.
echo.

REM ========================================================================
REM LOAD CUSTOM INCLUSIONS FROM CSV
REM Parse inclusions.csv and generate SQL INSERT statements
REM ========================================================================
set "INCLUSIONS_CSV=%ROOT%inclusions.csv"
set "INCLUSIONS_SQL=%ROOT%sql\load_inclusions_data.sql"

REM Generate the SQL file to load inclusions
echo -- Auto-generated from inclusions.csv > "!INCLUSIONS_SQL!"
echo -- Generated: %DATE% %TIME% >> "!INCLUSIONS_SQL!"
echo SET SERVEROUTPUT ON SIZE UNLIMITED >> "!INCLUSIONS_SQL!"
echo SET ECHO OFF >> "!INCLUSIONS_SQL!"
echo SET VERIFY OFF >> "!INCLUSIONS_SQL!"
echo SET FEEDBACK OFF >> "!INCLUSIONS_SQL!"
echo. >> "!INCLUSIONS_SQL!"
echo -- Create/clear temp table >> "!INCLUSIONS_SQL!"
echo DECLARE >> "!INCLUSIONS_SQL!"
echo v_exists NUMBER; >> "!INCLUSIONS_SQL!"
echo BEGIN >> "!INCLUSIONS_SQL!"
echo SELECT COUNT^(*^) INTO v_exists FROM all_tables WHERE owner = 'ATRACE' AND table_name = 'ANON_INCLUSIONS'; >> "!INCLUSIONS_SQL!"
echo IF v_exists = 0 THEN >> "!INCLUSIONS_SQL!"
echo EXECUTE IMMEDIATE 'CREATE TABLE atrace.anon_inclusions ^(table_name VARCHAR2^(128^) NOT NULL, column_name VARCHAR2^(128^) NOT NULL, anon_type VARCHAR2^(10^) NOT NULL, notes VARCHAR2^(500^), processed VARCHAR2^(1^) DEFAULT ''N'', process_msg VARCHAR2^(500^), CONSTRAINT pk_anon_inclusions PRIMARY KEY ^(table_name, column_name^)^)'; >> "!INCLUSIONS_SQL!"
echo DBMS_OUTPUT.PUT_LINE^(' Created atrace.anon_inclusions'^); >> "!INCLUSIONS_SQL!"
echo ELSE >> "!INCLUSIONS_SQL!"
echo EXECUTE IMMEDIATE 'DELETE FROM atrace.anon_inclusions'; >> "!INCLUSIONS_SQL!"
echo COMMIT; >> "!INCLUSIONS_SQL!"
echo END IF; >> "!INCLUSIONS_SQL!"
echo END; >> "!INCLUSIONS_SQL!"
echo / >> "!INCLUSIONS_SQL!"
echo GRANT SELECT, INSERT, UPDATE, DELETE ON atrace.anon_inclusions TO op; >> "!INCLUSIONS_SQL!"
echo. >> "!INCLUSIONS_SQL!"

REM Parse CSV and add INSERT statements
set INCL_COUNT=0
if exist "!INCLUSIONS_CSV!" (
 echo Parsing custom inclusions from: inclusions.csv
 for /f "usebackq tokens=1,2,3,* delims=," %%A in ("!INCLUSIONS_CSV!") do (
 REM Skip lines starting with # (comments) or empty lines
 set "LINE=%%A"
 if defined LINE (
 set "FIRST_CHAR=!LINE:~0,1!"
 if "!FIRST_CHAR!" NEQ "#" (
 REM Valid data line: TABLE_NAME,COLUMN_NAME,TYPE,NOTES
 set "TBL=%%A"
 set "COL=%%B"
 set "TYP=%%C"
 set "NTS=%%D"
 if defined TBL if defined COL if defined TYP (
 echo INSERT INTO atrace.anon_inclusions ^(table_name, column_name, anon_type, notes^) VALUES ^('!TBL!', '!COL!', '!TYP!', '!NTS!'^); >> "!INCLUSIONS_SQL!"
 set /a INCL_COUNT+=1
 )
 )
 )
 )
)

echo COMMIT; >> "!INCLUSIONS_SQL!"
echo. >> "!INCLUSIONS_SQL!"
echo DECLARE v_cnt NUMBER; >> "!INCLUSIONS_SQL!"
echo BEGIN >> "!INCLUSIONS_SQL!"
echo SELECT COUNT^(*^) INTO v_cnt FROM atrace.anon_inclusions; >> "!INCLUSIONS_SQL!"
echo IF v_cnt ^> 0 THEN >> "!INCLUSIONS_SQL!"
echo DBMS_OUTPUT.PUT_LINE^(' Custom inclusions loaded: ' ^|^| v_cnt^); >> "!INCLUSIONS_SQL!"
echo ELSE >> "!INCLUSIONS_SQL!"
echo DBMS_OUTPUT.PUT_LINE^(' No custom inclusions ^(inclusions.csv empty or all commented^)'^); >> "!INCLUSIONS_SQL!"
echo END IF; >> "!INCLUSIONS_SQL!"
echo END; >> "!INCLUSIONS_SQL!"
echo / >> "!INCLUSIONS_SQL!"
echo EXIT; >> "!INCLUSIONS_SQL!"

if !INCL_COUNT! GTR 0 (
 echo Found !INCL_COUNT! custom inclusion^(s^) to process
) else (
 echo No custom inclusions found ^(file empty or all commented^)
)

REM Load inclusions into database
echo Loading custom inclusions into database...
sqlplus -S sys/!SYSPWD!@!ORACLE_SID! as sysdba @"!INCLUSIONS_SQL!"

:execution
sqlplus /nolog @sql\start_anonymous_v3.sql !ORACLE_SID! !SYSPWD! !OPPWD! !EntC! !EntD! !Ent1! !Ent2! !Ent3! !Ent4! !Ent5! !FoldC! !FoldD! !Fold1! !Fold2! !Fold3! !Fold4! !Fold5! !TierC! !TierD! !Tier1! !Tier2! !Tier3! !Tier4! !Tier5! !CpteC! !CpteD! !Cpte1! !Cpte2! !Cpte3! !Cpte4! !Cpte5! !TBSDATA! !TBSINDEX!

:end
echo.
echo OP anonymization finished.
if not defined EPF_AUTO_CONFIRM (
 pause
)
exit /b

REM ========================================================================
REM SUBROUTINES
REM ========================================================================

:check_or_prompt
REM Usage: call :check_or_prompt VARNAME "Prompt text"
REM If the variable is empty or contains '<' (placeholder), prompt the user.
set "_val=!%~1!"
if "!_val!" == "" goto :do_prompt
echo !_val! | findstr /C:"<" >nul 2>&1
if !errorlevel! == 0 goto :do_prompt
REM Value is set from config - show it
echo [config] %~1 = !_val!
goto :eof

:do_prompt
set /P "%~1=%~2: "
goto :eof

:check_or_prompt_secret
REM Same as check_or_prompt but masks the display for passwords
set "_val=!%~1!"
if "!_val!" == "" goto :do_prompt_secret
echo !_val! | findstr /C:"<" >nul 2>&1
if !errorlevel! == 0 goto :do_prompt_secret
REM Value is set from config - show masked
echo [config] %~1 = ********
goto :eof

:do_prompt_secret
set /P "%~1=%~2: "
goto :eof

