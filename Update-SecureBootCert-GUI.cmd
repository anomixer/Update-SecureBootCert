<# : batch
@echo off
REM ---------------------------------------------------------------------------
REM  Secure Boot Certificate Updater (GUI) v2.0 - batch/PowerShell hybrid launcher.
REM  cmd.exe runs only these few lines; to PowerShell, this whole header is a
REM  block comment. The batch part passes this file's own path to
REM  Windows PowerShell, which reads the rest of the file and opens the window.
REM  Administrator rights are asked for once (UAC).
REM ---------------------------------------------------------------------------
setlocal
set "SBGUI_SCRIPT=%~f0"
set "SBGUI_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "SBGUI_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%SBGUI_PS%" set "SBGUI_PS=powershell"
"%SBGUI_PS%" -NoProfile -ExecutionPolicy Bypass -STA -Command "iex ([IO.File]::ReadAllText($env:SBGUI_SCRIPT, [Text.Encoding]::UTF8))"
if errorlevel 1 pause
exit /b
#>

# =============================================================================
#  Secure Boot Certificate Updater - GUI v2.0
#
#  A window for Update-SecureBootCert.ps1 (same engine, same steps):
#    - shows Secure Boot, Windows' own update status, the certificates in the
#      firmware (KEK and DB) with their real expiry dates, BitLocker and the
#      recent Secure Boot events
#    - optional: install KB5073724 (older Windows 10 21H2/22H2 only)
#    - optional: install all pending Windows software updates
#    - optional: suspend BitLocker for 2 restarts
#    - installs the 2023 certificates and boot manager (AvailableUpdates =
#      0x5944 and the Secure-Boot-Update task); never overwrites an update
#      that Windows already queued
#    - restart button; the work runs in the background, so the window
#      does not freeze
#
#  Nothing is changed until you click "Start update" and confirm.
#  Log files: %ProgramData%\Update-SecureBootCert
# =============================================================================

$SbEngine = @'
# >>> SB-ENGINE BEGIN - keep this block identical in Update-SecureBootCert.ps1 and Update-SecureBootCert-GUI.cmd <<<
# Shared by the script and the GUI. Functions that report progress call Write-SbLog,
# which the script and the GUI each define for themselves.

$SbVersion   = '2.0'
$SbKey       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SbTaskPath  = '\Microsoft\Windows\PI\'
$SbTaskName  = 'Secure-Boot-Update'
$SbFullValue = 0x5944   # Microsoft's value for the full update: 2023 KEK, 2023 DB certificates, 2023-signed boot manager
$SbDbValue   = 0x40     # Old method (v1.x): only adds Windows UEFI CA 2023 to the DB
$SbKbId      = 'KB5073724'
$SbKbUbr     = 6809     # Windows 10 build 1904x.6809 = KB5073724

# ----- Reference data -----

function Get-SbKnownCerts {
    @(
        [pscustomobject]@{ Store = 'KEK'; Name = 'Microsoft Corporation KEK CA 2011';     Year = 2011; Expires = [datetime]'2026-06-24'; Use = 'Signs updates to DB and DBX' }
        [pscustomobject]@{ Store = 'KEK'; Name = 'Microsoft Corporation KEK 2K CA 2023';  Year = 2023; Expires = [datetime]'2038-03-02'; Use = 'Signs updates to DB and DBX' }
        [pscustomobject]@{ Store = 'db';  Name = 'Microsoft Windows Production PCA 2011'; Year = 2011; Expires = [datetime]'2026-10-19'; Use = 'Windows boot manager' }
        [pscustomobject]@{ Store = 'db';  Name = 'Windows UEFI CA 2023';                  Year = 2023; Expires = [datetime]'2035-06-13'; Use = 'Windows boot manager' }
        [pscustomobject]@{ Store = 'db';  Name = 'Microsoft Corporation UEFI CA 2011';    Year = 2011; Expires = [datetime]'2026-06-27'; Use = 'Third-party boot loaders and option ROMs' }
        [pscustomobject]@{ Store = 'db';  Name = 'Microsoft UEFI CA 2023';                Year = 2023; Expires = [datetime]'2038-06-13'; Use = 'Third-party boot loaders (Linux shim, tools)' }
        [pscustomobject]@{ Store = 'db';  Name = 'Microsoft Option ROM UEFI CA 2023';     Year = 2023; Expires = [datetime]'2038-10-26'; Use = 'Third-party option ROMs (graphics, network)' }
    )
}

function Get-SbEventMeaning([int]$Id) {
    switch ($Id) {
        1032 { 'Not applied: BitLocker would have asked for the recovery key' }
        1033 { 'DBX update postponed: an old, possibly revoked boot manager is on the EFI partition' }
        1034 { 'DBX updated' }
        1036 { 'DB updated' }
        1037 { 'DBX updated: Windows Production PCA 2011 revoked' }
        1042 { 'DBX updated: old boot manager versions blocked' }
        1043 { 'KEK updated with Microsoft Corporation KEK 2K CA 2023' }
        1044 { 'DB updated with Microsoft Option ROM UEFI CA 2023' }
        1045 { 'DB updated with Microsoft UEFI CA 2023' }
        1795 { 'The firmware returned an error; Windows tries again at the next restart' }
        1796 { 'Unexpected error; Windows tries again at the next restart' }
        1797 { 'DBX update blocked: Windows UEFI CA 2023 is not in the DB' }
        1798 { 'DBX update blocked: the boot manager is not signed with Windows UEFI CA 2023' }
        1799 { 'Boot manager signed with Windows UEFI CA 2023 installed' }
        1800 { 'A restart is needed before the update can continue' }
        1801 { 'The 2023 certificates/boot manager are not fully applied to the firmware yet' }
        1802 { 'Blocked by Microsoft: known firmware issue on this device' }
        1803 { 'KEK update not possible: no KEK signed by this PC maker''s platform key (PK)' }
        1808 { 'Finished: this PC has the 2023 Secure Boot certificates and boot manager' }
        default { 'Secure Boot servicing event' }
    }
}

# ----- Reading the state (nothing is changed here) -----

function Get-SbOsInfo {
    $v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$v.CurrentBuildNumber
    $ubr = 0
    if ($null -ne $v.UBR) { $ubr = [int]$v.UBR }
    $type = [string]$v.InstallationType
    $isClient = ($type -eq 'Client')
    $name = [string]$v.ProductName
    if ($isClient -and $build -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
    $display = [string]$v.DisplayVersion
    if (-not $display) { $display = [string]$v.ReleaseId }
    $arch = $env:PROCESSOR_ARCHITEW6432
    if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    $archTag = switch ($arch) { 'AMD64' { 'x64' } 'ARM64' { 'ARM64' } 'x86' { 'x86' } default { '' } }
    [pscustomobject]@{
        Name          = $name
        Display       = $display
        Build         = $build
        Ubr           = $ubr
        Type          = $type
        IsClient      = $isClient
        IsServer      = (-not $isClient)
        IsWin10Client = ($isClient -and ($build -eq 19044 -or $build -eq 19045))
        IsWin11       = ($isClient -and $build -ge 22000)
        Arch          = $archTag
    }
}

# $true / $false, or $null when Secure Boot is not available (legacy BIOS/CSM)
function Get-SbSecureBoot {
    try { [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $null }
}

# Raw bytes of a Secure Boot variable (KEK or db), or $null
function Get-SbUefiVariable([string]$Name) {
    try {
        $v = Get-SecureBootUEFI -Name $Name -ErrorAction Stop
        if ($null -eq $v -or $null -eq $v.Bytes) { return $null }
        return , ([byte[]]$v.Bytes)
    } catch { return $null }
}

# X.509 certificates in an EFI_SIGNATURE_LIST buffer
function Get-SbEslCerts([byte[]]$Bytes, [string]$Store) {
    if ($null -eq $Bytes) { return }
    $x509 = [guid]'a5c059a1-94e4-4aa7-87b5-ab155c2bf072'   # EFI_CERT_X509_GUID
    $o = 0
    while ($o + 28 -le $Bytes.Length) {
        $type     = [guid]::new([byte[]]$Bytes[$o..($o + 15)])
        $listSize = [int][BitConverter]::ToUInt32($Bytes, $o + 16)
        $hdrSize  = [int][BitConverter]::ToUInt32($Bytes, $o + 20)
        $sigSize  = [int][BitConverter]::ToUInt32($Bytes, $o + 24)
        if ($listSize -lt 28 -or ($o + $listSize) -gt $Bytes.Length) { break }
        if ($type -eq $x509 -and $sigSize -gt 16) {
            $s = $o + 28 + $hdrSize
            while ($s + $sigSize -le $o + $listSize) {
                try {
                    $der = [byte[]]$Bytes[($s + 16)..($s + $sigSize - 1)]
                    $c = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($der)
                    [pscustomobject]@{
                        Store      = $Store
                        Name       = $c.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
                        NotAfter   = $c.NotAfter
                        Thumbprint = $c.Thumbprint
                    }
                } catch { }
                $s += $sigSize
            }
        }
        $o += $listSize
    }
}

function Get-SbCertStatus([datetime]$NotAfter) {
    $now = Get-Date
    if ($NotAfter -lt $now) { 'Expired' }
    elseif ($NotAfter -lt $now.AddDays(180)) { 'Expires soon' }
    else { 'Valid' }
}

# All certificates in KEK and db, with status. Readable = $false when the variables can't be read.
function Get-SbFirmwareCerts {
    $known = Get-SbKnownCerts
    $found = @()
    $readable = $false
    foreach ($store in 'KEK', 'db') {
        $bytes = Get-SbUefiVariable $store
        if ($null -eq $bytes) { continue }
        $readable = $true
        $parsed = @(Get-SbEslCerts -Bytes $bytes -Store $store)
        if ($parsed.Count -eq 0 -and $bytes.Length -gt 0) {
            # Fallback: look for the known names in the raw bytes
            $text = [Text.Encoding]::ASCII.GetString($bytes)
            foreach ($k in $known) {
                if ($k.Store -eq $store -and $text.Contains($k.Name)) {
                    $parsed += [pscustomobject]@{ Store = $store; Name = $k.Name; NotAfter = $k.Expires; Thumbprint = '' }
                }
            }
        }
        $found += $parsed
    }
    $certs = foreach ($c in $found) {
        $k = $known | Where-Object { $_.Name -eq $c.Name } | Select-Object -First 1
        $year = 0; $use = 'Added by the PC maker or another vendor'
        if ($k) { $year = $k.Year; $use = $k.Use }
        [pscustomobject]@{
            Store    = $(if ($c.Store -eq 'db') { 'DB' } else { 'KEK' })
            Name     = $c.Name
            NotAfter = $c.NotAfter
            Status   = Get-SbCertStatus $c.NotAfter
            Year     = $year
            Use      = $use
        }
    }
    [pscustomobject]@{ Readable = $readable; Certs = @($certs) }
}

function Get-SbServicing {
    $p = $null
    try { $p = Get-ItemProperty -Path ($SbKey + '\Servicing') -ErrorAction Stop } catch { }
    [pscustomobject]@{
        Status     = $(if ($p) { $p.UEFICA2023Status })
        Error      = $(if ($p) { $p.UEFICA2023Error })
        ErrorEvent = $(if ($p) { $p.UEFICA2023ErrorEvent })
        Capable    = $(if ($p) { $p.WindowsUEFICA2023Capable })
    }
}

function Get-SbAvailableUpdates {
    try {
        $v = (Get-ItemProperty -Path $SbKey -Name 'AvailableUpdates' -ErrorAction Stop).AvailableUpdates
        if ($null -ne $v) { return [int]$v }
    } catch { }
    return $null
}

function Get-SbTask {
    $r = [pscustomobject]@{ Exists = $false; State = ''; LastRun = $null; LastResult = $null }
    try {
        $t = Get-ScheduledTask -TaskPath $SbTaskPath -TaskName $SbTaskName -ErrorAction Stop
        $r.Exists = $true
        $r.State = [string]$t.State
        $i = $t | Get-ScheduledTaskInfo -ErrorAction Stop
        if ($i.LastRunTime -and $i.LastRunTime.Year -gt 2000) {
            $r.LastRun = $i.LastRunTime
            $r.LastResult = [int64]$i.LastTaskResult
        }
    } catch { }
    $r
}

function Get-SbBitLocker {
    $r = [pscustomobject]@{ Available = $false; On = $false; RecoveryPassword = $false; Drive = $env:SystemDrive }
    try {
        $vol = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName 'Win32_EncryptableVolume' -Filter ("DriveLetter='{0}'" -f $env:SystemDrive) -ErrorAction Stop
        if ($vol) {
            $r.Available = $true
            $r.On = ($vol.ProtectionStatus -eq 1)
            try {
                $kp = Invoke-CimMethod -InputObject $vol -MethodName 'GetKeyProtectors' -Arguments @{ KeyProtectorType = [uint32]3 } -ErrorAction Stop
                $r.RecoveryPassword = (@($kp.VolumeKeyProtectorID | Where-Object { $_ }).Count -gt 0)
            } catch { }
        }
    } catch { }
    $r
}

function Get-SbPendingReboot {
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
}

function Get-SbLastBoot {
    try { (Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction Stop).LastBootUpTime } catch { $null }
}

# Newest Secure Boot servicing events first (System log, source TPM-WMI)
function Get-SbEvents([int]$Max = 10) {
    $ids = 1032, 1033, 1034, 1036, 1037, 1042, 1043, 1044, 1045, 1795, 1796, 1797, 1798, 1799, 1800, 1801, 1802, 1803, 1808
    try {
        @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = $ids } -MaxEvents 200 -ErrorAction Stop |
            Where-Object { $_.ProviderName -like '*TPM-WMI*' } |
            Select-Object -First $Max |
            ForEach-Object { [pscustomobject]@{ Time = $_.TimeCreated; Id = $_.Id; Meaning = (Get-SbEventMeaning $_.Id) } })
    } catch { @() }
}

