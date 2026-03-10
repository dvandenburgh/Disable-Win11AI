#Requires -RunAsAdministrator
<#
    Win11-Cleanup.ps1 — Windows 11 Pro debloat + AI removal (24H2 / 25H2)

    Covers:
      - Bing/web integration and AI suggestions in Search and Explorer
      - Copilot (policy, taskbar button, Appx removal)
      - Recall, Click to Do, AI snapshotting and snapshot export (Copilot+ PCs)
      - AI Actions in File Explorer context menu
      - Paint AI features (Image Creator, Generative Fill, Cocreator)
      - Widgets / Windows Web Experience Pack
      - Start menu Recommended / promoted content
      - Start, Settings, Lock Screen, and Explorer ads and cloud nudges
      - Telemetry, activity feed, feedback prompts, diagnostic log collection
      - Consumer Experience / silent app installs
      - 25H2 native Store app removal policy scaffold (Pro+)
      - Ultimate Performance power plan (unlocked in Power Options)

    Sections that target Copilot+ PC hardware (Recall, Click to Do) are safe
    to apply on any machine — they no-op if the hardware is not present.

    Logs to: C:\Users\Public\Win11_Cleanup_YYYYMMDD_HHMMSS.log
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath   = Join-Path $env:PUBLIC "Win11_Cleanup_$timestamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path $logPath -Value $line -ErrorAction SilentlyContinue } catch {}
}

