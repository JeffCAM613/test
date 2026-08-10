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
echo KTP Payment Factory - Full Database Anonymization
echo ====================================================================
if %DRYRUN%==1 (
 echo.
 echo *** DRY RUN MODE - No database changes will be made ***
)
echo.
echo This orchestrator runs both OP and EPF anonymization in sequence:
echo 1. OP (Anonymization_OP) - Entities, folders, tiers, bank accts
echo 2. EPF (Anonymization_EPF) - Payment codes, BIC, amounts, users
echo.
echo Order matters: EPF cascades depend on OP mapping data.
echo.
echo ====================================================================
echo.

:SelectMode
echo Select execution mode:
echo [1] Full (OP + EPF)
echo [2] OP only
echo [3] EPF only (assumes OP already completed)
echo.
set /P MODE=Enter choice (1/2/3): 

if "!MODE!"=="1" goto CollectCreds
if "!MODE!"=="2" goto RunOP
if "!MODE!"=="3" goto CollectCredsEPF

echo Invalid choice.
goto SelectMode

REM ========================================================================
REM COLLECT ALL CREDENTIALS UPFRONT (Full mode)
REM This avoids waiting hours for OP to finish before prompting for EPF.
REM Variables are exported so sub-scripts skip their own prompting.
REM ========================================================================
:CollectCreds
echo.
echo ====================================================================
echo Collecting ALL credentials upfront (OP + EPF)
echo so you don't have to wait for OP to finish.
echo ====================================================================
echo.

REM --- Shared credentials ---
set /P ORACLE_SID= Enter DB Oracle SID: 
if "!ORACLE_SID!" == "" (
 echo ERROR: You did not capture a valid database name
 goto end
)

call :prompt_secret SYSPWD " Enter Password for SYS"
if "!SYSPWD!" == "" (
 echo ERROR: You did not capture a valid password for SYS
 goto end
)

call :prompt_secret OPPWD " Enter Password for OP"
if "!OPPWD!" == "" (
 echo ERROR: You did not capture a valid password for OP
 goto end
)

call :prompt_secret EPFPWD " Enter Password for OPPAYMENTS"
if "!EPFPWD!" == "" (
 echo ERROR: You did not capture a valid password for OPPAYMENTS
 goto end
)

set /P TBSDATA= Enter tablespace name for DATA: 
if "!TBSDATA!" == "" (
 echo ERROR: You did not capture a valid tablespace name for DATA
 goto end
)

set /P TBSINDEX= Enter tablespace name for INDEX: 
if "!TBSINDEX!" == "" (
 echo ERROR: You did not capture a valid tablespace name for INDEX
 goto end
)

echo.
echo Credentials collected. Both OP and EPF will run non-interactively.
echo.

REM --- Pre-set OP anonymization options (always anonymizes ALL) ---
REM This prevents start_anonymous.bat from prompting for each category.
set Ent0=y
set EntC=y
set EntD=y
set Ent1=n
set Ent2=n
set Ent3=n
set Ent4=n
set Ent5=n
set Fold0=y
set FoldC=y
set FoldD=y
set Fold1=n
set Fold2=n
set Fold3=n
set Fold4=n
set Fold5=n
set Tier0=y
set TierC=y
set TierD=y
set Tier1=n
set Tier2=n
set Tier3=n
set Tier4=n
set Tier5=n
set Cpte0=y
set CpteC=y
set CpteD=y
set Cpte1=n
set Cpte2=n
set Cpte3=n
set Cpte4=n
set Cpte5=n

goto RunOP

:CollectCredsEPF
echo.
echo ====================================================================
echo Collecting EPF credentials
echo ====================================================================
echo.
set /P ORACLE_SID= Enter DB Oracle SID: 
if "!ORACLE_SID!" == "" (
 echo ERROR: You did not capture a valid database name
 goto end
)

call :prompt_secret SYSPWD " Enter Password for SYS"
call :prompt_secret OPPWD " Enter Password for OP"
call :prompt_secret EPFPWD " Enter Password for OPPAYMENTS"

set /P TBSDATA= Enter tablespace name for DATA: 
set /P TBSINDEX= Enter tablespace name for INDEX: 
goto RunEPF

:RunOP
echo.
echo ====================================================================
echo Launching OP Anonymization...
echo ====================================================================
echo.
set EPF_AUTO_CONFIRM=1
pushd "%ROOT%Anonymization_OP"
if %DRYRUN%==1 (
 call start_anonymous.bat /dryrun
) else (
 call start_anonymous.bat
)
popd

if "!MODE!"=="2" goto end

:RunEPF
echo.
echo ====================================================================
echo Launching EPF Anonymization...
echo ====================================================================
echo.
if "!MODE!"=="1" (
 REM Full mode: open EPF in new window so OP results stay visible
 if %DRYRUN%==1 (
 start "EPF Anonymization" /D "%ROOT%Anonymization_EPF" cmd /k call start_epf_anonymization.bat /dryrun
 ) else (
 start "EPF Anonymization" /D "%ROOT%Anonymization_EPF" cmd /k call start_epf_anonymization.bat
 )
) else (
 REM EPF-only mode: run in same window
 pushd "%ROOT%Anonymization_EPF"
 if %DRYRUN%==1 (
 call start_epf_anonymization.bat /dryrun
 ) else (
 call start_epf_anonymization.bat
 )
 popd
)

:end
echo.
echo ====================================================================
if %DRYRUN%==1 (
 echo [DRY RUN COMPLETE] - No database changes were made.
 echo Re-run without /dryrun to execute.
) else if "!MODE!"=="1" (
 echo OP anonymization completed. EPF running in separate window.
) else (
 echo Anonymization process completed.
)
echo ====================================================================
echo.
pause
exit /b

REM ========================================================================
REM SUBROUTINES
REM ========================================================================
:prompt_secret
REM Usage: call :prompt_secret VARNAME "Prompt text"
REM Prompts for a password (note: Windows batch cannot mask input)
set /P %~1=%~2: 
exit /b