# Decides the overall result from a state object (no system calls, so it can be tested)
function Resolve-SbVerdict($S) {
    $missing = @()
    if (-not $S.HasKek2023)   { $missing += 'Microsoft Corporation KEK 2K CA 2023 (KEK)' }
    if (-not $S.HasWinCa2023) { $missing += 'Windows UEFI CA 2023 (DB)' }
    if ($S.HasUefi2011 -and -not $S.HasMsUefi2023)     { $missing += 'Microsoft UEFI CA 2023 (DB)' }
    if ($S.HasUefi2011 -and -not $S.HasOptionRom2023)  { $missing += 'Microsoft Option ROM UEFI CA 2023 (DB)' }
    if ($null -ne $S.Servicing.Capable -and $S.Servicing.Capable -ne 2) { $missing += 'boot manager signed with Windows UEFI CA 2023' }

    $queued = 0
    if ($null -ne $S.AvailableUpdates) { $queued = $S.AvailableUpdates -band (-bnot 0x4000) }

    if ($null -eq $S.SecureBoot -or -not $S.FirmwareReadable) { $v = 'NoUefi' }
    elseif ($S.Servicing.Status -eq 'Updated') { $v = 'Complete' }
    elseif ($missing.Count -eq 0 -and $queued -eq 0) {
        if ($null -eq $S.Servicing.Capable) { $v = 'CertsPresent' } else { $v = 'Complete' }
    }
    elseif ($queued -eq 0x100) {
        # Only the boot manager step is left. Restarted since the task last ran? Then the task must run again.
        if ($S.Task.LastRun -and $S.LastBoot -and $S.LastBoot -gt $S.Task.LastRun) { $v = 'InProgress' } else { $v = 'RestartNeeded' }
    }
    elseif ($queued -ne 0 -or $S.Servicing.Status -eq 'InProgress') { $v = 'InProgress' }
    elseif ($S.HasWinCa2023 -or $S.HasKek2023) { $v = 'Partial' }
    else { $v = 'NotStarted' }

    $S.Verdict = $v
    $S.Missing = $missing
}

function Get-SbState {
    $os = Get-SbOsInfo
    $fw = Get-SbFirmwareCerts
    $names = @($fw.Certs | ForEach-Object { $_.Name })
    $s = [pscustomobject]@{
        Time             = Get-Date
        Os               = $os
        SecureBoot       = Get-SbSecureBoot
        FirmwareReadable = $fw.Readable
        Certs            = $fw.Certs
        HasKek2023       = ($names -contains 'Microsoft Corporation KEK 2K CA 2023')
        HasWinCa2023     = ($names -contains 'Windows UEFI CA 2023')
        HasMsUefi2023    = ($names -contains 'Microsoft UEFI CA 2023')
        HasOptionRom2023 = ($names -contains 'Microsoft Option ROM UEFI CA 2023')
        HasUefi2011      = ($names -contains 'Microsoft Corporation UEFI CA 2011')
        Servicing        = Get-SbServicing
        AvailableUpdates = Get-SbAvailableUpdates
        Task             = Get-SbTask
        BitLocker        = Get-SbBitLocker
        PendingReboot    = Get-SbPendingReboot
        LastBoot         = Get-SbLastBoot
        Events           = @(Get-SbEvents 10)
        Verdict          = ''
        Missing          = @()
    }
    Resolve-SbVerdict $s
    $s
}

# ----- Text for the script and the GUI -----

# Error codes as 0x80070490 (registry DWORDs and HRESULTs come back as negative Int32)
function Format-SbHex($Value) {
    if ($null -eq $Value) { return '' }
    try { return ('0x{0:X8}' -f [int]$Value) } catch { return ('0x{0:X}' -f $Value) }
}

function Format-SbFlag($Value) {
    if ($null -eq $Value) { return 'not set' }
    if ($Value -eq 0) { return '0 (nothing queued)' }
    $q = $Value -band (-bnot 0x4000)
    $hex = '0x{0:X}' -f $Value
    if ($q -eq 0) { return "$hex (finished)" }
    if ($q -eq 0x100) { return "$hex (restart, then run again)" }
    return "$hex (update queued)"
}

function Format-SbServicing($Svc) {
    $t = 'not reported by this Windows'
    if ($Svc.Status) { $t = [string]$Svc.Status }
    if ($Svc.Error) { $t += ' (error ' + (Format-SbHex $Svc.Error) + ')' }
    $t
}

function Format-SbBootManager($Capable) {
    if ($null -eq $Capable) { return 'unknown (not reported)' }
    switch ([int]$Capable) {
        2 { 'Yes (PC starts with it)' }
        1 { 'Not yet (old boot manager)' }
        0 { 'No (2023 CA not in the DB)' }
        default { 'unknown (' + $Capable + ')' }
    }
}

function Format-SbTask($Task) {
    if (-not $Task.Exists) { return 'NOT FOUND' }
    if (-not $Task.LastRun) { return 'present, never run' }
    'last run {0:yyyy-MM-dd HH:mm}, result {1}' -f $Task.LastRun, (Format-SbHex $Task.LastResult)
}

function Format-SbBitLocker($Bl) {
    if (-not $Bl.Available) { return 'not available' }
    if (-not $Bl.On) { return 'off' }
    if ($Bl.RecoveryPassword) { return 'ON (recovery key exists)' }
    'ON (no recovery key protector!)'
}

function Format-SbOs($Os) {
    $t = $Os.Name
    if ($Os.Display) { $t += ' ' + $Os.Display }
    $t + (' (build {0}.{1})' -f $Os.Build, $Os.Ubr)
}

# Caption / Value / Level rows (Level: Ok, Warn, Error, Muted, Info)
function Get-SbStateRows($S) {
    $noUefi = ($S.Verdict -eq 'NoUefi')
    $rows = New-Object System.Collections.Generic.List[object]
    $add = { param($c, $v, $l) $rows.Add([pscustomobject]@{ Caption = $c; Value = [string]$v; Level = $l }) }

    if ($S.SecureBoot -eq $true) { & $add 'Secure Boot' 'Enabled' 'Ok' }
    elseif ($S.SecureBoot -eq $false) { & $add 'Secure Boot' 'DISABLED' 'Warn' }
    else { & $add 'Secure Boot' 'not available (legacy BIOS/CSM)' 'Muted' }

    & $add 'Windows' (Format-SbOs $S.Os) 'Info'

    $miss = 'Error'; if ($noUefi) { $miss = 'Muted' }
    if ($S.HasKek2023) { & $add 'KEK 2K CA 2023 (KEK)' 'Yes' 'Ok' } else { & $add 'KEK 2K CA 2023 (KEK)' 'No' $miss }
    if ($S.HasWinCa2023) { & $add 'Windows UEFI CA 2023 (DB)' 'Yes' 'Ok' } else { & $add 'Windows UEFI CA 2023 (DB)' 'No' $miss }

    $c = $S.Servicing.Capable
    $l = 'Muted'
    if ($null -ne $c) { if ($c -eq 2) { $l = 'Ok' } elseif ($c -eq 1) { $l = 'Warn' } else { $l = 'Error' } }
    & $add '2023 boot manager' (Format-SbBootManager $c) $l

    $l = 'Muted'
    if ($S.Servicing.Error) { $l = 'Error' }
    elseif ($S.Servicing.Status -eq 'Updated') { $l = 'Ok' }
    elseif ($S.Servicing.Status) { $l = 'Warn' }
    & $add 'Windows update status' (Format-SbServicing $S.Servicing) $l

    $l = 'Muted'
    if ($null -ne $S.AvailableUpdates -and ($S.AvailableUpdates -band (-bnot 0x4000)) -ne 0) { $l = 'Warn' }
    & $add 'AvailableUpdates' (Format-SbFlag $S.AvailableUpdates) $l

    $l = 'Ok'
    if (-not $S.Task.Exists) { if ($noUefi) { $l = 'Muted' } else { $l = 'Error' } }
    elseif (-not $S.Task.LastRun) { $l = 'Muted' }
    elseif ($S.Task.LastResult -ne 0) { $l = 'Warn' }
    & $add 'Secure-Boot-Update task' (Format-SbTask $S.Task) $l

    $l = 'Muted'; if ($S.BitLocker.On) { $l = 'Warn' }
    & $add ('BitLocker (' + $S.BitLocker.Drive + ')') (Format-SbBitLocker $S.BitLocker) $l

    if ($S.PendingReboot) { & $add 'Restart pending' 'Yes' 'Warn' } else { & $add 'Restart pending' 'No' 'Muted' }

    $rows.ToArray()
}

