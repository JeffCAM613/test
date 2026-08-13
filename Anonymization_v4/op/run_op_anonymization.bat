@echo off
setlocal enabledelayedexpansion

REM ===========================================================================
REM KTP OP Anonymization (v4) - entry point
REM ===========================================================================
REM   run_op_anonymization.bat              interactive
REM   run_op_anonymization.bat /dryrun      interactive, rehearse only
REM   run_op_anonymization.bat /auto        no prompts, take config as-is
REM   run_op_anonymization.bat /auto /force no prompts, no confirmation
REM
REM This script does four things and nothing more: settle the configuration,
REM turn the inventory CSVs into loadable SQL, hand over to sqlplus, and return
REM its exit code. All logic lives in sql\.
REM
REM Every path is derived from %~dp0 (the folder holding THIS file), so the
REM package works wherever it is unpacked. In v3 the batch files resolved paths
REM that did not match where they sat, and neither orchestrator could run.
REM ===========================================================================

set "ROOT=%~dp0"
cd /d "%ROOT%"

set "CONFIG_FILE=%ROOT%..\config\anonymization.ini"
set "INVENTORY_BASE=%ROOT%..\config\inventory_op.csv"
set "SQL_DIR=%ROOT%sql"
set "LOG_DIR=%ROOT%logs"
set "INVENTORY_SQL=%TEMP%\anon_inventory_%RANDOM%.sql"

set "RUN_MODE=EXECUTE"
set "INTERACTIVE=1"
set "FORCE=0"
for %%A in (%*) do (
    if /I "%%~A"=="/dryrun" set "RUN_MODE=DRYRUN"
    if /I "%%~A"=="/auto"   set "INTERACTIVE=0"
    if /I "%%~A"=="/force"  set "FORCE=1"
)

cls
echo.
echo ====================================================================
echo  KTP OP Anonymization (v4)
echo ====================================================================
if "!RUN_MODE!"=="DRYRUN" (
    echo  DRY RUN - the database will not be modified.
) else (
    echo  This makes mass irreversible changes. Use a restored copy only.
)
echo ====================================================================
echo.


REM ===========================================================================
REM  STEP 1 - decide where the configuration comes from
REM ===========================================================================
set "USE_CONFIG=0"

if not exist "%CONFIG_FILE%" goto :no_config_file
if "!INTERACTIVE!"=="0" (
    set "USE_CONFIG=1"
    goto :config_decided
)

echo Found: config\anonymization.ini
call :preview_config
echo.
set "_LOAD="
set /p "_LOAD=Load it? Anything missing is still asked for [Y/n]: "
if not defined _LOAD set "_LOAD=y"
echo.
if /I "!_LOAD:~0,1!"=="y" set "USE_CONFIG=1"
goto :config_decided

:no_config_file
if "!INTERACTIVE!"=="0" (
    echo ERROR: /auto needs a configuration file, and none was found:
    echo   %CONFIG_FILE%
    goto :failed
)
echo No configuration file found at config\anonymization.ini.
echo Every value will be asked for below.
echo.

:config_decided
if "!USE_CONFIG!"=="1" (
    REM eol=@ skips the @REM comments; tokens=1,* keeps values containing '='.
    for /f "usebackq eol=@ tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
        set "%%A=%%B"
    )
    echo Loaded config\anonymization.ini - only missing values will be asked for.
    echo.
) else (
    if exist "%CONFIG_FILE%" (
        echo Ignoring config\anonymization.ini - asking for every value.
        echo.
    )
    call :clear_all
)


REM ===========================================================================
REM  STEP 2 - connection
REM ===========================================================================
if "!INTERACTIVE!"=="1" (
    echo --------------------------------------------------------------------
    echo  Database connection
    echo --------------------------------------------------------------------
)
call :need ORACLE_SID       "Oracle SID"
if errorlevel 1 goto :failed
call :need SYS_PASSWORD     "SYS password"
if errorlevel 1 goto :failed
call :need OP_PASSWORD      "OP password"
if errorlevel 1 goto :failed
call :need TABLESPACE_DATA  "Tablespace for metadata tables"
if errorlevel 1 goto :failed
call :need TABLESPACE_INDEX "Tablespace for metadata indexes"
if errorlevel 1 goto :failed
if "!INTERACTIVE!"=="1" echo.


