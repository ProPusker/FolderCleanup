<#
.SYNOPSIS
    Automated file cleanup script with configurable retention policies
.DESCRIPTION
    This script cleans up old files based on configurable rules with logging and email notifications
.NOTES
    Version: 2.0
    Author: AI Assistant
    Modified: 2023-10-15
#>

#region Initialization
$ScriptName = [io.path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$ScriptVersion = "2.0"
$ScriptPath = $PSScriptRoot

# Logging Configuration
$LogConfig = @{
    Path = Join-Path $ScriptPath "$ScriptName.log"
    MaxSize = 64KB
    Retention = 5
    Levels = @{
        Info = "INFO"
        Warn = "WARNING"
        Error = "ERROR"
        Debug = "DEBUG"
    }
}

# Email Configuration
$EmailConfig = @{
    SmtpServer = "smtp.office365.com"
    Port = 587
    From = "noreply@example.com"
    To = "admin@example.com"
    Credentials = $null
}
#endregion

#region Functions
function Initialize-Logging {
    param(
        [string]$LogPath,
        [int]$MaxSize,
        [int]$Retention
    )

    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -Force -ItemType File | Out-Null
    }

    # Rotate log if needed
    if ((Get-Item $LogPath).Length -gt $MaxSize) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $archivePath = Join-Path $ScriptPath "logs\$ScriptName-$timestamp.log"
        Move-Item $LogPath $archivePath -Force
    }

    # Maintain log retention
    Get-ChildItem (Join-Path $ScriptPath "logs\$ScriptName-*.log") |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $Retention |
        Remove-Item -Force
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss.fff"
    $logEntry = "$timestamp|$($MyInvocation.ScriptLineNumber)|$Level|$Message"
    
    Add-Content -Path $LogConfig.Path -Value $logEntry
    Write-Host $logEntry
}

function Initialize-EmailCredentials {
    param(
        [string]$EncodedPassword
    )

    try {
        $securePass = ConvertTo-SecureString ([System.Text.Encoding]::UTF8.GetString(
            [System.Convert]::FromBase64String($EncodedPassword)
        )) -AsPlainText -Force
        $EmailConfig.Credentials = New-Object System.Management.Automation.PSCredential (
            $EmailConfig.From,
            $securePass
        )
    }
    catch {
        Write-Log "Failed to initialize email credentials: $_" -Level $LogConfig.Levels.Error
        throw
    }
}

function Send-Notification {
    param(
        [string]$Subject,
        [string]$Body
    )

    $mailParams = @{
        SmtpServer = $EmailConfig.SmtpServer
        Port = $EmailConfig.Port
        UseSsl = $true
        Credential = $EmailConfig.Credentials
        From = $EmailConfig.From
        To = $EmailConfig.To
        Subject = "$ScriptName - $Subject"
        Body = $Body
        Attachments = $LogConfig.Path
        ErrorAction = 'Stop'
    }

    try {
        Send-MailMessage @mailParams
        Write-Log "Notification email sent successfully" -Level $LogConfig.Levels.Info
    }
    catch {
        Write-Log "Failed to send notification: $_" -Level $LogConfig.Levels.Error
    }
}

function Get-HumanReadableSize {
    param(
        [long]$Bytes
    )

    switch ($Bytes) {
        { $_ -ge 1TB } { "{0:N2} TB" -f ($_ / 1TB); break }
        { $_ -ge 1GB } { "{0:N2} GB" -f ($_ / 1GB); break }
        { $_ -ge 1MB } { "{0:N2} MB" -f ($_ / 1MB); break }
        { $_ -ge 1KB } { "{0:N2} KB" -f ($_ / 1KB); break }
        default { "$_ bytes" }
    }
}

function Invoke-FileCleanup {
    param(
        [string]$RootPath,
        [hashtable]$RetentionRules
    )

    $totalStats = @{
        DeletedFiles = 0
        TotalSize = 0L
        Errors = 0
    }

    try {
        Write-Log "Starting cleanup process for: $RootPath" -Level $LogConfig.Levels.Info
        
        Get-ChildItem -Path $RootPath -Recurse -File |
            ForEach-Object {
                try {
                    $filePath = $_.FullName
                    $relativePath = $filePath.Substring($RootPath.Length)

                    # Apply retention rules
                    $rule = $RetentionRules.GetEnumerator() |
                        Where-Object { $relativePath -like $_.Key } |
                        Select-Object -First 1

                    $retentionDays = if ($rule) { $rule.Value } else { 180 }
                    $fileAge = (Get-Date) - $_.LastWriteTime

                    if ($fileAge.TotalDays -gt $retentionDays) {
                        $fileSize = $_.Length
                        Remove-Item $filePath -Force -ErrorAction Stop
                        
                        $totalStats.DeletedFiles++
                        $totalStats.TotalSize += $fileSize
                        
                        Write-Log "Removed: $filePath (Age: $([math]::Round($fileAge.TotalDays))d, Size: $(Get-HumanReadableSize $fileSize))" -Level $LogConfig.Levels.Info
                    }
                }
                catch {
                    $totalStats.Errors++
                    Write-Log "Error processing $filePath : $_" -Level $LogConfig.Levels.Error
                }
            }
    }
    catch {
        Write-Log "General cleanup error: $_" -Level $LogConfig.Levels.Error
        throw
    }

    return $totalStats
}
#endregion

#region Main Execution
try {
    # Initialize components
    Initialize-Logging @LogConfig
    Write-Log "Script initialized (Version: $ScriptVersion)" -Level $LogConfig.Levels.Info

    # Load configuration
    $configPath = Join-Path $ScriptPath "$ScriptName.xml"
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    [xml]$configuration = Get-Content $configPath
    Initialize-EmailCredentials -EncodedPassword $configuration.Settings.Smtp.EncodedPassword

    # Process cleanup rules
    $retentionRules = @{}
    $configuration.Settings.CleanupRules.Rule | ForEach-Object {
        $retentionRules[$_.Path] = [int]$_.RetentionDays
    }

    $cleanupResults = Invoke-FileCleanup -RootPath $configuration.Settings.RootPath -RetentionRules $retentionRules

    # Report results
    $summary = @"
Cleanup Summary:
- Deleted Files: $($cleanupResults.DeletedFiles)
- Reclaimed Space: $(Get-HumanReadableSize $cleanupResults.TotalSize)
- Processing Errors: $($cleanupResults.Errors)
- Execution Time: $((Get-Date).ToString("HH:mm:ss"))
"@

    Write-Log $summary -Level $LogConfig.Levels.Info
    Send-Notification -Subject "Cleanup Report" -Body $summary
}
catch {
    $errorMsg = "Critical error: $_`nStack Trace: $($_.ScriptStackTrace)"
    Write-Log $errorMsg -Level $LogConfig.Levels.Error
    Send-Notification -Subject "Script Failure" -Body $errorMsg
    exit 1
}
finally {
    Write-Log "Script execution completed" -Level $LogConfig.Levels.Info
}
#endregion