# One-line summary: Text and Level
function Get-SbVerdictText($S) {
    $t = ''; $l = 'Info'
    switch ($S.Verdict) {
        'NoUefi'        { $t = 'This PC does not use UEFI Secure Boot (legacy BIOS/CSM), or its Secure Boot variables cannot be read. There is nothing to update in the firmware.'; $l = 'Muted' }
        'Complete'      { $t = 'Up to date: the 2023 Secure Boot certificates and boot manager are in place.'; $l = 'Ok' }
        'CertsPresent'  { $t = 'The 2023 certificates are in the firmware (KEK and DB). This Windows build does not report the boot manager status.'; $l = 'Ok' }
        'RestartNeeded' { $t = 'Restart needed: the certificates are applied and the 2023 boot manager is installed at the next restart. After restarting, run this tool again.'; $l = 'Warn' }
        'InProgress'    { $t = 'Update in progress (AvailableUpdates = ' + (Format-SbFlag $S.AvailableUpdates) + '). Run the update again to start the next step.'; $l = 'Warn' }
        'Partial'       { $t = 'Partly updated. Missing: ' + ($S.Missing -join ', ') + '.'; $l = 'Warn' }
        default         { $t = 'Not updated: the 2023 Secure Boot certificates are not in the firmware yet.'; $l = 'Error' }
    }
    if ($S.SecureBoot -eq $false) { $t += ' Secure Boot is OFF.' }
    [pscustomobject]@{ Text = $t; Level = $l }
}

# Advice for known problems
function Get-SbHints($S) {
    $h = @()
    if ($S.Verdict -eq 'NoUefi') { return $h }
    if (-not $S.Task.Exists -and $S.Verdict -notin 'Complete', 'CertsPresent') {
        $h += 'The Secure-Boot-Update scheduled task is missing. Install the latest cumulative update for this Windows, then run this tool again.'
    }
    if ($S.SecureBoot -eq $false) {
        $h += 'Secure Boot is off. Windows can still install the certificates; turn Secure Boot on in the BIOS/UEFI setup afterwards and run this tool again to check.'
    }
    if ($S.Servicing.Error) {
        $e = 'Windows reported error ' + (Format-SbHex $S.Servicing.Error)
        if ($S.Servicing.ErrorEvent) { $e += (' (event {0}: {1})' -f $S.Servicing.ErrorEvent, (Get-SbEventMeaning ([int]$S.Servicing.ErrorEvent))) }
        $h += $e + '.'
    }
    if ($S.Verdict -notin 'Complete', 'CertsPresent' -and @($S.Events).Count -gt 0) {
        switch ($S.Events[0].Id) {
            1032 { $h += 'Windows held the update because BitLocker would ask for the recovery key. Suspend BitLocker for 2 restarts and run the update again.' }
            1795 { $h += 'The firmware refused the change. Look for a BIOS/UEFI update from the PC maker; Windows tries again at each restart.' }
            1796 { $h += 'The last attempt failed; Windows tries again at the next restart. If it keeps failing, look for a BIOS/UEFI update.' }
            1802 { $h += 'Microsoft blocks this update on this device because of a known firmware issue. Install the latest BIOS/UEFI update from the PC maker, then try again.' }
            1803 { $h += 'The firmware has no KEK update signed by the PC maker, so the KEK cannot be updated by Windows. Look for a BIOS/UEFI update from the PC maker.' }
        }
    }
    if ($S.BitLocker.On -and $S.Verdict -notin 'Complete', 'CertsPresent') {
        $h += 'BitLocker is on: have the 48-digit recovery key ready (https://aka.ms/myrecoverykey) or suspend BitLocker for 2 restarts.'
    }
    $h
}

# ----- Actions -----

# Windows 10 21H2/22H2 only: downloads KB5073724 from the Microsoft Update Catalog and installs it.
function Install-SbWin10Update($State) {
    $res = [pscustomobject]@{ Ok = $true; RebootRequired = $false }
    $os = $State.Os
    if (-not $os.IsWin10Client) { Write-SbLog ("Skipped: $SbKbId is only for Windows 10 21H2/22H2.") 'Muted'; return $res }
    if ($os.Ubr -ge $SbKbUbr) {
        Write-SbLog ('Skipped: this PC is at build {0}.{1}, so {2} or a later cumulative update is installed.' -f $os.Build, $os.Ubr, $SbKbId) 'Ok'
        return $res
    }
    if (-not $os.Arch) { Write-SbLog 'WARNING: unknown processor architecture; skipped.' 'Warn'; $res.Ok = $false; return $res }
    $ver = '21H2'; if ($os.Build -eq 19045) { $ver = '22H2' }
    $dir = Join-Path $env:TEMP 'Update-SecureBootCert'
    $file = $null
    try {
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

        Write-SbLog ("Looking up $SbKbId for Windows 10 Version $ver ($($os.Arch)) in the Microsoft Update Catalog...") 'Step'
        $page = Invoke-WebRequest -Uri ('https://www.catalog.update.microsoft.com/Search.aspx?q=' + $SbKbId) -UseBasicParsing -ErrorAction Stop
        $id = $null; $title = $null
        $rx = '(?s)id=["'']([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})_link["''][^>]*>(.*?)</a>'
        foreach ($m in [regex]::Matches($page.Content, $rx)) {
            $t = ($m.Groups[2].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()
            if ($t -match ('Windows 10 Version ' + $ver) -and $t -match ([regex]::Escape($os.Arch) + '-based') -and $t -notmatch 'Dynamic|Server') {
                $id = $m.Groups[1].Value; $title = $t; break
            }
        }
        if (-not $id) {
            Write-SbLog ('WARNING: {0} for Windows 10 Version {1} ({2}) was not found in the Catalog.' -f $SbKbId, $ver, $os.Arch) 'Warn'
            Write-SbLog ('         Manual download: https://www.catalog.update.microsoft.com/Search.aspx?q=' + $SbKbId) 'Muted'
            $res.Ok = $false; return $res
        }
        Write-SbLog ('Found: ' + $title)

        $json = '[{"size":0,"languages":"","uidInfo":"' + $id + '","updateID":"' + $id + '"}]'
        $dlg = Invoke-WebRequest -Uri 'https://www.catalog.update.microsoft.com/DownloadDialog.aspx' -Method Post -Body @{ updateIDs = $json } -UseBasicParsing -ErrorAction Stop
        $urls = @([regex]::Matches($dlg.Content, 'https?://[^''"\s<>]+?\.(?:msu|cab)\b') | ForEach-Object { $_.Value } | Select-Object -Unique)
        $url = $urls | Where-Object { $_ -match '\.msu$' } | Select-Object -First 1
        if (-not $url) { $url = $urls | Select-Object -First 1 }
        if (-not $url) { Write-SbLog 'ERROR: the Catalog did not return a download link.' 'Error'; $res.Ok = $false; return $res }
        $urlHost = ([uri]$url).Host
        if ($urlHost -notmatch '(^|\.)(windowsupdate\.com|microsoft\.com)$') {
            Write-SbLog ('ERROR: unexpected download host ' + $urlHost + '; not downloading.') 'Error'; $res.Ok = $false; return $res
        }

        if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        $file = Join-Path $dir ([IO.Path]::GetFileName(([uri]$url).AbsolutePath))
        Write-SbLog ('Downloading ' + [IO.Path]::GetFileName($file) + ' (several hundred MB, please wait)...') 'Step'
        $wc = New-Object System.Net.WebClient
        try {
            try { $wc.DownloadFile(($url -replace '^http://', 'https://'), $file) } catch { $wc.DownloadFile($url, $file) }
        } finally { $wc.Dispose() }

        $sig = Get-AuthenticodeSignature -FilePath $file
        if ($sig.Status -eq 'HashMismatch' -or ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -notmatch 'Microsoft')) {
            Write-SbLog ('ERROR: the downloaded file failed the signature check (' + $sig.Status + '); not installing.') 'Error'
            $res.Ok = $false; return $res
        }

        Write-SbLog 'Installing (10-30 minutes; do not turn the PC off)...' 'Step'
        if ($file -match '\.msu$') {
            $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wusa.exe') -ArgumentList ('"' + $file + '" /quiet /norestart') -Wait -PassThru -WindowStyle Hidden
        } else {
            $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\dism.exe') -ArgumentList ('/Online /Add-Package /PackagePath:"' + $file + '" /Quiet /NoRestart') -Wait -PassThru -WindowStyle Hidden
        }
        $code = [int64]$p.ExitCode
        switch ($code) {
            0           { Write-SbLog ('OK: ' + $SbKbId + ' installed.') 'Ok' }
            3010        { Write-SbLog ('OK: ' + $SbKbId + ' installed; restart required.') 'Ok'; $res.RebootRequired = $true }
            2359302     { Write-SbLog ('OK: ' + $SbKbId + ' is already installed.') 'Ok' }
            -2145124329 {
                Write-SbLog ('WARNING: ' + $SbKbId + ' is not applicable to this PC (0x80240017).') 'Warn'
                Write-SbLog '         Usually a newer cumulative update is installed, or the PC has no ESU license. The certificate step does not need it.' 'Muted'
                $res.Ok = $false
            }
            default     { Write-SbLog ('WARNING: the installer returned ' + (Format-SbHex $code) + '.') 'Warn'; $res.Ok = $false }
        }
        if ($res.Ok) {
            Write-SbLog 'NOTE: without an ESU license, Windows can remove this update again after the restart. The certificate step does not depend on it.' 'Muted'
        }
    } catch {
        Write-SbLog ('WARNING: ' + $SbKbId + ' failed: ' + $_.Exception.Message) 'Warn'
        Write-SbLog '         Continuing; the certificate step does not depend on it.' 'Muted'
        $res.Ok = $false
    } finally {
        if ($file -and (Test-Path -LiteralPath $file)) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
    }
    $res
}

# Installs pending Windows software updates (not drivers, not hidden ones).
function Install-SbWindowsUpdates {
    $res = [pscustomobject]@{ Ok = $false; RebootRequired = $false }
    try {
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $searcher = $session.CreateUpdateSearcher()
        Write-SbLog 'Searching for pending Windows updates (software only; this can take several minutes)...' 'Step'
        $found = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
        $coll = New-Object -ComObject 'Microsoft.Update.UpdateColl'
        foreach ($u in $found.Updates) {
            if ($u.InstallationBehavior.CanRequestUserInput) { Write-SbLog ('  skipped (needs user input): ' + $u.Title) 'Muted'; continue }
            if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch { } }
            [void]$coll.Add($u)
            Write-SbLog ('  * ' + $u.Title)
        }
        if ($coll.Count -eq 0) { Write-SbLog 'OK: no pending updates.' 'Ok'; $res.Ok = $true; return $res }

        Write-SbLog ('Downloading {0} update(s)...' -f $coll.Count) 'Step'
        $dl = $session.CreateUpdateDownloader()
        $dl.Updates = $coll
        $dr = $dl.Download()
        if ($dr.ResultCode -ne 2 -and $dr.ResultCode -ne 3) { Write-SbLog ('WARNING: download result code {0}.' -f $dr.ResultCode) 'Warn' }

        Write-SbLog 'Installing (please wait)...' 'Step'
        $inst = $session.CreateUpdateInstaller()
        $inst.Updates = $coll
        $ir = $inst.Install()
        $res.RebootRequired = [bool]$ir.RebootRequired
        # OperationResultCode: 2 succeeded, 3 succeeded with errors, 4 failed, 5 aborted
        for ($i = 0; $i -lt $coll.Count; $i++) {
            $ur = $ir.GetUpdateResult($i)
            if ($ur.ResultCode -ne 2) { Write-SbLog ('  not installed (code {0}, {1}): {2}' -f $ur.ResultCode, (Format-SbHex $ur.HResult), $coll.Item($i).Title) 'Warn' }
        }
        switch ($ir.ResultCode) {
            2       { Write-SbLog 'OK: updates installed.' 'Ok'; $res.Ok = $true }
            3       { Write-SbLog 'OK: updates installed, some with errors (see above).' 'Warn'; $res.Ok = $true }
            4       { Write-SbLog 'ERROR: installation failed.' 'Error' }
            5       { Write-SbLog 'ERROR: installation aborted.' 'Error' }
            default { Write-SbLog ('WARNING: result code {0}.' -f $ir.ResultCode) 'Warn' }
        }
        if ($res.RebootRequired) { Write-SbLog 'A restart is required to finish installing the updates.' 'Warn' }
    } catch {
        Write-SbLog ('WARNING: Windows Update failed: ' + $_.Exception.Message) 'Warn'
    }
    $res
}