REM ===========================================================================
REM  STEP 3 - what to anonymize
REM ===========================================================================
if "!INTERACTIVE!"=="1" (
    echo --------------------------------------------------------------------
    echo  What to anonymize
    echo --------------------------------------------------------------------
    echo  These decide which kinds of identifier get replaced. A category left
    echo  at 'n' keeps its real codes everywhere in the schema.
    echo.
    echo  Free text and PII is ALWAYS erased and is not affected by any answer
    echo  below - 92 columns, listed in inventory_op.csv under NULL_OUT.
    echo.
)
REM No '>' or '^' in these prompt strings: inside double quotes cmd treats '^'
REM as a literal character rather than an escape, so it would print verbatim.
call :need_yn ANONYMIZE_ENTITY       "Anonymize entity codes,       prefix E_"  y
call :need_yn ANONYMIZE_PORTFOLIO    "Anonymize portfolio codes,    prefix P_"  y
call :need_yn ANONYMIZE_COUNTERPARTY "Anonymize counterparty codes, prefix T_"  y
call :need_yn ANONYMIZE_BANK_ACCOUNT "Anonymize bank account codes, prefix CB_" y
if "!INTERACTIVE!"=="1" echo.


REM ===========================================================================
REM  STEP 4 - description labels
REM ===========================================================================
if "!INTERACTIVE!"=="1" (
    echo --------------------------------------------------------------------
    echo  Description labels          [was EntD / FoldD / TierD / CpteD]
    echo --------------------------------------------------------------------
    echo  Overwrites the label with the row's own anonymized code, so screens
    echo  stay readable: a counterparty shows as T_0000412 rather than blank.
    echo.
)
call :flag_cols ANONYMIZE_ENTITY_DESCRIPTION       DESCRIPTION ENTITY       "Entity"       "!ANONYMIZE_ENTITY!"
call :flag_cols ANONYMIZE_PORTFOLIO_DESCRIPTION    DESCRIPTION PORTFOLIO    "Portfolio"    "!ANONYMIZE_PORTFOLIO!"
call :flag_cols ANONYMIZE_COUNTERPARTY_DESCRIPTION DESCRIPTION COUNTERPARTY "Counterparty" "!ANONYMIZE_COUNTERPARTY!"
call :flag_cols ANONYMIZE_BANK_ACCOUNT_DESCRIPTION DESCRIPTION BANK_ACCOUNT "Bank account" "!ANONYMIZE_BANK_ACCOUNT!"


REM ===========================================================================
REM  STEP 5 - per-entity PII attributes
REM ===========================================================================
if "!INTERACTIVE!"=="1" (
    echo --------------------------------------------------------------------
    echo  Per-entity PII attributes   [was Ent1-5 / Fold1-5 / Tier1-5 / Cpte1-5]
    echo --------------------------------------------------------------------
    echo  Overwrites each column with that row's anonymized code. Same privacy
    echo  effect as emptying it, but the column stays populated so NOT NULL and
    echo  format checks still pass.
    echo.
    echo  Columns tagged [site] come from config\inventory_op_custom.csv - they
    echo  are what this site put in the old Ent1-5 style slots. Comment a line
    echo  out there to drop one column without disabling the whole category.
    echo.
)
call :flag_cols ANONYMIZE_ENTITY_ATTRIBUTES       SELF_CODE ENTITY       "Entity"       "!ANONYMIZE_ENTITY!"
call :flag_cols ANONYMIZE_PORTFOLIO_ATTRIBUTES    SELF_CODE PORTFOLIO    "Portfolio"    "!ANONYMIZE_PORTFOLIO!"
call :flag_cols ANONYMIZE_COUNTERPARTY_ATTRIBUTES SELF_CODE COUNTERPARTY "Counterparty" "!ANONYMIZE_COUNTERPARTY!"
call :flag_cols ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES SELF_CODE BANK_ACCOUNT "Bank account" "!ANONYMIZE_BANK_ACCOUNT!"


