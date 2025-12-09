#requires -RunAsAdministrator
<#
    Disable most Windows 11 "AI" features:
      - Copilot button + Copilot feature
      - AI web/Bing integration in Start/Taskbar search
      - Search/Copilot icons in Windows Search & File Explorer suggestions
      - Recall (on Copilot+ PCs)
      - Widgets / Windows Web Experience Pack
      - Auto-suggest in Explorer address bar / Run dialog

    Logs to: C:\Users\Public\Disable_AIFeatures_YYYYMMDD_HHMMSS.log
#>

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath   = Join-Path $env:PUBLIC "Disable_AIFeatures_$timestamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try {
        Add-Content -Path $logPath -Value $line -ErrorAction SilentlyContinue
    } catch { }
}

function Ensure-Admin {
    $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pri.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "This script must be run as Administrator. Aborting." "ERROR"
        throw "Not running as Administrator"
    }
}

function Set-RegValue {
    param(
        [ValidateSet('HKLM','HKCU')][string]$Hive,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][object]$Value,
        [ValidateSet('DWord','String')][string]$Type = 'DWord'
    )

    try {
        # FIXED: use ${Hive} so PowerShell doesn't think $Hive: is a variable
        $fullPath = "${Hive}:\$Path"

        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -Force | Out-Null
            Write-Log "Created registry key $fullPath"
        }

        $propertyType = if ($Type -eq 'String') { 'String' } else { 'DWord' }

        New-ItemProperty -Path $fullPath -Name $Name -Value $Value -PropertyType $propertyType -Force | Out-Null
        Write-Log "Set $fullPath\$Name = $Value ($Type)"
    }
    catch {
        Write-Log "Failed to set registry value $Hive\$Path\$Name : $_" "ERROR"
    }
}

# -----------------------------
# 0. Basic checks + restore point
# -----------------------------
try {
    Ensure-Admin
} catch {
    # Already logged; hard abort
    return
}

Write-Log "Log file: $logPath"

# Try to create a restore point (may fail if disabled)
try {
    Write-Log "Attempting to create system restore point 'Before_AI_Disable'"
    Checkpoint-Computer -Description "Before_AI_Disable" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Log "System restore point created."
} catch {
    Write-Log "Could not create a restore point (System Restore may be disabled). Continuing anyway. $_" "WARN"
}

# -----------------------------
# 1. Disable web/Bing + AI-ish suggestions in Start / Search / Explorer
# -----------------------------
Write-Log "Disabling Bing/web results and AI-ish search suggestions in Start/Taskbar Search and Explorer."

# Disable Copilot + Web icons & web suggestions in Windows Search, and also Explorer search box suggestions
# HKCU\Software\Policies\Microsoft\Windows\Explorer - DisableSearchBoxSuggestions = 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type 'DWord'

# Disable web search engine calls from Windows Search (policy variant)
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type 'DWord'

# Turn off Explorer/Run autosuggest (those "smart" suggestions in address bar / Run)
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete' -Name 'AutoSuggest' -Value 'no' -Type 'String'

# -----------------------------
# 2. Disable Windows Copilot (system-wide + hide button)
# -----------------------------
Write-Log "Disabling Windows Copilot via policy and hiding taskbar button."

# Policy key to turn off Copilot
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type 'DWord'

# Hide Copilot button on taskbar
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Value 0 -Type 'DWord'

# -----------------------------
# 3. Try to uninstall Microsoft Copilot app (if present)
# -----------------------------
Write-Log "Trying to uninstall Microsoft Copilot app packages for the current user (if installed)."

try {
    $copilotPkgs = Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue

    if ($copilotPkgs) {
        foreach ($pkg in $copilotPkgs) {
            try {
                Write-Log "Removing Copilot package $($pkg.Name) ..."
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed $($pkg.Name)"
            }
            catch {
                Write-Log "Failed to remove $($pkg.Name): $_" "WARN"
            }
        }
    }
    else {
        Write-Log "No Copilot-related Appx packages found for the current user."
    }
}
catch {
    Write-Log "Error while enumerating/removing Copilot Appx packages: $_" "WARN"
}

# -----------------------------
# 4. Disable Recall / AI data capture (Copilot+ PCs only)
# -----------------------------
Write-Log "Configuring policies to disable Windows Recall and AI snapshotting (if present)."

# Recall / WindowsAI policies:
# HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI
#   AllowRecallEnablement   = 0  (don't allow Recall to be enabled)
#   DisableAIDataAnalysis   = 1  (block saving/analyzing screen snapshots for Recall)

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1 -Type 'DWord'

# -----------------------------
# 5. Remove Widgets / Windows Web Experience Pack
# -----------------------------
Write-Log "Attempting to remove Windows Web Experience Pack (Widgets and some cloud/home feed bits)."

try {
    # Package providing Widgets & related features: MicrosoftWindows.Client.WebExperience
    $webExp = Get-AppxPackage -Name 'MicrosoftWindows.Client.WebExperience' -ErrorAction SilentlyContinue

    if ($webExp) {
        foreach ($pkg in $webExp) {
            try {
                Write-Log "Removing Web Experience package $($pkg.Name) ..."
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed $($pkg.Name)"
            }
            catch {
                Write-Log "Failed to remove $($pkg.Name): $_" "WARN"
            }
        }
    }
    else {
        Write-Log "MicrosoftWindows.Client.WebExperience is not installed (or already removed) for this user."
    }
}
catch {
    Write-Log "Error while enumerating/removing Web Experience Pack: $_" "WARN"
}

# -----------------------------
# 6. Finish
# -----------------------------
Write-Log "All sections completed. A system reboot is recommended to apply all changes."
Write-Log "If something feels off, you can use the 'Before_AI_Disable' restore point (if it was created successfully)."