# Suspends BitLocker on the system drive for N restarts (it resumes by itself).
function Suspend-SbBitLocker([int]$RebootCount = 2) {
    try {
        $vol = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName 'Win32_EncryptableVolume' -Filter ("DriveLetter='{0}'" -f $env:SystemDrive) -ErrorAction Stop
        if (-not $vol) { Write-SbLog 'BitLocker is not available; nothing to suspend.' 'Muted'; return $true }
        if ($vol.ProtectionStatus -ne 1) { Write-SbLog ('BitLocker protection is already off on ' + $env:SystemDrive + '.') 'Muted'; return $true }
        $r = Invoke-CimMethod -InputObject $vol -MethodName 'DisableKeyProtectors' -Arguments @{ DisableCount = [uint32]$RebootCount } -ErrorAction Stop
        if ($r.ReturnValue -eq 0) {
            Write-SbLog ('OK: BitLocker suspended on {0} for the next {1} restarts; it turns back on by itself.' -f $env:SystemDrive, $RebootCount) 'Ok'
            return $true
        }
        Write-SbLog ('WARNING: BitLocker could not be suspended (code ' + (Format-SbHex $r.ReturnValue) + ').') 'Warn'
    } catch {
        Write-SbLog ('WARNING: BitLocker could not be suspended: ' + $_.Exception.Message) 'Warn'
    }
    $false
}

# Asks Windows to install the 2023 certificates (and boot manager) and starts the Secure-Boot-Update task.
# Never overwrites an update that Windows has already queued.
function Start-SbDeployment($State, [switch]$DbOnly) {
    $res = [pscustomobject]@{ Ok = $false; RebootRequired = $false }
    if ($null -eq $State.SecureBoot -or -not $State.FirmwareReadable) {
        Write-SbLog 'Skipped: UEFI Secure Boot is not available on this PC.' 'Muted'
        return $res
    }
    if (-not $State.Task.Exists) {
        Write-SbLog 'ERROR: the Secure-Boot-Update scheduled task was not found. Install the latest cumulative update for this Windows, then run this tool again.' 'Error'
        return $res
    }
    try {
        $au = $State.AvailableUpdates
        $queued = 0
        if ($null -ne $au) { $queued = $au -band (-bnot 0x4000) }
        if ($queued -ne 0) {
            Write-SbLog ('Windows already has an update queued (AvailableUpdates = 0x{0:X}); leaving it as is.' -f $au)
        } else {
            $value = $SbFullValue; $what = 'full update: KEK, DB certificates and boot manager'
            if ($DbOnly) { $value = $SbDbValue; $what = 'old method: Windows UEFI CA 2023 in the DB only' }
            Write-SbLog ('Setting AvailableUpdates = 0x{0:X} ({1})...' -f $value, $what) 'Step'
            Set-ItemProperty -Path $SbKey -Name 'AvailableUpdates' -Value $value -Type DWord -ErrorAction Stop
            Write-SbLog 'OK: value set.' 'Ok'
        }

        Write-SbLog 'Starting the Secure-Boot-Update task...' 'Step'
        Start-ScheduledTask -TaskPath $SbTaskPath -TaskName $SbTaskName -ErrorAction Stop
        Start-Sleep -Seconds 3
        $deadline = (Get-Date).AddSeconds(180)
        while ((Get-Date) -lt $deadline) {
            $t = Get-ScheduledTask -TaskPath $SbTaskPath -TaskName $SbTaskName -ErrorAction SilentlyContinue
            if (-not $t -or [string]$t.State -ne 'Running') { break }
            Start-Sleep -Seconds 2
        }
        $task = Get-SbTask
        $svc = Get-SbServicing
        Write-SbLog ('Task: ' + (Format-SbTask $task) + '.')
        Write-SbLog ('AvailableUpdates is now ' + (Format-SbFlag (Get-SbAvailableUpdates)) + '.')
        Write-SbLog ('Windows update status: ' + (Format-SbServicing $svc) + '.')
        if ($svc.Error) {
            $m = ''
            if ($svc.ErrorEvent) { $m = ' - event ' + $svc.ErrorEvent + ': ' + (Get-SbEventMeaning ([int]$svc.ErrorEvent)) }
            Write-SbLog ('WARNING: Windows reported error ' + (Format-SbHex $svc.Error) + $m) 'Warn'
        }
        $res.Ok = $true
        $res.RebootRequired = $true
    } catch {
        Write-SbLog ('ERROR: ' + $_.Exception.Message) 'Error'
    }
    $res
}

# <<< SB-ENGINE END >>>
'@
. ([scriptblock]::Create($SbEngine))

# ===== Traditional Chinese (zh-TW) =====
# Windows set to Traditional Chinese (zh-TW/HK/MO) shows the window in Traditional
# Chinese; otherwise it stays English. SBGUI_LANG=zh-TW or SBGUI_LANG=en overrides.
$script:UiLang = 'en'
try {
    $cc = [System.Globalization.CultureInfo]::CurrentCulture
    $uc = [System.Globalization.CultureInfo]::CurrentUICulture
    if (($cc.Name -match '^zh-(TW|HK|MO)$') -or ($uc.Name -match '^zh-(TW|HK|MO)$')) { $script:UiLang = 'zh-TW' }
} catch { }
if ($env:SBGUI_LANG -in 'zh-TW', 'zh', 'zh-HK', 'zh-MO') { $script:UiLang = 'zh-TW' }
elseif ($env:SBGUI_LANG -eq 'en') { $script:UiLang = 'en' }