REM ===========================================================================
REM  STEP 6 - run behaviour (all have defaults)
REM ===========================================================================
if "!INTERACTIVE!"=="1" (
    echo --------------------------------------------------------------------
    echo  Run behaviour - press Enter to accept the shown default
    echo --------------------------------------------------------------------
)
call :need_default PARALLEL_DEGREE        "Parallel degree for bulk updates, 1 disables" 4
call :need_default CUSTOM_INVENTORY       "Site-specific inventory file"                 inventory_op_custom.csv
call :need_default FAIL_ON_MISSING_OBJECT "Abort if an inventory object is missing, y/n" n
call :need_default MIN_CODE_LENGTH        "Shortest identifier to substitute, protects checkboxes" 2
if "!INTERACTIVE!"=="1" echo.

set "INVENTORY_CUSTOM=%ROOT%..\config\!CUSTOM_INVENTORY!"


REM ===========================================================================
REM  STEP 7 - summary
REM ===========================================================================
echo ====================================================================
echo  Summary
echo ====================================================================
echo  Database ........ !ORACLE_SID!
echo  Tablespaces ..... !TABLESPACE_DATA! (data)  !TABLESPACE_INDEX! (index)
echo.
echo  Codes ........... entity=!ANONYMIZE_ENTITY!  portfolio=!ANONYMIZE_PORTFOLIO!  counterparty=!ANONYMIZE_COUNTERPARTY!  account=!ANONYMIZE_BANK_ACCOUNT!
echo  Descriptions .... entity=!ANONYMIZE_ENTITY_DESCRIPTION!  portfolio=!ANONYMIZE_PORTFOLIO_DESCRIPTION!  counterparty=!ANONYMIZE_COUNTERPARTY_DESCRIPTION!  account=!ANONYMIZE_BANK_ACCOUNT_DESCRIPTION!
echo  PII attributes .. entity=!ANONYMIZE_ENTITY_ATTRIBUTES!  portfolio=!ANONYMIZE_PORTFOLIO_ATTRIBUTES!  counterparty=!ANONYMIZE_COUNTERPARTY_ATTRIBUTES!  account=!ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES!
echo.
echo  Parallel ........ !PARALLEL_DEGREE!
echo  Custom file ..... !CUSTOM_INVENTORY!
echo  Fail on missing . !FAIL_ON_MISSING_OBJECT!
echo  Min code length . !MIN_CODE_LENGTH!   (shorter values are treated as checkbox states)
echo ====================================================================
echo.


REM ===========================================================================
REM  STEP 8 - turn the inventory CSVs into INSERT statements
REM
REM  The CSVs are here, on the client, not necessarily on the database server,
REM  so they cannot be read by an external table.
REM ===========================================================================
if not exist "%INVENTORY_BASE%" (
    echo ERROR: inventory not found:
    echo   %INVENTORY_BASE%
    goto :failed
)

echo Building the inventory...
> "%INVENTORY_SQL%" echo SET DEFINE OFF
>> "%INVENTORY_SQL%" echo SET FEEDBACK OFF

set /a SEQ=0
call :parse_csv "%INVENTORY_BASE%" BASE
if exist "!INVENTORY_CUSTOM!" (
    call :parse_csv "!INVENTORY_CUSTOM!" CUSTOM
) else (
    echo   no site-specific inventory ^(!CUSTOM_INVENTORY!^) - skipping
)

>> "%INVENTORY_SQL%" echo COMMIT;
>> "%INVENTORY_SQL%" echo SET DEFINE ON

echo   !SEQ! inventory items prepared
echo.

if !SEQ! EQU 0 (
    echo ERROR: the inventory produced no items. Every line was a comment,
    echo        or the CSV format is wrong. Nothing to do.
    goto :failed
)


REM ===========================================================================
REM  STEP 9 - confirm and run
REM ===========================================================================
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