function Write-Step {
    param([string]$Msg)
    $line = "`n>> $Msg"
    Write-Host $line -ForegroundColor Cyan
    try { Add-Content -Path $logPath -Value $line -ErrorAction SilentlyContinue } catch {}
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
        Write-Log "Failed to set registry value ${Hive}:\$Path\$Name : $_" "ERROR"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 0. Restore point
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "Log file: $logPath"

try {
    Write-Log "Attempting to create system restore point 'Before_Win11_Cleanup'"
    Checkpoint-Computer -Description "Before_Win11_Cleanup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Log "System restore point created."
} catch {
    Write-Log "Could not create a restore point (System Restore may be disabled). Continuing anyway. $_" "WARN"
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Search — disable Bing/web results and AI suggestions
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Search — Disable Bing/web results and AI suggestions"

Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\Explorer'             -Name 'DisableSearchBoxSuggestions' -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'             -Name 'DisableSearchBoxSuggestions' -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Windows Search'       -Name 'DisableWebSearch'            -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Windows Search'       -Name 'ConnectedSearchUseWeb'       -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Search'         -Name 'SearchboxTaskbarMode'        -Value 1  # 0=hidden 1=icon 2=box
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\AutoComplete' -Name 'AutoSuggest'          -Value 'no' -Type 'String'

# ─────────────────────────────────────────────────────────────────────────────
# 2. Copilot — disable system-wide, hide button, remove app
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Copilot — Disable system-wide, hide taskbar button, remove Appx"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'       -Name 'TurnOffWindowsCopilot'       -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\WindowsCopilot'       -Name 'TurnOffWindowsCopilot'       -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton'        -Value 0

try {
    $copilotPkgs = Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue
    if ($copilotPkgs) {
        foreach ($pkg in $copilotPkgs) {
            try {
                Write-Log "Removing Copilot package $($pkg.Name) ..."
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed $($pkg.Name)"
            } catch {
                Write-Log "Failed to remove $($pkg.Name): $_" "WARN"
            }
        }
    } else {
        Write-Log "No Copilot Appx packages found for current user."
    }
} catch {
    Write-Log "Error enumerating Copilot Appx packages: $_" "WARN"
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Recall — disable AI snapshotting and export (Copilot+ PCs)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Recall — Disable AI snapshotting and export (Copilot+ PCs)"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'            -Name 'AllowRecallEnablement'       -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'            -Name 'DisableAIDataAnalysis'       -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'            -Name 'AllowSnapshotExport'         -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 4. Click to Do — disable on-screen AI overlay (Copilot+ PCs)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Click to Do — Disable on-screen AI overlay (Copilot+ PCs)"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'            -Name 'DisableClickToDo'            -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\WindowsAI'            -Name 'DisableClickToDo'            -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\Shell\ClickToDo'               -Name 'DisableClickToDo'            -Value 1

# ─────────────────────────────────────────────────────────────────────────────
# 5. Paint AI — disable Image Creator, Generative Fill, Cocreator
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Paint — Disable AI features (Image Creator, Generative Fill, Cocreator)"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableImageCreator'        -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableGenerativeFill'      -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableCocreator'           -Value 1

# ─────────────────────────────────────────────────────────────────────────────
# 6. File Explorer — remove AI Actions menu, ads, cloud nudges
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "File Explorer — Remove AI Actions menu, ads, cloud nudges"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'             -Name 'HideAIActionsMenu'           -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowSyncProviderNotifications' -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo'                 -Value 1  # open to This PC
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt'              -Value 0  # show extensions
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer'          -Name 'ShowFrequent'             -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer'          -Name 'ShowRecent'               -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 7. Widgets / Windows Web Experience Pack — remove from taskbar and uninstall
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Widgets — Remove from taskbar and uninstall Web Experience Pack"

Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa'               -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Dsh'                             -Name 'AllowNewsAndInterests'   -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests' -Name 'value' -Value 0

try {
    $webExp = Get-AppxPackage -Name 'MicrosoftWindows.Client.WebExperience' -ErrorAction SilentlyContinue
    if ($webExp) {
        foreach ($pkg in $webExp) {
            try {
                Write-Log "Removing Web Experience package $($pkg.Name) ..."
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed $($pkg.Name)"
            } catch {
                Write-Log "Failed to remove $($pkg.Name): $_" "WARN"
            }
        }
    } else {
        Write-Log "MicrosoftWindows.Client.WebExperience not found (already removed or not installed)."
    }
} catch {
    Write-Log "Error enumerating Web Experience Pack: $_" "WARN"
}

# ─────────────────────────────────────────────────────────────────────────────
# 8. Start menu — remove Recommended section and all ad/suggestion channels
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Start menu — Remove Recommended section and ad/suggestion channels"

# Policy keys (Pro+ enforced; belt-and-suspenders with Education flag below)
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'             -Name 'HideRecommendedSection'     -Value 1
Set-RegValue -Hive 'HKCU' -Path 'Software\Policies\Microsoft\Windows\Explorer'             -Name 'HideRecommendedSection'     -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'             -Name 'HideRecentlyAddedApps'      -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\Explorer'             -Name 'HideFrequentlyUsedApps'     -Value 1

# Education flag — suppresses promoted/AI content in Start on all editions including Home
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\PolicyManager\current\device\Education' -Name 'IsEducationEnvironment'   -Value 1

# Per-user recent/recommended tracking
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackDocs'        -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs'       -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_ShowRecentDocs'   -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowRecentFiles'        -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowFrequentFolders'    -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_ShowRunAsOtherUser' -Value 0

# ContentDeliveryManager — all ad/suggestion/push channels
$cdm = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SystemPaneSuggestionsEnabled'          -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-338388Enabled'       -Value 0  # Start suggestions
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-338389Enabled'       -Value 0  # Lock screen tips
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-338393Enabled'       -Value 0  # Timeline suggestions
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-353694Enabled'       -Value 0  # Settings suggestions
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-353696Enabled'       -Value 0  # Settings suggestions 2
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-280815Enabled'       -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-310093Enabled'       -Value 0  # Spotlight/Windows tips (24H2+)
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-314559Enabled'       -Value 0  # Promoted apps in Start (24H2+)
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SoftLandingEnabled'                    -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'ContentDeliveryAllowed'                -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'OemPreInstalledAppsEnabled'            -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'PreInstalledAppsEnabled'               -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'PreInstalledAppsEverEnabled'           -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SilentInstalledAppsEnabled'            -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'FeatureManagementEnabled'              -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 9. Taskbar — remove Task View button
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Taskbar — Remove Task View button"

Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton'      -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 10. Lock screen — remove Spotlight and cloud content
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Lock screen — Remove Spotlight and cloud content"

Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'RotatingLockScreenEnabled'             -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'RotatingLockScreenOverlayEnabled'      -Value 0
Set-RegValue -Hive 'HKCU' -Path $cdm -Name 'SubscribedContent-338387Enabled'       -Value 0  # Lock screen fun facts/tips

# ─────────────────────────────────────────────────────────────────────────────
# 11. Telemetry and activity feed
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Telemetry — Minimize data collection and disable activity feed"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'                -Name 'AllowTelemetry'                  -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry'                  -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'MaxTelemetryAllowed'             -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'                -Name 'LimitDiagnosticLogCollection'    -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'                -Name 'DoNotShowFeedbackNotifications'  -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\System'                        -Name 'EnableActivityFeed'              -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\System'                        -Name 'PublishUserActivities'           -Value 0
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\System'                        -Name 'UploadUserActivities'            -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 12. Settings app — disable personalized ads and tailored experiences
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Settings — Disable personalized ads and tailored experiences"

Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled'                                      -Value 0
Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\Privacy'         -Name 'TailoredExperiencesWithDiagnosticDataEnabled'  -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 13. Consumer Experience — block silent app installs and cloud content pushes
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Consumer Experience — Block silent app installs and cloud content"

Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures'               -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSoftLanding'                           -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableCloudOptimizedContent'                 -Value 1
Set-RegValue -Hive 'HKLM' -Path 'SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountStateContent'           -Value 1

Set-RegValue -Hive 'HKCU' -Path 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name 'ScoobeSystemSettingEnabled' -Value 0

# ─────────────────────────────────────────────────────────────────────────────
# 14. 25H2 native Store app removal policy scaffold (Pro / Enterprise / Edu)
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "25H2 Store app removal — Creating policy scaffold"

# Windows 11 25H2 reads package family name subkeys from this path and
# deprovisions the corresponding apps for all new user profiles. Changes
# survive feature updates. Silently ignored on 24H2 and Home editions.
#
# !! DO NOT add Microsoft Store or any Xbox/gaming packages here.
#    The Store is required for app updates and Xbox services underpin
#    Game Pass, game overlays, and controller input on PC.
#
# To remove an app, add its package family name as a subkey with value 1:
#   Set-RegValue -Hive 'HKLM' -Path "$appxRoot\Microsoft.BingNews_8wekyb3d8bbwe" -Name '(default)' -Value 1
#
# Common candidates (uncomment to enable):
#   Microsoft.BingWeather_8wekyb3d8bbwe
#   Microsoft.BingNews_8wekyb3d8bbwe
#   Microsoft.YourPhone_8wekyb3d8bbwe                    # Phone Link
#   Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe
#   Microsoft.OutlookForWindows_8wekyb3d8bbwe
#   Clipchamp.Clipchamp_yxz26nhyzhsrt
#   Microsoft.Windows.DevHome_8wekyb3d8bbwe

$appxRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages'
if (-not (Test-Path $appxRoot)) {
    New-Item -Path $appxRoot -Force | Out-Null
    Write-Log "Created $appxRoot — add package family name subkeys to enable app removal."
} else {
    Write-Log "$appxRoot already exists."
}

# ─────────────────────────────────────────────────────────────────────────────
# 15. Power plan — unlock Ultimate Performance in Power Options
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Power plan — Unlock Ultimate Performance in Power Options"

# Adds the hidden scheme to the list of available plans so it can be selected
# in Control Panel > Power Options. Does NOT activate it — current plan unchanged.
$ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$existingScheme = powercfg /list 2>$null | Where-Object { $_ -match $ultimateGuid }

if ($existingScheme) {
    Write-Log "Ultimate Performance plan is already available in Power Options."
} else {
    powercfg /duplicatescheme $ultimateGuid 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Ultimate Performance plan added. Select it in Power Options whenever you want it."
    } else {
        Write-Log "Could not add Ultimate Performance plan (may not be supported on this edition)." "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 16. Restart Explorer to apply taskbar / Start menu changes
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Restarting Explorer to apply taskbar and Start menu changes..."

Stop-Process -Name explorer -Force
Start-Sleep -Seconds 2
Start-Process explorer

Write-Log "All sections completed. A reboot is recommended to fully apply all changes."
Write-Log "If something feels off, use the 'Before_Win11_Cleanup' restore point (if created)."
Write-Log "Log saved to: $logPath"
