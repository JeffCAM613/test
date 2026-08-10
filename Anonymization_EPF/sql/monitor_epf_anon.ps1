# ============================================================================
# EPF Anonymization Live Monitor
# ============================================================================
# Polls oppayments.epf_anon_log and displays real-time progress for all phases.
# Run in a separate terminal alongside the anonymization script.
#
# Usage:
# .\monitor_epf_anon.ps1 -ConnStr "oppayments/password@DBSID" [-PollSec 5] [-IdleTimeoutMin 30]
# ============================================================================

param(
 [Parameter(Mandatory=$true)]
 [string]$ConnStr,

 [int]$PollSec = 5,

 [int]$IdleTimeoutMin = 30,

 [string]$LogFile = ""
)

# ============================================================================
function Invoke-SqlPoll {
 param([string]$Sql, [int]$TimeoutMs = 90000)

 $tempSql = [System.IO.Path]::GetTempFileName() + ".sql"

 try {
 @"
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 4000
SET TRIMSPOOL ON
SET TRIMOUT ON
$Sql
EXIT;
"@ | Set-Content -Path $tempSql -Encoding ASCII

 $psi = New-Object System.Diagnostics.ProcessStartInfo
 $psi.FileName = "sqlplus"
 $psi.Arguments = "-S $ConnStr @$tempSql"
 $psi.RedirectStandardOutput = $true
 $psi.RedirectStandardError = $true
 $psi.UseShellExecute = $false
 $psi.CreateNoWindow = $true

 $proc = [System.Diagnostics.Process]::Start($psi)
 $output = $proc.StandardOutput.ReadToEnd()
 $proc.WaitForExit($TimeoutMs) | Out-Null

 if (-not $proc.HasExited) {
 $proc.Kill()
 return @()
 }

 return @($output -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne "" })
 }
 finally {
 Remove-Item $tempSql -ErrorAction SilentlyContinue
 }
}

# ============================================================================
function Write-Log {
 param([string]$Message, [string]$Color = "White")

 Write-Host $Message -ForegroundColor $Color
 if ($LogFile -ne "") {
 Add-Content -Path $LogFile -Value $Message
 }
}

# ============================================================================
# Main
# ============================================================================

$host.UI.RawUI.WindowTitle = "EPF Anonymization - Live Monitor"

Write-Log "============================================================" "Cyan"
Write-Log " EPF ANONYMIZATION - LIVE MONITOR" "Cyan"
Write-Log "============================================================" "Cyan"
Write-Log " Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
Write-Log " Poll: ${PollSec}s | Idle timeout: ${IdleTimeoutMin}min" "Gray"
Write-Log "============================================================" "Cyan"
Write-Log ""

# Server baseline time (only show entries after this)
[string[]]$baselineLines = @(Invoke-SqlPoll "SELECT TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') FROM dual;")
if ($baselineLines.Count -eq 0) {
 Write-Log "ERROR: Cannot connect to database. Check connection string." "Red"
 Write-Log ""
 Write-Log "Press any key to exit..."
 $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
 exit 1
}
$serverBaseline = $baselineLines[0].Trim()
Write-Log " Server time: $serverBaseline" "Gray"
Write-Log " Waiting for anonymization activity..." "Yellow"
Write-Log ""

$lastLogId = 0
$lastActivity = Get-Date
$maxIdleSeconds = $IdleTimeoutMin * 60
$activityDetected = $false