if "!RUN_MODE!"=="EXECUTE" if "!FORCE!"=="0" (
    echo This will irreversibly modify schema OP on !ORACLE_SID!.
    set "CONFIRM="
    set /p "CONFIRM=Type YES to proceed: "
    if /I not "!CONFIRM!"=="YES" (
        echo Cancelled - nothing was changed.
        goto :cleanup_ok
    )
    echo.
)

sqlplus -L /nolog @"%SQL_DIR%\00_run_op_anonymization.sql" ^
    "!ORACLE_SID!" "!SYS_PASSWORD!" "!OP_PASSWORD!" ^
    "!TABLESPACE_DATA!" "!TABLESPACE_INDEX!" "!RUN_MODE!" ^
    "!ANONYMIZE_ENTITY!" "!ANONYMIZE_PORTFOLIO!" "!ANONYMIZE_COUNTERPARTY!" "!ANONYMIZE_BANK_ACCOUNT!" ^
    "!ANONYMIZE_ENTITY_DESCRIPTION!" "!ANONYMIZE_PORTFOLIO_DESCRIPTION!" ^
    "!ANONYMIZE_COUNTERPARTY_DESCRIPTION!" "!ANONYMIZE_BANK_ACCOUNT_DESCRIPTION!" ^
    "!ANONYMIZE_ENTITY_ATTRIBUTES!" "!ANONYMIZE_PORTFOLIO_ATTRIBUTES!" ^
    "!ANONYMIZE_COUNTERPARTY_ATTRIBUTES!" "!ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES!" ^
    "!PARALLEL_DEGREE!" "!FAIL_ON_MISSING_OBJECT!" "!MIN_CODE_LENGTH!" "%INVENTORY_SQL%"

set "RC=!ERRORLEVEL!"
if !RC! EQU 0 (
    del "%INVENTORY_SQL%" 2>nul
) else (
    echo.
    echo The generated inventory file has been KEPT for inspection:
    echo   %INVENTORY_SQL%
)

echo.
echo ====================================================================
if !RC! NEQ 0 (
    echo  FAILED - exit code !RC!
    echo.
    echo  Nothing is assumed about how far it got. To see:
    echo    SELECT phase, object_name, status, message
    echo      FROM anon_meta.anon_step_log
    echo     WHERE run_id = ^(SELECT MAX^(run_id^) FROM anon_meta.anon_run^)
    echo       AND status = 'ERROR';
    echo.
    echo  The mapping is intact, so re-running resumes rather than restarts.
    echo  Full output: logs\
    echo ====================================================================
    exit /b !RC!
)

if "!RUN_MODE!"=="DRYRUN" (
    echo  DRY RUN COMPLETE - no changes were made.
    echo  Re-run without /dryrun to execute.
) else (
    echo  COMPLETE
    echo.
    echo  Verify:
    echo    sqlplus op/^<password^>@!ORACLE_SID! @verify\verify_op_coverage.sql
)
echo  Full output: logs\
echo ====================================================================
exit /b 0


REM ===========================================================================
REM  Subroutines
REM
REM  Two batch rules govern the patterns below:
REM    - set /p leaves the variable UNCHANGED when the user presses Enter, so
REM      every prompt clears the variable first and applies the default after.
REM    - "if defined NAME" takes a variable NAME, which is how a routine can
REM      test a variable whose name arrived as an argument.
REM ===========================================================================

REM --- Show what the config file would supply, before asking to load it.
:preview_config
set /a _set=0
set /a _blank=0
for /f "usebackq eol=@ tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    if "%%B"=="" (set /a _blank+=1) else (set /a _set+=1)
)
echo   !_set! value^(s^) populated, !_blank! left blank.
exit /b 0