$script:Zh = @{
    # --- window ---
    'Secure Boot Certificate Updater'                            = '安全開機憑證更新工具'
    'What to do:'                                                = '要做什麼：'
    "Install the 2023 Secure Boot certificates and boot manager (Microsoft's full update)" = '安裝 2023 安全開機憑證與開機管理程式（Microsoft 完整更新）'
    'Old method: only add Windows UEFI CA 2023 to the DB (0x40), not the KEK or the boot manager' = '舊方法：只把 Windows UEFI CA 2023 加入 DB（0x40），不更新 KEK 或開機管理程式'
    'Install all pending Windows updates first (software only; can take a long time)' = '先安裝所有待處理的 Windows 更新（僅軟體更新，可能很久）'
    'Suspend BitLocker for the next 2 restarts (it turns back on by itself)' = '暫停 BitLocker 兩次重新開機（之後會自動恢復）'
    'Refresh'                                                    = '重新整理'
    'Start update'                                               = '開始更新'
    'Continue update'                                            = '繼續更新'
    'Restart now'                                                = '立即重新開機'
    'Open log folder'                                            = '開啟記錄資料夾'
    'Certificates in the firmware'                               = '韌體中的憑證'
    'Recent Secure Boot events'                                  = '最近的安全開機事件'
    'Store'                                                      = '存放區'
    'Certificate'                                                = '憑證'
    'Expires'                                                    = '到期日'
    'Status'                                                     = '狀態'
    'Used for'                                                   = '用途'
    'Time'                                                       = '時間'
    'Event'                                                      = '事件'
    'Meaning'                                                    = '說明'
    'Reading the state...'                                       = '正在讀取狀態…'
    'State: '                                                    = '狀態：'
    '--- State at '                                              = '--- 狀態於 '
    'Unexpected error: '                                         = '未預期的錯誤：'
    'Line '                                                      = '行 '
    'Nothing is changed until you click Start update and confirm.' = '在按下「開始更新」並確認之前，不會變更任何設定。'
    'Restarts are needed. If BitLocker is on, have the recovery key ready (aka.ms/myrecoverykey) or suspend it. Use at your own risk.' = '需要重新開機。若啟用 BitLocker，請備妥復原金鑰（aka.ms/myrecoverykey）或先暫停；使用風險自負。'
    'Could not read the certificates from the firmware (Secure Boot not available?)' = '無法從韌體讀取憑證（安全開機無法使用？）'
    'No Secure Boot servicing events in the System log'          = '系統記錄中沒有安全開機維護事件'
    'Restart the PC (button above). Then open this tool again: it starts the next step and confirms the result.' = '請重新開機（上方按鈕），然後再開一次本工具：它會進行下一步並確認結果。'
    'Restarting in 30 seconds (cancel with: shutdown /a)...'     = '將於 30 秒後重新開機（可用 shutdown /a 取消）…'
    'Cancelled. Nothing was changed.'                            = '已取消，沒有變更任何設定。'
    'Tick at least one action.'                                  = '請至少勾選一項動作。'
    'The update is still running. Wait until it finishes, then close the window.' = '更新仍在執行，請等它結束後再關閉視窗。'
    'Administrator rights are needed. Open the file again and accept the prompt.' = '需要系統管理員權限。請重新開啟本檔案並接受提示。'
    'Secure Boot'                                                = '安全開機'
    'Restart'                                                    = '重新開機'
    'Secure Boot certificate update (Update-SecureBootCert)'     = '安全開機憑證更新（Update-SecureBootCert）'

    # --- state rows ---
    'Windows'                                                    = 'Windows'
    'KEK 2K CA 2023 (KEK)'                                       = 'KEK 2K CA 2023（KEK）'
    'Windows UEFI CA 2023 (DB)'                                  = 'Windows UEFI CA 2023（DB）'
    '2023 boot manager'                                          = '2023 開機管理程式'
    'Windows update status'                                      = 'Windows 更新狀態'
    'Secure-Boot-Update task'                                    = 'Secure-Boot-Update 排程工作'
    'Restart pending'                                            = '有待重新開機'
    'Enabled'                                                    = '已啟用'
    'DISABLED'                                                   = '已停用'
    'not available (legacy BIOS/CSM)'                            = '無法使用（傳統 BIOS/CSM）'
    'Yes'                                                        = '是'
    'No'                                                         = '否'
    'Yes (PC starts with it)'                                    = '是（電腦已用它開機）'
    'Not yet (old boot manager)'                                 = '尚未（舊的開機管理程式）'
    'No (2023 CA not in the DB)'                                 = '否（DB 中沒有 2023 CA）'
    'unknown (not reported)'                                     = '未知（未回報）'
    'not reported by this Windows'                               = '此版 Windows 未回報'
    'Updated'                                                    = '已更新'
    'InProgress'                                                 = '進行中'
    'Error'                                                      = '錯誤'
    'not set'                                                    = '未設定'
    '0 (nothing queued)'                                         = '0（沒有排隊的更新）'
    'NOT FOUND'                                                  = '找不到'
    'present, never run'                                         = '存在，尚未執行'
    'off'                                                        = '關閉'
    'not available'                                              = '無法使用'
    'ON (recovery key exists)'                                   = '開啟（有復原金鑰）'
    'ON (no recovery key protector!)'                            = '開啟（沒有復原金鑰保護！）'

    # --- summary ---
    'This PC does not use UEFI Secure Boot (legacy BIOS/CSM), or its Secure Boot variables cannot be read. There is nothing to update in the firmware.' = '這台電腦沒有使用 UEFI 安全開機（傳統 BIOS/CSM），或無法讀取安全開機變數；韌體沒有需要更新的項目。'
    'Up to date: the 2023 Secure Boot certificates and boot manager are in place.' = '已是最新：2023 安全開機憑證與開機管理程式都已就位。'
    'The 2023 certificates are in the firmware (KEK and DB). This Windows build does not report the boot manager status.' = '2023 憑證已在韌體中（KEK 與 DB）；此版 Windows 沒有回報開機管理程式狀態。'
    'Restart needed: the certificates are applied and the 2023 boot manager is installed at the next restart. After restarting, run this tool again.' = '需要重新開機：憑證已套用，2023 開機管理程式會在下次重新開機時安裝；重新開機後請再執行本工具。'
    'Not updated: the 2023 Secure Boot certificates are not in the firmware yet.' = '尚未更新：韌體中還沒有 2023 安全開機憑證。'

    # --- hints ---
    'The Secure-Boot-Update scheduled task is missing. Install the latest cumulative update for this Windows, then run this tool again.' = '找不到 Secure-Boot-Update 排程工作。請先安裝此版 Windows 最新的累積更新，然後再執行本工具。'
    'Secure Boot is off. Windows can still install the certificates; turn Secure Boot on in the BIOS/UEFI setup afterwards and run this tool again to check.' = '安全開機已關閉。Windows 仍可安裝憑證；之後請在 BIOS/UEFI 設定中開啟安全開機，再執行本工具檢查。'
    'Windows held the update because BitLocker would ask for the recovery key. Suspend BitLocker for 2 restarts and run the update again.' = 'Windows 暫緩更新，因為 BitLocker 會要求復原金鑰。請暫停 BitLocker 兩次重新開機，然後再執行更新。'
    'The firmware refused the change. Look for a BIOS/UEFI update from the PC maker; Windows tries again at each restart.' = '韌體拒絕這項變更。請找電腦製造商的 BIOS/UEFI 更新；Windows 會在每次重新開機時再試。'
    'The last attempt failed; Windows tries again at the next restart. If it keeps failing, look for a BIOS/UEFI update.' = '上次嘗試失敗；Windows 會在下次重新開機時再試。若持續失敗，請找 BIOS/UEFI 更新。'
    'Microsoft blocks this update on this device because of a known firmware issue. Install the latest BIOS/UEFI update from the PC maker, then try again.' = '因為已知的韌體問題，Microsoft 在這台裝置上封鎖了此更新。請安裝電腦製造商最新的 BIOS/UEFI 更新後再試。'
    'The firmware has no KEK update signed by the PC maker, so the KEK cannot be updated by Windows. Look for a BIOS/UEFI update from the PC maker.' = '韌體沒有由電腦製造商簽署的 KEK 更新，因此 Windows 無法更新 KEK。請找電腦製造商的 BIOS/UEFI 更新。'
    'BitLocker is on: have the 48-digit recovery key ready (https://aka.ms/myrecoverykey) or suspend BitLocker for 2 restarts.' = 'BitLocker 已開啟：請備妥 48 位數復原金鑰（https://aka.ms/myrecoverykey），或暫停 BitLocker 兩次重新開機。'

    # --- certificates ---
    'Valid'                                                      = '有效'
    'Expired'                                                    = '已過期'
    'Expires soon'                                               = '即將到期'
    'Signs updates to DB and DBX'                                = '簽署 DB 與 DBX 的更新'
    'Windows boot manager'                                       = 'Windows 開機管理程式'
    'Third-party boot loaders and option ROMs'                   = '第三方開機載入程式與 Option ROM'
    'Third-party boot loaders (Linux shim, tools)'               = '第三方開機載入程式（Linux shim、工具）'
    'Third-party option ROMs (graphics, network)'                = '第三方 Option ROM（顯示卡、網路）'
    'Added by the PC maker or another vendor'                    = '由電腦製造商或其他廠商加入'

    # --- events ---
    'Not applied: BitLocker would have asked for the recovery key' = '未套用：BitLocker 會要求復原金鑰'
    'DBX update postponed: an old, possibly revoked boot manager is on the EFI partition' = 'DBX 更新延後：EFI 磁碟分割上有舊的、可能已被撤銷的開機管理程式'
    'DBX updated'                                                = 'DBX 已更新'
    'DB updated'                                                 = 'DB 已更新'
    'DBX updated: Windows Production PCA 2011 revoked'           = 'DBX 已更新：Windows Production PCA 2011 已撤銷'
    'DBX updated: old boot manager versions blocked'             = 'DBX 已更新：舊版開機管理程式已封鎖'
    'KEK updated with Microsoft Corporation KEK 2K CA 2023'      = 'KEK 已更新為 Microsoft Corporation KEK 2K CA 2023'
    'DB updated with Microsoft Option ROM UEFI CA 2023'          = 'DB 已加入 Microsoft Option ROM UEFI CA 2023'
    'DB updated with Microsoft UEFI CA 2023'                     = 'DB 已加入 Microsoft UEFI CA 2023'
    'The firmware returned an error; Windows tries again at the next restart' = '韌體回傳錯誤；Windows 會在下次重新開機時再試'
    'Unexpected error; Windows tries again at the next restart'   = '未預期的錯誤；Windows 會在下次重新開機時再試'
    'DBX update blocked: Windows UEFI CA 2023 is not in the DB'  = 'DBX 更新被封鎖：DB 中沒有 Windows UEFI CA 2023'
    'DBX update blocked: the boot manager is not signed with Windows UEFI CA 2023' = 'DBX 更新被封鎖：開機管理程式不是用 Windows UEFI CA 2023 簽署'
    'Boot manager signed with Windows UEFI CA 2023 installed'    = '已安裝以 Windows UEFI CA 2023 簽署的開機管理程式'
    'A restart is needed before the update can continue'         = '需要重新開機才能繼續更新'
    'The 2023 certificates/boot manager are not fully applied to the firmware yet' = '2023 憑證／開機管理程式尚未完整套用到韌體'
    'Blocked by Microsoft: known firmware issue on this device'  = '已被 Microsoft 封鎖：這台裝置有已知的韌體問題'
    "KEK update not possible: no KEK signed by this PC maker's platform key (PK)" = '無法更新 KEK：沒有由這台電腦製造商平台金鑰（PK）簽署的 KEK'
    'Finished: this PC has the 2023 Secure Boot certificates and boot manager' = '已完成：這台電腦已有 2023 安全開機憑證與開機管理程式'
    'Secure Boot servicing event'                                = '安全開機維護事件'

    # --- log: step headers and fixed lines ---
    'Step: Windows 10 cumulative update (KB5073724)'             = '步驟：Windows 10 累積更新（KB5073724）'
    'Step: Windows Update'                                       = '步驟：Windows 更新'
    'Step: BitLocker'                                            = '步驟：BitLocker'
    'Step: Secure Boot certificates'                             = '步驟：安全開機憑證'
    'Finished.'                                                  = '完成。'
    'Finished, with warnings or errors (see above).'             = '完成，但有警告或錯誤（見上方）。'
    'Searching for pending Windows updates (software only; this can take several minutes)...' = '正在搜尋待處理的 Windows 更新（僅軟體更新，可能需要幾分鐘）…'
    'OK: no pending updates.'                                    = 'OK：沒有待處理的更新。'
    'Installing (please wait)...'                                = '正在安裝（請稍候）…'
    'OK: updates installed.'                                     = 'OK：更新已安裝。'
    'OK: updates installed, some with errors (see above).'       = 'OK：更新已安裝，部分有錯誤（見上方）。'
    'ERROR: installation failed.'                                = '錯誤：安裝失敗。'
    'ERROR: installation aborted.'                               = '錯誤：安裝已中止。'
    'A restart is required to finish installing the updates.'    = '需要重新開機才能完成安裝這些更新。'
    'BitLocker is not available; nothing to suspend.'            = 'BitLocker 無法使用，沒有需要暫停的項目。'
    'Skipped: UEFI Secure Boot is not available on this PC.'     = '略過：這台電腦沒有 UEFI 安全開機。'
    'ERROR: the Secure-Boot-Update scheduled task was not found. Install the latest cumulative update for this Windows, then run this tool again.' = '錯誤：找不到 Secure-Boot-Update 排程工作。請先安裝此版 Windows 最新的累積更新，然後再執行本工具。'
    'Starting the Secure-Boot-Update task...'                    = '正在啟動 Secure-Boot-Update 排程工作…'
    'OK: value set.'                                             = 'OK：機碼值已設定。'
    'WARNING: unknown processor architecture; skipped.'          = '警告：未知的處理器架構，已略過。'
    'ERROR: the Catalog did not return a download link.'         = '錯誤：Microsoft Update Catalog 沒有回傳下載連結。'
    'Installing (10-30 minutes; do not turn the PC off)...'      = '正在安裝（10–30 分鐘，請勿關機）…'
    'NOTE: without an ESU license, Windows can remove this update again after the restart. The certificate step does not depend on it.' = '注意：若沒有 ESU 授權，Windows 可能在重新開機後再次移除這個更新；憑證步驟不依賴它。'
    '         Continuing; the certificate step does not depend on it.' = '         繼續執行；憑證步驟不依賴這個更新。'
    '         Usually a newer cumulative update is installed, or the PC has no ESU license. The certificate step does not need it.' = '         通常是已安裝較新的累積更新，或這台電腦沒有 ESU 授權；憑證步驟不需要它。'
    'Skipped: KB5073724 is only for Windows 10 21H2/22H2.'       = '略過：KB5073724 只適用於 Windows 10 21H2/22H2。'
    'OK: KB5073724 installed.'                                   = 'OK：KB5073724 已安裝。'
    'OK: KB5073724 installed; restart required.'                 = 'OK：KB5073724 已安裝，需要重新開機。'
    'OK: KB5073724 is already installed.'                        = 'OK：KB5073724 已經安裝。'
    'WARNING: KB5073724 is not applicable to this PC (0x80240017).' = '警告：KB5073724 不適用於這台電腦（0x80240017）。'
    'full update: KEK, DB certificates and boot manager'          = '完整更新：KEK、DB 憑證與開機管理程式'
    'old method: Windows UEFI CA 2023 in the DB only'             = '舊方法：只把 Windows UEFI CA 2023 加入 DB'
    'Windows already has an update queued (AvailableUpdates = 0x{0:X}); leaving it as is.' = 'Windows 已有排隊的更新（AvailableUpdates = 0x{0:X}），保持原狀。'
}