while ($true) {
 # Idle timeout
 $idleSeconds = ((Get-Date) - $lastActivity).TotalSeconds
 if ($idleSeconds -gt $maxIdleSeconds) {
 Write-Log ""
 Write-Log "IDLE TIMEOUT: No new activity for $IdleTimeoutMin minutes." "Yellow"
 Write-Log "Press any key to exit..."
 $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
 break
 }

 # Poll all entries after baseline, tracked by log_id cursor (no run_id filter)
 $sql = @"
SELECT log_id || '|' ||
 TO_CHAR(log_timestamp, 'HH24:MI:SS') || '|' ||
 module || '|' ||
 operation || '|' ||
 NVL(TO_CHAR(step_number), '') || '|' ||
 NVL(TO_CHAR(rows_affected), '0') || '|' ||
 status || '|' ||
 NVL(REPLACE(message, '|', '/'), '') || '|' ||
 NVL(TO_CHAR(ROUND(elapsed_seconds, 1)), '') || '|' ||
 NVL(table_name, '') || '|' ||
 NVL(REPLACE(error_message, '|', '/'), '')
 FROM oppayments.epf_anon_log
 WHERE log_id > $lastLogId
 AND log_timestamp >= TO_TIMESTAMP('$serverBaseline', 'YYYY-MM-DD HH24:MI:SS')
 ORDER BY log_id;
"@
 [string[]]$rows = @(Invoke-SqlPoll $sql)

 foreach ($row in $rows) {
 $parts = $row -split '\|', 11
 if ($parts.Count -lt 7) { continue }

 $logId = $parts[0].Trim()
 $timestamp = $parts[1].Trim()
 $module = $parts[2].Trim()
 $operation = $parts[3].Trim()
 $stepNum = $parts[4].Trim()
 $rowsAff = $parts[5].Trim()
 $status = $parts[6].Trim()
 $message = if ($parts.Count -gt 7) { $parts[7].Trim() } else { "" }
 $elapsed = if ($parts.Count -gt 8) { $parts[8].Trim() } else { "" }
 $tableName = if ($parts.Count -gt 9) { $parts[9].Trim() } else { "" }
 $errorMsg = if ($parts.Count -gt 10) { $parts[10].Trim() } else { "" }

 if ($logId -match '^\d+$') { $lastLogId = [int]$logId }
 $lastActivity = Get-Date

 if (-not $activityDetected) {
 $activityDetected = $true
 Write-Log " Activity detected." "Green"
 Write-Log "------------------------------------------------------------"
 }

 # Format output
 $color = "White"
 $line = ""

 switch ($operation) {
 "RUN_START" {
 $color = "Green"
 $line = "[$timestamp] >>> $module STARTED: $message"
 }
 "PHASE_START" {
 $color = "Cyan"
 $line = "[$timestamp] === $message ==="
 }
 "PHASE_END" {
 $color = "Cyan"
 $elapsedStr = if ($elapsed) { " (${elapsed}s)" } else { "" }
 $line = "[$timestamp] === $message$elapsedStr ==="
 }
 "ANONYMIZE" {
 $color = "White"
 $elapsedStr = if ($elapsed) { " (${elapsed}s)" } else { "" }
 $tableStr = if ($tableName) { "$tableName: " } else { "" }
 $line = "[$timestamp] -> ${tableStr}$rowsAff rows$elapsedStr | $message"
 }
 "MAPPING" {
 $color = "White"
 $elapsedStr = if ($elapsed) { " (${elapsed}s)" } else { "" }
 $line = "[$timestamp] -> $tableName: $message$elapsedStr"
 }
 "DISABLE" {
 $color = "Yellow"
 $line = "[$timestamp] TRIGGERS DISABLED: $message"
 }
 "ENABLE" {
 $color = "Yellow"
 $line = "[$timestamp] TRIGGERS ENABLED: $message"
 }
 "ALL_COMPLETE" {
 $color = "Green"
 $line = "[$timestamp] >>> ALL PHASES COMPLETE: $message"
 }
 default {
 $elapsedStr = if ($elapsed) { " (${elapsed}s)" } else { "" }
 $line = "[$timestamp] [$module] $operation: $message$elapsedStr"
 }
 }
 if ($status -eq "ERROR") { $color = "Red" }
 if ($status -eq "WARNING") { $color = "Yellow" }

 Write-Log $line $color

 # Only exit on the orchestrator's final ALL_COMPLETE signal
 if ($operation -eq "ALL_COMPLETE" -and $module -eq "EPF_ORCHESTRATOR") {
 Write-Log ""
 Write-Log "------------------------------------------------------------"
 Write-Log " All EPF anonymization phases completed." "Green"
 Write-Log "============================================================" "Cyan"
 Write-Log ""
 Write-Log "Press any key to exit..."
 $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
 exit 0
 }
 }

 Start-Sleep -Seconds $PollSec
}