REM --- Forget anything a previous run or the environment left behind, so that
REM     "do not load the config" really does ask for everything.
:clear_all
for %%V in (ORACLE_SID SYS_PASSWORD OP_PASSWORD TABLESPACE_DATA TABLESPACE_INDEX
            ANONYMIZE_ENTITY ANONYMIZE_PORTFOLIO ANONYMIZE_COUNTERPARTY ANONYMIZE_BANK_ACCOUNT
            ANONYMIZE_ENTITY_DESCRIPTION ANONYMIZE_PORTFOLIO_DESCRIPTION
            ANONYMIZE_COUNTERPARTY_DESCRIPTION ANONYMIZE_BANK_ACCOUNT_DESCRIPTION
            ANONYMIZE_ENTITY_ATTRIBUTES ANONYMIZE_PORTFOLIO_ATTRIBUTES
            ANONYMIZE_COUNTERPARTY_ATTRIBUTES ANONYMIZE_BANK_ACCOUNT_ATTRIBUTES
            PARALLEL_DEGREE CUSTOM_INVENTORY FAIL_ON_MISSING_OBJECT MIN_CODE_LENGTH) do set "%%V="
exit /b 0


REM --- A value counts as missing if unset or still a <PLACEHOLDER>.
REM     Sets _missing to 1 or 0.
:is_missing
set "_missing=1"
if not defined %~1 exit /b 0
set "_v=!%~1!"
if "!_v!"=="" exit /b 0
echo !_v! | findstr /C:"<" >nul 2>&1
if !errorlevel! EQU 0 exit /b 0
set "_missing=0"
exit /b 0


REM Separate labels rather than "if COND echo ... & exit /b": in batch the '&'
REM starts a new command that the if does NOT guard, so the exit would fire on
REM every call.
:echo_set
if /I "%~1"=="SYS_PASSWORD" goto :echo_set_masked
if /I "%~1"=="OP_PASSWORD"  goto :echo_set_masked
echo   [config] %~1 = !%~1!
exit /b 0
:echo_set_masked
echo   [config] %~1 = ********
exit /b 0


REM --- Required, no default. Prompts until answered.
REM     Usage: call :need VARNAME "description"
:need
call :is_missing "%~1"
if "!_missing!"=="0" goto :need_show
if "!INTERACTIVE!"=="0" goto :need_cannot_ask
:need_retry
set "%~1="
set /p "%~1=  %~2: "
if not defined %~1 (
    echo         that value is required
    goto :need_retry
)
exit /b 0
:need_show
if "!INTERACTIVE!"=="1" call :echo_set "%~1"
exit /b 0
:need_cannot_ask
echo ERROR: %~2 is not set in the configuration file, and /auto cannot ask for it.
exit /b 1


REM --- Value with a default. Enter accepts it.
REM     Usage: call :need_default VARNAME "description" DEFAULT
:need_default
call :is_missing "%~1"
if "!_missing!"=="0" goto :need_default_show
if "!INTERACTIVE!"=="0" goto :need_default_apply
set "%~1="
set /p "%~1=  %~2 [%~3]: "
if not defined %~1 goto :need_default_apply
exit /b 0
:need_default_apply
set "%~1=%~3"
exit /b 0
:need_default_show
if "!INTERACTIVE!"=="1" call :echo_set "%~1"
exit /b 0


REM --- Yes/no with a default.
REM     Usage: call :need_yn VARNAME "question" DEFAULT
:need_yn
call :is_missing "%~1"
if "!_missing!"=="0" goto :need_yn_show
if "!INTERACTIVE!"=="0" goto :need_yn_apply
set "%~1="
set /p "%~1=  %~2 [%~3]: "
if not defined %~1 goto :need_yn_apply
goto :need_yn_done
:need_yn_apply
set "%~1=%~3"
goto :need_yn_done
:need_yn_show
if "!INTERACTIVE!"=="1" call :echo_set "%~1"
:need_yn_done
REM Normalise so later comparisons and the summary are consistent. The engine
REM accepts y/yes/true/1 regardless; this is for display and for the
REM "is the category on?" test below.
set "_v=!%~1!"
set "_v=!_v:~0,1!"
if /I "!_v!"=="y" set "%~1=y"
if /I "!_v!"=="t" set "%~1=y"
if /I "!_v!"=="1" set "%~1=y"
if /I "!_v!"=="o" set "%~1=y"
if /I "!_v!"=="n" set "%~1=n"
if /I "!_v!"=="f" set "%~1=n"
if /I "!_v!"=="0" set "%~1=n"
exit /b 0