# Dynamic text: first match wins, so specific patterns go before the generic ones.
$script:ZhRules = @(
    @('^=== (?<d>.+) - update started ===$', '=== ${d} - 更新開始 ==='),
    @('^BitLocker \((?<d>[A-Za-z]:)\)$', 'BitLocker（${d}）'),
    @('^Install (?<kb>\S+) first \(only Windows 10 21H2/22H2 older than build \.(?<u>\d+)\)$', '先安裝 ${kb}（僅限 Windows 10 21H2/22H2，組建低於 .${u}）'),
    @('^Secure Boot Certificate Updater v(?<v>.+)$', '安全開機憑證更新工具 v${v}'),
    @('^Log file: (?<p>.+)$', '記錄檔：${p}'),
    @('^Windows reported error (?<h>0x[0-9A-Fa-f]+)$', 'Windows 回報錯誤 ${h}'),
    @('^Skipped: this PC is at build (?<b>[0-9.]+), so (?<kb>\S+) or a later cumulative update is installed\.$', '略過：本機組建為 ${b}，已安裝 ${kb} 或更新的累積更新。'),
    @('^Looking up (?<kb>\S+) for Windows 10 Version (?<v>.+) \((?<a>[^)]+)\) in the Microsoft Update Catalog\.\.\.$', '正在 Microsoft Update Catalog 查詢 ${kb}（Windows 10 ${v}，${a}）…'),
    @('^WARNING: (?<kb>\S+) for Windows 10 Version (?<v>.+) \((?<a>[^)]+)\) was not found in the Catalog\.$', '警告：在 Microsoft Update Catalog 找不到 ${kb}（Windows 10 ${v}，${a}）。'),
    @('^\s*Manual download: (?<u>\S+)$', '         手動下載：${u}'),
    @('^Found: (?<t>.+)$', '找到：${t}'),
    @('^Downloading (?<f>.+) \(several hundred MB, please wait\)\.\.\.$', '正在下載 ${f}（數百 MB，請稍候）…'),
    @('^Downloading (?<n>\d+) update\(s\)\.\.\.$', '正在下載 ${n} 個更新…'),
    @('^ERROR: unexpected download host (?<h>.+); not downloading\.$', '錯誤：非預期的下載主機 ${h}，不會下載。'),
    @('^ERROR: the downloaded file failed the signature check \((?<s>.*)\); not installing\.$', '錯誤：下載的檔案簽章檢查失敗（${s}），不會安裝。'),
    @('^WARNING: the installer returned (?<h>0x[0-9A-Fa-f]+)\.$', '警告：安裝程式回傳 ${h}。'),
    @('^WARNING: (?<kb>\S+) failed: (?<m>.+)$', '警告：${kb} 失敗：${m}'),
    @('^  skipped \(needs user input\): (?<t>.+)$', '  已略過（需要使用者輸入）：${t}'),
    @('^  not installed \(code (?<c>-?\d+), (?<h>0x[0-9A-Fa-f]+)\): (?<t>.+)$', '  未安裝（代碼 ${c}，${h}）：${t}'),
    @('^WARNING: download result code (?<c>-?\d+)\.$', '警告：下載結果代碼 ${c}。'),
    @('^WARNING: result code (?<c>-?\d+)\.$', '警告：結果代碼 ${c}。'),
    @('^WARNING: Windows Update failed: (?<m>.+)$', '警告：Windows 更新失敗：${m}'),
    @('^BitLocker protection is already off on (?<d>.+)\.$', 'BitLocker 保護已在 ${d} 關閉。'),
    @('^OK: BitLocker suspended on (?<d>.+) for the next (?<n>\d+) restarts; it turns back on by itself\.$', 'OK：已暫停 ${d} 的 BitLocker，接下來 ${n} 次重新開機有效；之後會自動恢復。'),
    @('^WARNING: BitLocker could not be suspended \((?<h>0x[0-9A-Fa-f]+)\)\.$', '警告：無法暫停 BitLocker（${h}）。'),
    @('^WARNING: BitLocker could not be suspended: (?<m>.+)$', '警告：無法暫停 BitLocker：${m}'),
    @('^Windows already has an update queued \(AvailableUpdates = (?<v>0x[0-9A-Fa-f]+)\); leaving it as is\.$', 'Windows 已有排隊的更新（AvailableUpdates = ${v}），保持原狀。'),
    @('^Task: (?<t>.+)\.$', '排程工作：${t}。'),
    @('^last run (?<d>[0-9-]+ [0-9:]+), result (?<r>0x[0-9A-Fa-f]+)$', '上次執行 ${d}，結果 ${r}'),
    @('^(?<h>0x[0-9A-Fa-f]+) \(finished\)$', '${h}（已完成）'),
    @('^(?<h>0x[0-9A-Fa-f]+) \(restart, then run again\)$', '${h}（重新開機後再執行一次）'),
    @('^(?<h>0x[0-9A-Fa-f]+) \(update queued\)$', '${h}（已有排隊的更新）'),
    @('^(?<n>.+) \(build (?<b>[0-9.]+)\)$', '${n}（組建 ${b}）'),
    @('^unknown \((?<x>.*)\)$', '未知（${x}）'),
    @('^Updated \(error (?<h>0x[0-9A-Fa-f]+)\)$', '已更新（錯誤 ${h}）'),
    @('^InProgress \(error (?<h>0x[0-9A-Fa-f]+)\)$', '進行中（錯誤 ${h}）'),
    @('^Error \(error (?<h>0x[0-9A-Fa-f]+)\)$', '錯誤（錯誤 ${h}）'),
    @('^  \(more in the log below\)$', '（更多請見下方記錄）'),
    @('^ERROR: (?<m>.+)$', '錯誤：${m}'),
    @('^WARNING: (?<m>.+)$', '警告：${m}')
)

function Get-Zh([string]$t) {
    if ($script:UiLang -ne 'zh-TW') { return $t }
    if ([string]::IsNullOrEmpty($t)) { return $t }
    if ($t.EndsWith(' Secure Boot is OFF.')) { return (Get-Zh $t.Substring(0, $t.Length - 20)) + ' 安全開機已關閉。' }
    if ($script:Zh.ContainsKey($t)) { return $script:Zh[$t] }
    if ($t -match '^Update in progress \(AvailableUpdates = (?<v>.+)\)\. Run the update again to start the next step\.$') {
        return '更新進行中（AvailableUpdates = ' + $Matches.v + '）。請再執行一次更新以進行下一步。'
    }
    if ($t -match '^Partly updated\. Missing: (?<m>.+)\.$') { return '只完成一部分。缺少：' + ($Matches.m -replace ', ', '、') + '。' }
    if ($t -match '^Setting AvailableUpdates = (?<v>0x[0-9A-Fa-f]+) \((?<w>.*)\)\.\.\.$') { return '正在設定 AvailableUpdates = ' + $Matches.v + '（' + (Get-Zh $Matches.w) + '）…' }
    if ($t -match '^WARNING: Windows reported error (?<h>0x[0-9A-Fa-f]+)(?: - event (?<e>\d+): (?<m>.*))?$') {
        $ev = ''
        if ($Matches.e) { $ev = ' - 事件 ' + $Matches.e + '：' + (Get-Zh $Matches.m) }
        return '警告：Windows 回報錯誤 ' + $Matches.h + $ev
    }
    if ($t -match '^Windows reported error (?<h>0x[0-9A-Fa-f]+)(?: \(event (?<e>\d+): (?<m>.*)\))?\.$') {
        $ev = ''
        if ($Matches.e) { $ev = '（事件 ' + $Matches.e + '：' + (Get-Zh $Matches.m) + '）' }
        return 'Windows 回報錯誤 ' + $Matches.h + $ev + '。'
    }
    if ($t -match '^Windows update status: (?<s>.+)\.$') { return 'Windows 更新狀態：' + (Get-Zh $Matches.s) + '。' }
    if ($t -match '^(?<p>Task): (?<t>.+)\.$') { return '排程工作：' + (Get-Zh $Matches.t) + '。' }
    if ($t -match '^AvailableUpdates is now (?<v>.+)\.$') { return 'AvailableUpdates 現在是 ' + (Get-Zh $Matches.v) + '。' }
    foreach ($r in $script:ZhRules) {
        if ($t -match $r[0]) { return ($t -replace $r[0], $r[1]) }
    }
    return $t
}

