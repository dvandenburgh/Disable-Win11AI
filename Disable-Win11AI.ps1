#requires -RunAsAdministrator
<#
    Disable Windows 11 "AI" features (updated for 24H2 / 25H2):
      - Copilot button + Copilot feature
      - AI web/Bing integration in Start/Taskbar search
      - Search/Copilot icons in Windows Search & File Explorer suggestions
      - Recall (on Copilot+ PCs)
      - Click to Do (Win+Q on-screen AI, Copilot+ PCs)        [NEW in 24H2/25H2]
      - Recall snapshot export policy                          [NEW in 25H2]
      - Widgets / Windows Web Experience Pack
      - Auto-suggest in Explorer address bar / Run dialog
      - AI Actions in File Explorer context menu               [NEW in 25H2]
      - Paint AI features: Image Creator, Generative Fill,
        Cocreator                                              [NEW in 24H2/25H2]
      - Start menu Recommended / promoted content section      [NEW in 24H2/25H2]

    Logs to: C:\Users\Public\Disable_AIFeatures_YYYYMMDD_HHMMSS.log

    NOTE: Sections 6-9 target features added in Windows 11 24H2 and 25H2.
    Sections that apply only to Copilot+ PC hardware (Recall, Click to Do)
    are safe to apply on any machine - they simply no-op if the hardware
    is not present.
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
    return
}

Write-Log "Log file: $logPath"

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
Write-Log "--- Section 1: Disabling Bing/web results and AI search suggestions ---"

# Disable search box suggestions (Explorer address bar, Run dialog) - per-user
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type 'DWord'

# Same key at machine scope - ensures it sticks for all users / new profiles
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type 'DWord'

# Disable web search engine calls from Windows Search (policy variant)
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type 'DWord'

# Disable Connected Search (also prevents Bing results bleeding into Search)
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0 -Type 'DWord'

# Turn off Explorer/Run autosuggest (address bar "smart" suggestions)
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete' -Name 'AutoSuggest' -Value 'no' -Type 'String'

# -----------------------------
# 2. Disable Windows Copilot (system-wide + hide button)
# -----------------------------
Write-Log "--- Section 2: Disabling Windows Copilot and hiding taskbar button ---"

Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type 'DWord'

# Hide Copilot button on taskbar
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Value 0 -Type 'DWord'

# -----------------------------
# 3. Try to uninstall Microsoft Copilot app (if present)
# -----------------------------
Write-Log "--- Section 3: Removing Copilot Appx package (if installed) ---"

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
Write-Log "--- Section 4: Disabling Recall AI snapshotting and export (Copilot+ PCs) ---"

# AllowRecallEnablement = 0  -> block Recall from being enabled at all
# DisableAIDataAnalysis  = 1  -> block saving/analyzing screen snapshots
# AllowSnapshotExport    = 0  -> block users from exporting Recall snapshot data [NEW 25H2]
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement'  -Value 0 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis'  -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowSnapshotExport'    -Value 0 -Type 'DWord'

# -----------------------------
# 5. Remove Widgets / Windows Web Experience Pack
# -----------------------------
Write-Log "--- Section 5: Removing Windows Web Experience Pack (Widgets) ---"

try {
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
        Write-Log "MicrosoftWindows.Client.WebExperience not found (already removed or not installed)."
    }
}
catch {
    Write-Log "Error while enumerating/removing Web Experience Pack: $_" "WARN"
}

# -----------------------------
# 6. Disable Click to Do (Win+Q on-screen AI, 24H2 / 25H2 Copilot+ PCs)
# [NEW] Click to Do is an on-screen AI overlay that identifies text and images
# under your cursor and offers AI actions on them. Policy key lives in WindowsAI.
# Safe to set on non-Copilot+ hardware; it simply has no effect.
# -----------------------------
Write-Log "--- Section 6: Disabling Click to Do (Copilot+ on-screen AI) ---"

# Policy path (enforced, overrides user toggle in Settings)
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableClickToDo' -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\WindowsAI'  -Name 'DisableClickToDo' -Value 1 -Type 'DWord'

# Per-user shell key (Settings toggle target; belt-and-suspenders)
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\Shell\ClickToDo'     -Name 'DisableClickToDo' -Value 1 -Type 'DWord'

# -----------------------------
# 7. Disable AI Actions in File Explorer context menu
# [NEW in 25H2] "AI Actions" adds an AI submenu to the right-click context
# menu in File Explorer, offering actions like summarise, rewrite, etc.
# HideAIActionsMenu = 1 removes the entire submenu for all users on this machine.
# -----------------------------
Write-Log "--- Section 7: Hiding AI Actions from File Explorer context menu ---"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'HideAIActionsMenu' -Value 1 -Type 'DWord'

# -----------------------------
# 8. Disable Paint AI features (Image Creator, Generative Fill, Cocreator)
# [NEW in 24H2/25H2] Microsoft added AI-powered features to the inbox Paint app.
# These policy DWORDs disable each feature individually.
# Note: "Generative Erase" and "Remove Background" do not yet have policy keys.
# -----------------------------
Write-Log "--- Section 8: Disabling Paint AI features (Image Creator, Generative Fill, Cocreator) ---"

$paintPolicyPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
Set-RegValue -Hive 'HKLM' -Path $paintPolicyPath -Name 'DisableImageCreator'   -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path $paintPolicyPath -Name 'DisableGenerativeFill' -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKLM' -Path $paintPolicyPath -Name 'DisableCocreator'      -Value 1 -Type 'DWord'

# -----------------------------
# 9. Hide Start menu Recommended / promoted content section
# [NEW in 24H2/25H2] The "Recommended" section in the Start menu shows recent
# files, promoted apps, and AI-surfaced suggestions. Two keys are required;
# the IsEducationEnvironment flag is the only reliable cross-edition method
# to fully suppress this section (Pro policy key alone is insufficient on Home).
# NOTE: This requires Windows 11 Pro or higher for the HideRecommendedSection
# key to take effect. On Home editions only IsEducationEnvironment applies.
# -----------------------------
Write-Log "--- Section 9: Suppressing Start menu Recommended / promoted content ---"

# Pro/Enterprise/Edu policy key
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'                      -Name 'HideRecommendedSection'  -Value 1 -Type 'DWord'
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\Explorer'                      -Name 'HideRecommendedSection'  -Value 1 -Type 'DWord'

# Education environment flag - suppresses promoted/AI suggestions in Start on all editions
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\PolicyManager\current\device\Education'         -Name 'IsEducationEnvironment'  -Value 1 -Type 'DWord'

# -----------------------------
# 10. Finish
# -----------------------------
Write-Log "All sections completed. A system reboot is recommended to apply all changes."
Write-Log "If something feels off, use the 'Before_AI_Disable' restore point (if created)."
Write-Log "Log saved to: $logPath"