REM --- Ask a description/attributes flag, listing the columns it governs.
REM     The list is read from the inventory CSVs at prompt time, so it is always
REM     what will actually happen rather than a description that can drift.
REM
REM     Usage: call :flag_cols VARNAME RULE CATEGORY "Label" <category flag>
:flag_cols
set "_var=%~1"
set "_rule=%~2"
set "_cat=%~3"
set "_catflag=%~5"

REM The category itself being off makes this moot: both rules write the row's
REM anonymized code, and without a mapping there is none to write.
if /I not "!_catflag!"=="y" (
    set "%~1=n"
    if "!INTERACTIVE!"=="1" echo   %~4 - skipped, that category is not being anonymized.
    exit /b 0
)

call :is_missing "%~1"
if "!_missing!"=="0" goto :flag_cols_show
if "!INTERACTIVE!"=="0" (
    set "%~1=y"
    exit /b 0
)

echo   %~4 - columns affected:
set "_found=0"
call :list_cols "%INVENTORY_BASE%" "!_rule!" "!_cat!" ""
if exist "!INVENTORY_CUSTOM!" call :list_cols "!INVENTORY_CUSTOM!" "!_rule!" "!_cat!" "[site]"
if "!_found!"=="0" echo         none in the inventory - nothing would change

set "%~1="
set /p "%~1=      Anonymize these? [y]: "
if not defined %~1 set "%~1=y"
set "_v=!%~1!"
set "_v=!_v:~0,1!"
if /I "!_v!"=="y" (set "%~1=y") else (set "%~1=n")
echo.
exit /b 0

:flag_cols_show
if "!INTERACTIVE!"=="1" call :echo_set "%~1"
exit /b 0


REM --- List inventory columns matching a rule, for this category or for ANY.
REM     Usage: call :list_cols <csv> <RULE> <CATEGORY> <tag>
:list_cols
for /f "usebackq eol=# tokens=1-5* delims=," %%A in ("%~1") do (
    if /I not "%%A"=="table_name" (
        if /I "%%C"=="%~2" (
            if /I "%%D"=="%~3" (
                echo         %%A.%%B %~4
                set "_found=1"
            )
            if /I "%%D"=="ANY" (
                echo         %%A.%%B %~4 - applies to every category
                set "_found=1"
            )
        )
    )
)
exit /b 0


REM --- Parse one inventory CSV into INSERT statements.
REM     eol=# drops the comment lines; blank lines are skipped by for /f.
REM     tokens=1-5* keeps any commas in the notes field inside %%F.
:parse_csv
set "CSV=%~1"
set "SRC=%~2"
echo   reading %~nx1
for /f "usebackq eol=# tokens=1-5* delims=," %%A in ("%CSV%") do (
    set "TBL=%%A"
    set "COL=%%B"
    set "RUL=%%C"
    set "CAT=%%D"
    set "NTS=%%F"
    if /I not "!TBL!"=="table_name" (
        if not "!COL!"=="" if not "!RUL!"=="" if not "!CAT!"=="" (
            REM Strip quotes so they cannot break the generated SQL.
            set "NTS=!NTS:'=!"
            set "TBL=!TBL:'=!"
            set "COL=!COL:'=!"
            set /a SEQ+=1
            >> "%INVENTORY_SQL%" echo INSERT INTO anon_meta.anon_inventory ^(table_name,column_name,rule,category,source,notes,seq^) VALUES ^(UPPER^('!TBL!'^),UPPER^('!COL!'^),UPPER^('!RUL!'^),UPPER^('!CAT!'^),'%SRC%','!NTS!',!SEQ!^);
        )
    )
)
exit /b 0


:failed
echo.
del "%INVENTORY_SQL%" 2>nul
exit /b 1

:cleanup_ok
del "%INVENTORY_SQL%" 2>nul
exit /b 0