# Runs in a background runspace: the engine plus these lines. $sync and $opts come from the window.
$SbWorker = @'
function Write-SbLog([string]$Text, [string]$Level = 'Info') { $sync.Queue.Enqueue($Text) }
$result = [pscustomobject]@{ Restart = $false; Failed = $false }
try {
    Write-SbLog ''
    Write-SbLog ('=== ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' - update started ===')
    $st = Get-SbState
    if ($opts.Kb) {
        Write-SbLog ''
        Write-SbLog ('Step: Windows 10 cumulative update (' + $SbKbId + ')')
        $r = Install-SbWin10Update -State $st
        if ($r.RebootRequired) { $result.Restart = $true }
        if (-not $r.Ok) { $result.Failed = $true }
    }
    if ($opts.Wu) {
        Write-SbLog ''
        Write-SbLog 'Step: Windows Update'
        $r = Install-SbWindowsUpdates
        if ($r.RebootRequired) { $result.Restart = $true }
        if (-not $r.Ok) { $result.Failed = $true }
    }
    if ($opts.Bl) {
        Write-SbLog ''
        Write-SbLog 'Step: BitLocker'
        if (-not (Suspend-SbBitLocker -RebootCount 2)) { $result.Failed = $true }
    }
    if ($opts.Deploy) {
        Write-SbLog ''
        Write-SbLog 'Step: Secure Boot certificates'
        $st = Get-SbState
        $r = Start-SbDeployment -State $st -DbOnly:([bool]$opts.DbOnly)
        if ($r.RebootRequired) { $result.Restart = $true }
        if (-not $r.Ok) { $result.Failed = $true }
    }
    Write-SbLog ''
    if ($result.Failed) { Write-SbLog 'Finished, with warnings or errors (see above).' } else { Write-SbLog 'Finished.' }
} catch {
    Write-SbLog ('ERROR: ' + $_.Exception.Message)
    $result.Failed = $true
}
$sync.Result = $result
'@

function Test-Admin {
    try { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    catch { $false }
}

function ConvertTo-PsLiteral([string]$s) { $s -replace "'", "''" }

# ===== GUI =====
try {
    # --- Administrator: reopens elevated, without a console, and this copy ends ---
    if (-not (Test-Admin)) {
        $exe = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $exe)) { $exe = 'powershell' }
        $cmd = "`$env:SBGUI_SCRIPT = '{0}'; iex ([IO.File]::ReadAllText(`$env:SBGUI_SCRIPT, [Text.Encoding]::UTF8))" -f (ConvertTo-PsLiteral $env:SBGUI_SCRIPT)
        $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
        try {
            Start-Process -FilePath $exe -Verb RunAs -WindowStyle Hidden -ErrorAction Stop -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -EncodedCommand $enc"
            exit 0
        } catch {
            Write-Host (Get-Zh 'Administrator rights are needed. Open the file again and accept the prompt.') -ForegroundColor Yellow
            exit 1
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Hides the console behind the window (when already opened as administrator)
    try {
        Add-Type -Namespace SbGui -Name Con -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
        [void][SbGui.Con]::ShowWindow([SbGui.Con]::GetConsoleWindow(), 0)
    } catch { }

    # --- Log file ---
    $LogDir = Join-Path $env:ProgramData 'Update-SecureBootCert'
    $LogFile = $null
    try {
        if (-not (Test-Path $LogDir)) { [void](New-Item -ItemType Directory -Path $LogDir -Force) }
        $LogFile = Join-Path $LogDir ('GUI_{0:yyyyMMdd_HHmmss}.log' -f (Get-Date))
    } catch { $LogFile = $null }

    function Write-LogFile([string]$t) {
        if ($LogFile) { try { [IO.File]::AppendAllText($LogFile, $t + "`r`n", [Text.Encoding]::UTF8) } catch { } }
    }

    # --- Look ---
    function Rgb($a) { [System.Drawing.Color]::FromArgb($a[0], $a[1], $a[2]) }
    $cBg    = Rgb @(28, 30, 36);   $cBox = Rgb @(20, 22, 27)
    $cText  = Rgb @(235, 236, 240); $cMuted = Rgb @(140, 146, 160)
    $cGreen = Rgb @(72, 199, 116);  $cRed = Rgb @(239, 83, 80)
    $cYellow = Rgb @(250, 204, 21); $cOrange = Rgb @(249, 115, 22); $cBlue = Rgb @(59, 130, 246); $cGrey = Rgb @(75, 80, 94)
    $fText  = New-Object System.Drawing.Font('Segoe UI', 9)
    $fBold  = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $fTitle = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
    $fMono  = New-Object System.Drawing.Font('Consolas', 9)

    function Get-LevelColor([string]$Level) {
        switch ($Level) {
            'Ok'    { $cGreen }
            'Warn'  { $cYellow }
            'Error' { $cRed }
            'Muted' { $cMuted }
            default { $cText }
        }
    }

    $AnchorTL   = [System.Windows.Forms.AnchorStyles]'Top, Left'
    $AnchorTLR  = [System.Windows.Forms.AnchorStyles]'Top, Left, Right'
    $AnchorAll  = [System.Windows.Forms.AnchorStyles]'Top, Bottom, Left, Right'
    $AnchorBLR  = [System.Windows.Forms.AnchorStyles]'Bottom, Left, Right'

    function New-Ctl($type, $x, $y, $w, $h) {
        $c = New-Object ("System.Windows.Forms.$type")
        $c.Location = New-Object System.Drawing.Point($x, $y)
        $c.Size = New-Object System.Drawing.Size($w, $h)
        $c.Anchor = $AnchorTL
        $c
    }
    function New-Btn($text, $x, $y, $w, $h, $color) {
        $b = New-Ctl 'Button' $x $y $w $h
        $b.Text = $text; $b.FlatStyle = 'Flat'; $b.BackColor = $color; $b.ForeColor = [System.Drawing.Color]::White
        $b.Font = $fBold; $b.FlatAppearance.BorderSize = 0; $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        $b
    }
    function New-Label($text, $x, $y, $w, $h) {
        $l = New-Ctl 'Label' $x $y $w $h
        $l.Text = $text; $l.ForeColor = $cText; $l.AutoEllipsis = $true
        $l
    }
    function New-Check($text, $x, $y, $w, $checked) {
        $c = New-Ctl 'CheckBox' $x $y $w 22
        $c.Text = $text; $c.Checked = $checked; $c.ForeColor = $cText
        $c
    }
    function New-List($columns) {
        $lv = New-Object System.Windows.Forms.ListView
        $lv.Dock = 'Fill'; $lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.HideSelection = $true
        $lv.BackColor = $cBox; $lv.ForeColor = $cText; $lv.Font = $fText; $lv.HeaderStyle = 'Nonclickable'
        foreach ($col in $columns) { [void]$lv.Columns.Add($col[0], $col[1]) }
        $lv
    }

    # --- Window ---
    $form = New-Object System.Windows.Forms.Form
    $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $form.Text = (Get-Zh 'Secure Boot Certificate Updater') + ' v' + $SbVersion
    $screenH = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height
    $form.ClientSize = New-Object System.Drawing.Size(900, ([Math]::Max(600, [Math]::Min(740, $screenH - 60))))
    $form.MinimumSize = New-Object System.Drawing.Size(916, 620)
    $form.StartPosition = 'CenterScreen'; $form.FormBorderStyle = 'Sizable'; $form.MaximizeBox = $true
    $form.BackColor = $cBg; $form.ForeColor = $cText; $form.Font = $fText
    $tip = New-Object System.Windows.Forms.ToolTip

    $lblTitle = New-Label (Get-Zh 'Secure Boot Certificate Updater') 16 10 868 28
    $lblTitle.Font = $fTitle; $lblTitle.Anchor = $AnchorTLR
    $lblSummary = New-Label '' 16 40 868 40
    $lblSummary.Font = $fBold; $lblSummary.Anchor = $AnchorTLR; $lblSummary.AutoEllipsis = $false
    $lblHint = New-Label '' 16 82 868 18
    $lblHint.ForeColor = $cYellow; $lblHint.Anchor = $AnchorTLR
    foreach ($c in $lblTitle, $lblSummary, $lblHint) { $form.Controls.Add($c) }

    # --- State grid: 5 rows x 2 columns (filled from Get-SbStateRows) ---
    $capLabels = @(); $valLabels = @()
    for ($i = 0; $i -lt 10; $i++) {
        $col = [int][Math]::Floor($i / 5); $row = $i % 5
        $x = 16 + $col * 440; $y = 104 + $row * 21
        $cap = New-Label '' $x $y 164 20; $cap.ForeColor = $cMuted
        $val = New-Label '' ($x + 166) $y 262 20
        $form.Controls.Add($cap); $form.Controls.Add($val)
        $capLabels += $cap; $valLabels += $val
    }

    # --- Certificates and events ---
    $tabs = New-Ctl 'TabControl' 16 214 868 150
    $tabs.Anchor = $AnchorTLR
    $tabCerts = New-Object System.Windows.Forms.TabPage((Get-Zh 'Certificates in the firmware'))
    $tabEvents = New-Object System.Windows.Forms.TabPage((Get-Zh 'Recent Secure Boot events'))
    $lvCerts = New-List @(@((Get-Zh 'Store'), 56), @((Get-Zh 'Certificate'), 300), @((Get-Zh 'Expires'), 92), @((Get-Zh 'Status'), 96), @((Get-Zh 'Used for'), 290))
    $lvEvents = New-List @(@((Get-Zh 'Time'), 130), @((Get-Zh 'Event'), 60), @((Get-Zh 'Meaning'), 640))
    $tabCerts.Controls.Add($lvCerts); $tabEvents.Controls.Add($lvEvents)
    [void]$tabs.TabPages.Add($tabCerts); [void]$tabs.TabPages.Add($tabEvents)
    $form.Controls.Add($tabs)

    # --- What to do ---
    $lblWhat = New-Label (Get-Zh 'What to do:') 16 370 868 20
    $lblWhat.Font = $fBold
    $form.Controls.Add($lblWhat)
    $chkDeploy = New-Check (Get-Zh 'Install the 2023 Secure Boot certificates and boot manager (Microsoft''s full update)') 24 392 860 $true
    $chkDbOnly = New-Check (Get-Zh 'Old method: only add Windows UEFI CA 2023 to the DB (0x40), not the KEK or the boot manager') 48 414 836 $false
    $chkKb     = New-Check (Get-Zh ('Install ' + $SbKbId + ' first (only Windows 10 21H2/22H2 older than build .' + $SbKbUbr + ')')) 24 436 860 $false
    $chkWu     = New-Check (Get-Zh 'Install all pending Windows updates first (software only; can take a long time)') 24 458 860 $false
    $chkBl     = New-Check (Get-Zh 'Suspend BitLocker for the next 2 restarts (it turns back on by itself)') 24 480 860 $false
    foreach ($c in $chkDeploy, $chkDbOnly, $chkKb, $chkWu, $chkBl) { $form.Controls.Add($c) }

    $btnRefresh = New-Btn (Get-Zh 'Refresh') 16 508 120 38 $cGrey
    $btnStart   = New-Btn (Get-Zh 'Start update') 144 508 360 38 $cOrange
    $btnRestart = New-Btn (Get-Zh 'Restart now') 512 508 170 38 $cBlue
    $btnLogs    = New-Btn (Get-Zh 'Open log folder') 690 508 194 38 $cGrey
    $btnRestart.Enabled = $false
    foreach ($c in $btnRefresh, $btnStart, $btnRestart, $btnLogs) { $form.Controls.Add($c) }

    $txtLog = New-Ctl 'TextBox' 16 554 868 ($form.ClientSize.Height - 554 - 30)
    $txtLog.Multiline = $true; $txtLog.ReadOnly = $true; $txtLog.ScrollBars = 'Vertical'
    $txtLog.BackColor = $cBox; $txtLog.ForeColor = Rgb @(210, 210, 210); $txtLog.Font = $fMono
    $txtLog.Anchor = $AnchorAll
    $form.Controls.Add($txtLog)

    $lblFoot = New-Label (Get-Zh 'Restarts are needed. If BitLocker is on, have the recovery key ready (aka.ms/myrecoverykey) or suspend it. Use at your own risk.') 16 ($form.ClientSize.Height - 26) 868 22
    $lblFoot.ForeColor = $cMuted; $lblFoot.Anchor = $AnchorBLR
    $form.Controls.Add($lblFoot)

    # --- Helpers ---
    function Add-UiLog([string]$t) {
        $t = Get-Zh $t
        $txtLog.AppendText($t + "`r`n")
        Write-LogFile $t
    }
    # Engine functions log through this on the window's thread
    function Write-SbLog([string]$Text, [string]$Level = 'Info') { Add-UiLog $Text }

    function Set-Value($label, [string]$text, $color) { $label.Text = $text; $label.ForeColor = $color }

    $script:State = $null
    $script:NeedsRestart = $false
    $script:Busy = $false
    $script:Job = $null

    # Enables the options that make sense for the current state
    function Set-OptionState([bool]$resetDefaults) {
        $st = $script:State
        $btnRefresh.Enabled = $true; $btnStart.Enabled = $true; $btnLogs.Enabled = $true
        $btnRestart.Enabled = [bool]$script:NeedsRestart
        if (-not $st) { return }
        $canAct = ($st.Verdict -ne 'NoUefi')
        $kbOk = ($st.Os.IsWin10Client -and $st.Os.Ubr -lt $SbKbUbr)
        $chkDeploy.Enabled = $canAct
        $chkKb.Enabled = $kbOk
        $chkWu.Enabled = $true
        $chkBl.Enabled = [bool]$st.BitLocker.On
        if ($resetDefaults) {
            $needs = ($st.Verdict -in 'NotStarted', 'Partial', 'InProgress')
            $chkDeploy.Checked = ($canAct -and $needs)
            $chkKb.Checked = ($kbOk -and $st.Verdict -in 'NotStarted', 'Partial')
            $chkWu.Checked = $false
            $chkBl.Checked = $false
            $chkDbOnly.Checked = $false
        }
        if (-not $chkDeploy.Enabled) { $chkDeploy.Checked = $false }
        if (-not $chkKb.Enabled) { $chkKb.Checked = $false }
        if (-not $chkBl.Enabled) { $chkBl.Checked = $false }
        $chkDbOnly.Enabled = ($chkDeploy.Enabled -and $chkDeploy.Checked)
        if (-not $chkDbOnly.Enabled) { $chkDbOnly.Checked = $false }
        if ($st.Verdict -eq 'InProgress') { $btnStart.Text = (Get-Zh 'Continue update') } else { $btnStart.Text = (Get-Zh 'Start update') }
    }

    function Set-Busy([bool]$busy) {
        $script:Busy = $busy
        $form.UseWaitCursor = $busy
        if ($busy) {
            foreach ($c in $btnRefresh, $btnStart, $btnRestart, $chkDeploy, $chkDbOnly, $chkKb, $chkWu, $chkBl) { $c.Enabled = $false }
        } else {
            Set-OptionState $false
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    # Reads the state and fills the window
    function Update-View([bool]$resetDefaults = $true) {
        Set-Value $lblSummary (Get-Zh 'Reading the state...') $cMuted
        $lblHint.Text = ''
        [System.Windows.Forms.Application]::DoEvents()
        $st = Get-SbState
        $script:State = $st

        $rows = @(Get-SbStateRows $st)
        for ($i = 0; $i -lt $valLabels.Count; $i++) {
            if ($i -lt $rows.Count) {
                $capLabels[$i].Text = (Get-Zh $rows[$i].Caption)
                $rowVal = Get-Zh $rows[$i].Value
                Set-Value $valLabels[$i] $rowVal (Get-LevelColor $rows[$i].Level)
                $tip.SetToolTip($valLabels[$i], $rowVal)
            } else { $capLabels[$i].Text = ''; $valLabels[$i].Text = '' }
        }

        $lvCerts.BeginUpdate(); $lvCerts.Items.Clear()
        foreach ($c in $st.Certs) {
            $it = New-Object System.Windows.Forms.ListViewItem($c.Store)
            [void]$it.SubItems.Add($c.Name)
            [void]$it.SubItems.Add($c.NotAfter.ToString('yyyy-MM-dd'))
            [void]$it.SubItems.Add((Get-Zh $c.Status))
            [void]$it.SubItems.Add((Get-Zh $c.Use))
            if ($c.Year -eq 2023) { if ($c.Status -eq 'Valid') { $it.ForeColor = $cGreen } else { $it.ForeColor = $cRed } }
            elseif ($c.Year -eq 2011) { $it.ForeColor = $cYellow }
            else { $it.ForeColor = $cMuted }
            [void]$lvCerts.Items.Add($it)
        }
        if (@($st.Certs).Count -eq 0) {
            $it = New-Object System.Windows.Forms.ListViewItem('-')
            [void]$it.SubItems.Add((Get-Zh 'Could not read the certificates from the firmware (Secure Boot not available?)'))
            $it.ForeColor = $cMuted
            [void]$lvCerts.Items.Add($it)
        }
        $lvCerts.EndUpdate()

        $lvEvents.BeginUpdate(); $lvEvents.Items.Clear()
        foreach ($e in $st.Events) {
            $it = New-Object System.Windows.Forms.ListViewItem($e.Time.ToString('yyyy-MM-dd HH:mm'))
            [void]$it.SubItems.Add([string]$e.Id)
            [void]$it.SubItems.Add((Get-Zh $e.Meaning))
            if ($e.Id -in 1795, 1796, 1797, 1798, 1802, 1803, 1032) { $it.ForeColor = $cYellow }
            elseif ($e.Id -in 1808, 1799, 1036, 1043, 1044, 1045) { $it.ForeColor = $cGreen }
            [void]$lvEvents.Items.Add($it)
        }
        if (@($st.Events).Count -eq 0) {
            $it = New-Object System.Windows.Forms.ListViewItem('-')
            [void]$it.SubItems.Add('')
            [void]$it.SubItems.Add((Get-Zh 'No Secure Boot servicing events in the System log'))
            $it.ForeColor = $cMuted
            [void]$lvEvents.Items.Add($it)
        }
        $lvEvents.EndUpdate()

        $v = Get-SbVerdictText $st
        $vText = Get-Zh $v.Text
        Set-Value $lblSummary $vText (Get-LevelColor $v.Level)
        $hints = @(Get-SbHints $st | ForEach-Object { Get-Zh $_ })
        if ($hints.Count -gt 0) {
            $more = ''
            if ($hints.Count -gt 1) { $more = Get-Zh '  (more in the log below)' }
            $lblHint.Text = $hints[0] + $more
            $tip.SetToolTip($lblHint, ($hints -join "`r`n"))
        }

        if ($st.Verdict -eq 'RestartNeeded' -or $st.PendingReboot) { $script:NeedsRestart = $true }
        Set-OptionState $resetDefaults

        # Full report in the log file, hints also in the window
        Write-LogFile ''
        Write-LogFile ((Get-Zh '--- State at ') + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ---')
        foreach ($r in $rows) {
            if ($script:UiLang -eq 'zh-TW') { Write-LogFile ((Get-Zh $r.Caption) + ' = ' + (Get-Zh $r.Value)) }
            else { Write-LogFile ('{0,-26} {1}' -f (Get-Zh $r.Caption), (Get-Zh $r.Value)) }
        }
        foreach ($c in $st.Certs) { Write-LogFile ('[{0,-3}] {1,-38} {2:yyyy-MM-dd} {3}' -f $c.Store, $c.Name, $c.NotAfter, (Get-Zh $c.Status)) }
        foreach ($e in $st.Events) { Write-LogFile ('{0:yyyy-MM-dd HH:mm} {1} {2}' -f $e.Time, $e.Id, (Get-Zh $e.Meaning)) }
        Write-LogFile $vText
        $txtLog.AppendText((Get-Zh 'State: ') + $vText + "`r`n")
        foreach ($h in $hints) { Add-UiLog ('  - ' + $h) }
    }

    # --- Background work ---
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250

    function Start-SbWorker($opts) {
        $sync = [hashtable]::Synchronized(@{ Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'; Result = $null })
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        $rs.SessionStateProxy.SetVariable('sync', $sync)
        $rs.SessionStateProxy.SetVariable('opts', $opts)
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript($SbEngine + "`r`n" + $SbWorker)
        $script:Job = [pscustomobject]@{ PS = $ps; RS = $rs; Sync = $sync; Handle = $ps.BeginInvoke() }
        $timer.Start()
    }

    $timer.Add_Tick({
        try {
            $j = $script:Job
            if (-not $j) { $timer.Stop(); return }
            $line = $null
            while ($j.Sync.Queue.TryDequeue([ref]$line)) { Add-UiLog $line }
            if (-not $j.Handle.IsCompleted) { return }

            $timer.Stop()
            try { [void]$j.PS.EndInvoke($j.Handle) } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message) }
            foreach ($e in $j.PS.Streams.Error) { Add-UiLog ('ERROR: ' + $e.ToString()) }
            while ($j.Sync.Queue.TryDequeue([ref]$line)) { Add-UiLog $line }
            $res = $j.Sync.Result
            try { $j.PS.Dispose(); $j.RS.Close(); $j.RS.Dispose() } catch { }
            $script:Job = $null
            if ($res -and $res.Restart) { $script:NeedsRestart = $true }

            Set-Busy $true
            Update-View $true
            if ($script:NeedsRestart) {
                Add-UiLog 'Restart the PC (button above). Then open this tool again: it starts the next step and confirms the result.'
            }
        } catch {
            Add-UiLog ('ERROR: ' + $_.Exception.Message)
            $timer.Stop()
        } finally {
            if (-not $script:Job) { Set-Busy $false }
        }
    })

    function Start-Update {
        if ($script:Busy) { return }
        $o = @{ Deploy = $chkDeploy.Checked; DbOnly = $chkDbOnly.Checked; Kb = $chkKb.Checked; Wu = $chkWu.Checked; Bl = $chkBl.Checked }
        if (-not ($o.Deploy -or $o.Kb -or $o.Wu -or $o.Bl)) {
            [void][System.Windows.Forms.MessageBox]::Show((Get-Zh 'Tick at least one action.'), (Get-Zh 'Secure Boot'), 'OK', 'Information'); return
        }
        $zh = ($script:UiLang -eq 'zh-TW')
        $lines = @()
        if ($o.Kb) { if ($zh) { $lines += ('- 安裝 ' + $SbKbId) } else { $lines += ('- install ' + $SbKbId) } }
        if ($o.Wu) { if ($zh) { $lines += '- 安裝所有待處理的 Windows 更新' } else { $lines += '- install all pending Windows updates' } }
        if ($o.Bl) { if ($zh) { $lines += '- 暫停 BitLocker 兩次重新開機' } else { $lines += '- suspend BitLocker for 2 restarts' } }
        if ($o.Deploy) {
            if ($o.DbOnly) {
                if ($zh) { $lines += '- 把 Windows UEFI CA 2023 加入安全開機 DB（舊方法）' } else { $lines += '- add Windows UEFI CA 2023 to the Secure Boot DB (old method)' }
            } else {
                if ($zh) { $lines += '- 安裝 2023 安全開機憑證與開機管理程式' } else { $lines += '- install the 2023 Secure Boot certificates and boot manager' }
            }
        }
        $bl = ''
        if ($script:State -and $script:State.BitLocker.On -and -not $o.Bl) {
            if ($zh) { $bl = "`r`nBitLocker 已開啟且不會暫停：請備妥 48 位數復原金鑰（aka.ms/myrecoverykey）。`r`n" }
            else { $bl = "`r`nBitLocker is ON and will not be suspended: have the 48-digit recovery key ready (aka.ms/myrecoverykey).`r`n" }
        }
        if ($zh) { $q = "將執行：`r`n" + ($lines -join "`r`n") + "`r`n" + $bl + "`r`n執行期間請勿關機；之後需要重新開機。`r`n`r`n要繼續嗎？" }
        else { $q = "This will:`r`n" + ($lines -join "`r`n") + "`r`n" + $bl + "`r`nDo not turn the PC off while it runs. Restarts are needed afterwards.`r`n`r`nContinue?" }
        if ([System.Windows.Forms.MessageBox]::Show($q, (Get-Zh 'Secure Boot'), 'YesNo', 'Warning') -ne 'Yes') { Add-UiLog 'Cancelled. Nothing was changed.'; return }
        Set-Busy $true
        Start-SbWorker $o
    }

    $chkDeploy.Add_CheckedChanged({
        $chkDbOnly.Enabled = ($chkDeploy.Enabled -and $chkDeploy.Checked)
        if (-not $chkDbOnly.Enabled) { $chkDbOnly.Checked = $false }
    })
    $btnRefresh.Add_Click({
        try { Set-Busy $true; Update-View $false } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message) } finally { Set-Busy $false }
    })
    $btnStart.Add_Click({
        try { Start-Update } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message); if (-not $script:Job) { Set-Busy $false } }
    })
    $btnRestart.Add_Click({
        try {
            if ($script:UiLang -eq 'zh-TW') { $q = "電腦將在 30 秒後重新開機。`r`n`r`n請先儲存工作；可用 shutdown /a 取消。`r`n`r`n重新開機後，請再開一次本工具完成後續步驟。`r`n`r`n要立即重新開機嗎？" }
            else { $q = "The PC will restart in 30 seconds.`r`n`r`nSave your work first. You can cancel by running:  shutdown /a`r`n`r`nAfter the restart, open this tool again to finish.`r`n`r`nRestart now?" }
            if ([System.Windows.Forms.MessageBox]::Show($q, (Get-Zh 'Restart'), 'YesNo', 'Warning') -eq 'Yes') {
                Add-UiLog 'Restarting in 30 seconds (cancel with: shutdown /a)...'
                & shutdown.exe /r /t 30 /c (Get-Zh 'Secure Boot certificate update (Update-SecureBootCert)') | Out-Null
            }
        } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message) }
    })
    $btnLogs.Add_Click({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $LogDir + '"') } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message) }
    })
    $form.Add_FormClosing({
        param($src, $evtArgs)
        if ($script:Busy) {
            [void][System.Windows.Forms.MessageBox]::Show((Get-Zh 'The update is still running. Wait until it finishes, then close the window.'), (Get-Zh 'Secure Boot'), 'OK', 'Information')
            $evtArgs.Cancel = $true
        }
    })

    Add-UiLog ((Get-Zh 'Secure Boot Certificate Updater') + ' v' + $SbVersion)
    Add-UiLog (Get-Zh 'Nothing is changed until you click Start update and confirm.')
    if ($LogFile) { Add-UiLog ('Log file: ' + $LogFile) }

    $form.Add_Shown({
        try { $form.Activate(); Set-Busy $true; Update-View $true } catch { Add-UiLog ('ERROR: ' + $_.Exception.Message) } finally { Set-Busy $false }
    })
    [void]$form.ShowDialog()
    exit 0
} catch {
    $msg = (Get-Zh 'Unexpected error: ') + $_.Exception.Message + "`r`n" + (Get-Zh 'Line ') + $_.InvocationInfo.ScriptLineNumber
    try { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($msg, (Get-Zh 'Secure Boot Certificate Updater'), 'OK', 'Error') } catch { Write-Host $msg -ForegroundColor Red }
    exit 1
}
