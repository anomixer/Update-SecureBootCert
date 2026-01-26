# ============================================================
# Windows Security Boot Certificate Auto Update Tool
# ============================================================
# Function: Automatically update Windows 10/11 security certificates
#   - KEK CA 2011 -> KEK CA 2023
#   - UEFI CA 2011 -> UEFI CA 2023
#   - Windows Production PCA 2011 -> Windows Production PCA 2023
#
# Compatible Systems:
#   OK Windows 10 (All editions including LTSC)
#   OK Windows 10 Enterprise LTSC 2021 (21H2)
#   OK Windows 10 IoT Enterprise LTSC 2021 (21H2)
#   OK Windows 11 (All editions)
#   OK Windows Server 2016/2019/2022/2025
#
# Why Update:
#   These certificates expire June-October 2026
#   Expiry will cause:
#   - Your computer may NEVER boot into Windows 10/11 again
#   - System completely unable to install ANY security updates
#   - All new software and drivers will be unusable
#   - Computer exposed to EXTREME security risks
#
# Notes:
#   - Requires administrator rights
#   - Restart recommended after installation
#   - Takes 5-15 minutes
#   - Windows 10: Installs KB5073724
#   - Windows 11: Uses monthly updates + KB5036210
#
# ============================================================

# ===== Check Admin Rights =====
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ===== Auto Elevate Function =====
function Invoke-Elevate {
    param(
        [string]$ScriptPath
    )
    
    Write-Host ""
    Write-Host "WARNING: This script requires administrator rights" -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$ScriptPath`""
        Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait
        exit 0
    }
    catch {
        Write-Host "ERROR: Cannot elevate privileges: $_" -ForegroundColor Red
        Write-Host "Please run this script as administrator" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ===== Check if 2023 certificates are already installed =====
function Test-2023CertificatesInstalled {
    $foundCerts = @()
    
    try {
        Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Subject -match "2023") {
                $foundCerts += $_
            }
        }
    }
    catch {
        return $null
    }
    
    return $foundCerts
}

# ===== Check if old 2011 certificates exist =====
function Test-2011CertificatesInstalled {
    $certPatterns = @("KEK CA 2011", "UEFI CA 2011", "Windows Production PCA 2011")
    $foundCerts = @()
    
    try {
        Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($pattern in $certPatterns) {
                if ($_.Subject -match $pattern) {
                    $foundCerts += $_
                }
            }
        }
    }
    catch {
        return $null
    }
    
    return $foundCerts
}

# ===== Check if KB5073724 is installed (Windows 10) =====
function Test-KB5073724Installed {
    try {
        $hotfix = Get-HotFix -Id "KB5073724" -ErrorAction SilentlyContinue
        if ($hotfix) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# ===== Check if Windows UEFI CA 2023 is in Secure Boot DB =====
function Test-UEFICA2023InDB {
    try {
        $result = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
        return $result
    }
    catch {
        return $false
    }
}


# ===== Check Secure Boot Status =====
function Get-SecureBootStatus {
    try {
        $secureBootEnabled = Confirm-SecureBootUEFI
        return $secureBootEnabled
    }
    catch {
        return $null
    }
}

# ===== Get BIOS Secure Boot Certificates =====
# ===== Get BIOS Secure Boot Certificates =====
function Get-SecureBootCertificates {
    $certInfo = @()
    try {
        # Check KEK
        $kek = Get-SecureBootUEFI -Name KEK -ErrorAction SilentlyContinue
        if ($kek) {
            $kekString = [System.Text.Encoding]::ASCII.GetString($kek.bytes)
            if ($kekString -match 'Microsoft Corporation KEK 2K CA 2023') {
                $certInfo += [PSCustomObject]@{ Type = "KEK"; Certificate = "Microsoft KEK CA 2023"; Status = "√ Valid"; Expiry = "~2033"; Color = "Green" }
            }
            if ($kekString -match 'Microsoft Corporation KEK CA 2011') {
                $certInfo += [PSCustomObject]@{ Type = "KEK"; Certificate = "Microsoft KEK CA 2011"; Status = "√ Expires Soon"; Expiry = "2026-06"; Color = "Yellow" }
            }
        }

        # Check DB
        $db = Get-SecureBootUEFI -Name db -ErrorAction SilentlyContinue
        if ($db) {
            $dbString = [System.Text.Encoding]::ASCII.GetString($db.bytes)
            if ($dbString -match 'Windows UEFI CA 2023') {
                $certInfo += [PSCustomObject]@{ Type = "DB "; Certificate = "Windows UEFI CA 2023"; Status = "√ Valid"; Expiry = "~2033"; Color = "Green" }
            }
            if ($dbString -match 'Microsoft UEFI CA 2011') {
                $certInfo += [PSCustomObject]@{ Type = "DB "; Certificate = "Microsoft UEFI CA 2011"; Status = "√ Expires Soon"; Expiry = "2026-06"; Color = "Yellow" }
            }
            if ($dbString -match 'Windows Production PCA 2011') {
                $certInfo += [PSCustomObject]@{ Type = "DB "; Certificate = "Windows Production PCA 2011"; Status = "√ Expires Soon"; Expiry = "2026-10"; Color = "Yellow" }
            }
        }
    }
    catch { }
    return $certInfo
}# ===== Deploy Windows UEFI CA 2023 to Secure Boot DB =====
function Install-UEFICA2023 {
    Write-Host ""
    Write-Host "Step 3/3: Deploying Windows UEFI CA 2023 to Secure Boot DB..." -ForegroundColor Cyan
    
    try {
        # Step 1: Set registry key
        Write-Host "Setting registry key..." -ForegroundColor Cyan
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdates" -Value 0x40 -ErrorAction Stop
        Write-Host "OK: Registry key set" -ForegroundColor Green
        
        # Step 2: Start scheduled task
        Write-Host "Starting Secure Boot update task..." -ForegroundColor Cyan
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update" -ErrorAction Stop
        Write-Host "OK: Task started" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "IMPORTANT: System needs TWO reboots for changes to take effect" -ForegroundColor Yellow
        
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to deploy UEFI CA 2023: $_" -ForegroundColor Red
        return $false
    }
}

# ===== Show Program Info =====
function Show-ProgramInfo {
    # Resize console window for better visibility
    try {
        $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(100, 40)
        $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(100, 3000)
    }
    catch {
        # Ignore resize errors (may not work in all environments)
    }
    
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  SecureBootCertFix - Windows Secure Boot Certificate Updater" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "WARNING: Certificates expire June-October 2026!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If NOT updated:" -ForegroundColor Red
    Write-Host "  X Your computer may NEVER boot into Windows again!" -ForegroundColor Red
    Write-Host "  X Cannot install security updates" -ForegroundColor Red
    Write-Host "  X Cannot use new software/drivers" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "This tool will:" -ForegroundColor Green
    Write-Host "  1. Check current certificate status" -ForegroundColor White
    Write-Host "  2. Download and install KB5073724 (Windows 10)" -ForegroundColor White
    Write-Host "  3. Deploy new 2023 certificates" -ForegroundColor White
    Write-Host "  4. Verify installation" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - Administrator rights (will auto-request)" -ForegroundColor White
    Write-Host "  - TWO reboots required" -ForegroundColor White
    Write-Host "  - 5-15 minutes" -ForegroundColor White
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        $start = Read-Host "Start update process? (Y/N)"
    } until ($start -eq "Y" -or $start -eq "y" -or $start -eq "N" -or $start -eq "n")
    
    if ($start -eq "N" -or $start -eq "n") {
        exit 1
    }
}

# ===== Main Program Start =====

# Get script path
$scriptPath = $MyInvocation.MyCommand.Definition
if (-not $scriptPath) {
    $scriptPath = $PSCommandPath
}
if (-not $scriptPath) {
    $scriptPath = $MyInvocation.InvocationName
}

Show-ProgramInfo

# Check and elevate if needed
if (-not (Test-AdminRights)) {
    Invoke-Elevate -ScriptPath $scriptPath
    exit 0
}

Write-Host "OK: Administrator rights confirmed" -ForegroundColor Green
Write-Host ""


# ===== Check Secure Boot Status =====
Write-Host ""
Write-Host "Step 1/3: Checking Secure Boot Status..." -ForegroundColor Cyan
$secureBootStatus = Get-SecureBootStatus

if ($secureBootStatus -eq $true) {
    Write-Host "OK: Secure Boot is ENABLED" -ForegroundColor Green
    
    # Show current BIOS certificates
    Write-Host ""
    Write-Host "Current Secure Boot Certificates (BIOS):" -ForegroundColor Cyan
    $biosCerts = Get-SecureBootCertificates
    
    if ($biosCerts -and $biosCerts.Count -gt 0) {
        foreach ($cert in $biosCerts) {
            Write-Host "  [$($cert.Type)] $($cert.Certificate)" -ForegroundColor White
            Write-Host "      $($cert.Status) (Expiry: $($cert.Expiry))" -ForegroundColor $cert.Color
        }
    }
    else {
        Write-Host "  INFO: Could not read BIOS certificate details" -ForegroundColor Yellow
    }
}
elseif ($secureBootStatus -eq $false) {
    Write-Host "WARNING: Secure Boot is DISABLED" -ForegroundColor Yellow
    Write-Host "  Updates will install but won't take effect until Secure Boot is enabled" -ForegroundColor Yellow
}
else {
    Write-Host "INFO: Secure Boot status unknown (may not be supported)" -ForegroundColor Cyan
}

Write-Host ""

# ===== Check Current Status =====
Write-Host "Checking Windows certificate status..." -ForegroundColor Cyan


# Check for 2023 certificates
$installed2023Certs = Test-2023CertificatesInstalled
$installed2011Certs = Test-2011CertificatesInstalled

if ($installed2023Certs -and $installed2023Certs.Count -gt 0) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "GOOD NEWS: 2023 certificates are already installed!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Installed 2023 certificates:" -ForegroundColor Green
    $installed2023Certs | ForEach-Object {
        $daysUntilExpiry = ($_.NotAfter - (Get-Date)).Days
        Write-Host "  * $($_.Subject)" -ForegroundColor Green
        Write-Host "    Expires: $($_.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
        Write-Host "    Days remaining: $daysUntilExpiry" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Check if UEFI CA 2023 is in Secure Boot DB
Write-Host "Checking Secure Boot DB for Windows UEFI CA 2023..." -ForegroundColor Cyan
$uefiCA2023InDB = Test-UEFICA2023InDB

if ($uefiCA2023InDB) {
    Write-Host "OK: Windows UEFI CA 2023 is in Secure Boot DB" -ForegroundColor Green
}
else {
    Write-Host "INFO: Windows UEFI CA 2023 not found in Secure Boot DB" -ForegroundColor Yellow
}

# Show old certificates if they exist
if ($installed2011Certs -and $installed2011Certs.Count -gt 0) {
    Write-Host ""
    Write-Host "Old 2011 certificates (will expire in 2026):" -ForegroundColor Yellow
    $installed2011Certs | ForEach-Object {
        $daysUntilExpiry = ($_.NotAfter - (Get-Date)).Days
        Write-Host "  * $($_.Subject)" -ForegroundColor Yellow
        Write-Host "    Expires: $($_.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Red
        Write-Host "    Days remaining: $daysUntilExpiry" -ForegroundColor Cyan
        Write-Host ""
    }
}

# If everything is already updated, exit
# If UEFI CA 2023 is in DB, we consider it a success regardless of local cert store
if ($uefiCA2023InDB) {
    Write-Host ""
    Write-Host "NOTE: System is already fully updated (UEFI CA 2023 in DB)." -ForegroundColor Green
    Write-Host "      Continuing execution to verify all steps..." -ForegroundColor Green
    Write-Host ""
    # We continue execution instead of exiting, to show the steps marking them as completed
}

# ===== Check Windows Version =====
Write-Host ""
Write-Host "Checking Windows version..." -ForegroundColor Cyan

# Get Windows version info
$osInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$buildNumber = [int]$osInfo.CurrentBuildNumber
$productName = $osInfo.ProductName
if ($buildNumber -lt 22000) {
    $isWin10 = $true
}
else {
    $isWin10 = $false
    # Fix: Windows 11 registry often still says "Windows 10"
    $productName = $productName -replace "Windows 10", "Windows 11"
}

Write-Host "OK: Detected $productName (Build: $buildNumber)" -ForegroundColor Yellow

# ===== Check if KB5073724 already installed (Windows 10) =====
if ($isWin10) {
    Write-Host ""
    Write-Host "Checking KB5073724 status..." -ForegroundColor Cyan
    
    if (Test-KB5073724Installed) {
        Write-Host "OK: KB5073724 is already installed" -ForegroundColor Green
    }
    else {
        Write-Host "INFO: KB5073724 NOT installed" -ForegroundColor Yellow
        Write-Host "      (If you lack an ESU license, the update may have been rolled back. This is normal.)" -ForegroundColor Gray
        if ($uefiCA2023InDB) {
            Write-Host "NOTE: Skipping installation because UEFI CA 2023 is already in DB" -ForegroundColor Green
        }
    }
}

do {
    $confirm = Read-Host "`nContinue with certificate update? (Y/N)"
} until ($confirm -eq "Y" -or $confirm -eq "y" -or $confirm -eq "N" -or $confirm -eq "n")

if ($confirm -eq "N" -or $confirm -eq "n") {
    Write-Host ""
    Write-Host "CANCELLED" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Step 2/3: Installing Security Updates (KB5073724)..." -ForegroundColor Cyan
if ($uefiCA2023InDB) {
    Write-Host "OK: Skipped (Already updated)" -ForegroundColor Green
}
Write-Host ""

# ===== Setup Parameters =====
$downloadDir = "$env:TEMP\WindowsUpdates"

if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    Write-Host "OK: Created download directory: $downloadDir" -ForegroundColor Green
}

# ===== Download KB5073724 for Windows 10 =====
# ===== Download KB5073724 for Windows 10 =====
if ($isWin10 -and -not $uefiCA2023InDB -and -not (Test-KB5073724Installed)) {
    Write-Host ""
    Write-Host "NOTE: Windows 10 detected - will install KB5073724" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Cyan
    
    try {
        $moduleExists = Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue
        
        if (-not $moduleExists) {
            Write-Host "Downloading PSWindowsUpdate module... (Answer Y if asking NuGet installation)" -ForegroundColor Cyan
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "OK: Module installed" -ForegroundColor Green
        }
        else {
            Write-Host "OK: PSWindowsUpdate module already exists" -ForegroundColor Green
        }
        
        Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
        
        Write-Host ""
        Write-Host "Downloading KB5073724..." -ForegroundColor Cyan
        $updates = Get-WindowsUpdate -KB "KB5073724" -AcceptAll -Download -ErrorAction SilentlyContinue
        
        if ($updates) {
            Write-Host "OK: KB5073724 downloaded successfully" -ForegroundColor Green
            Write-Host "Updates:" -ForegroundColor Cyan
            $updates | ForEach-Object {
                Write-Host "  * $($_.Title)" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "INFO: KB5073724 not found or already installed" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "WARNING: PSWindowsUpdate method failed, trying standard method..." -ForegroundColor Yellow
    }
    
    # ===== Microsoft Update Catalog Auto-Download =====
    Write-Host ""
    Write-Host "Attempting automatic download from Microsoft Update Catalog..." -ForegroundColor Cyan
    
    try {
        # Detect architecture
        $arch = $env:PROCESSOR_ARCHITECTURE
        $archName = ""
        
        if ($arch -eq "AMD64") {
            $archName = "x64"
            Write-Host "Detected system: x64 (64-bit)" -ForegroundColor Cyan
        }
        elseif ($arch -eq "x86") {
            $archName = "x86"
            Write-Host "Detected system: x86 (32-bit)" -ForegroundColor Cyan
        }
        elseif ($arch -eq "ARM64") {
            $archName = "arm64"
            Write-Host "Detected system: ARM64" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "Fetching update information..." -ForegroundColor Cyan
        
        # Fetch the catalog page
        $catalogUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724"
        $response = Invoke-WebRequest -Uri $catalogUrl -UseBasicParsing -ErrorAction Stop
        
        # Parse to find update GUID
        $updatePattern = "updateIDs\.push\(\{\'size\'\:\'.*?\'\'languages\'\:\'.*?\'\'uidInfo\'\:\'(.*?)\'\'updateID\'\:\'(.*?)\'\}\)"
        $regexMatches = [regex]::Matches($response.Content, $updatePattern)
        
        $targetUpdate = $null
        foreach ($match in $regexMatches) {
            $updateInfo = $match.Groups[1].Value
            $updateId = $match.Groups[2].Value
            
            if ($updateInfo -match $archName) {
                $targetUpdate = @{
                    UpdateId = $updateId
                    Info     = $updateInfo
                }
                break
            }
        }
        
        if ($targetUpdate) {
            Write-Host "OK: Found update for $archName" -ForegroundColor Green
            Write-Host ""
            Write-Host "Retrieving download link..." -ForegroundColor Cyan
            
            # Get download link
            $downloadUrl = "https://www.catalog.update.microsoft.com/DownloadDialog.aspx"
            $postData = "updateIDs=[$($targetUpdate.UpdateId)]"
            $downloadPage = Invoke-WebRequest -Uri $downloadUrl -Method Post -Body $postData -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -ErrorAction Stop
            
            # Extract .cab URL
            if ($downloadPage.Content -match "http[s]?://[^'`"<>]+\.cab") {
                $cabUrl = $matches[0]
                $fileName = Split-Path $cabUrl -Leaf
                $downloadPath = Join-Path $downloadDir $fileName
                
                Write-Host "OK: Found download link" -ForegroundColor Green
                Write-Host "File: $fileName" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Downloading..." -ForegroundColor Cyan
                
                # Download with progress
                Invoke-WebRequest -Uri $cabUrl -OutFile $downloadPath -UseBasicParsing
                
                Write-Host "OK: Download completed" -ForegroundColor Green
                Write-Host "Saved to: $downloadPath" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Installing via DISM..." -ForegroundColor Cyan
                
                # Install using DISM
                DISM /Online /Add-Package /PackagePath:"$downloadPath" /NoRestart
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "OK: KB5073724 installed successfully!" -ForegroundColor Green
                    Write-Host "NOTE: If you lack an ESU license, this update might be removed after reboot." -ForegroundColor Yellow
                    Write-Host "      However, the Secure Boot DB update (Step 3) will be scheduled independently." -ForegroundColor Yellow
                    $needsRestart = $true
                }
                else {
                    Write-Host "WARNING: DISM exit code $LASTEXITCODE" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "ERROR: Could not extract download URL" -ForegroundColor Red
            }
        }
        else {
            Write-Host "WARNING: Could not find update for $archName" -ForegroundColor Yellow
            Write-Host "This is expected if the update is not yet public or has been superseded." -ForegroundColor Gray
            Write-Host "Proceeding to Step 3 (Registry Method)..." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "WARNING: Automatic download failed: $_" -ForegroundColor Yellow
        Write-Host "Proceeding to Step 3 (Registry Method)..." -ForegroundColor Green
    }

}

# ===== Standard Windows Update Method =====
if (-not $uefiCA2023InDB) {
    Write-Host ""
    Write-Host "Checking Windows Update..." -ForegroundColor Cyan
    
    $needsRestart = $false
    
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
    
        Write-Host "Searching for available updates..." -ForegroundColor Cyan
        $searchResult = $updateSearcher.Search("IsInstalled=0")
    
        $updateCount = $searchResult.Updates.Count
        Write-Host "OK: Found $updateCount available updates" -ForegroundColor Green
    
        if ($updateCount -gt 0) {
            Write-Host ""
            Write-Host "Available updates:" -ForegroundColor Cyan
            $searchResult.Updates | ForEach-Object {
                Write-Host "  * $($_.Title)" -ForegroundColor Cyan
            }
        
            Write-Host ""
            Write-Host "Downloading updates (please wait)..." -ForegroundColor Cyan
            $updateDownloader = $updateSession.CreateUpdateDownloader()
            $updateDownloader.Updates = $searchResult.Updates
            $downloadResult = $updateDownloader.Download()
        
            if ($downloadResult.ResultCode -eq 2) {
                Write-Host "OK: Download successful" -ForegroundColor Green
            }
            else {
                Write-Host "WARNING: Download result code: $($downloadResult.ResultCode)" -ForegroundColor Yellow
            }
        
            Write-Host ""
            Write-Host "Installing updates (please wait)..." -ForegroundColor Cyan
            $updateInstaller = $updateSession.CreateUpdateInstaller()
            $updateInstaller.Updates = $searchResult.Updates
            $installResult = $updateInstaller.Install()
        
            switch ($installResult.ResultCode) {
                0 { 
                    Write-Host "INFO: No restart required" -ForegroundColor Cyan
                    $needsRestart = $false
                }
                1 { 
                    Write-Host "OK: Installation successful, restart required" -ForegroundColor Green
                    $needsRestart = $true
                }
                2 { 
                    Write-Host "OK: Installation successful, already restarted" -ForegroundColor Green
                    $needsRestart = $false
                }
                3 { 
                    Write-Host "ERROR: Installation failed" -ForegroundColor Red
                    $needsRestart = $false
                }
                default { 
                    Write-Host "WARNING: Unknown result code: $($installResult.ResultCode)" -ForegroundColor Yellow
                    $needsRestart = $false
                }
            }
        }
        else {
            Write-Host "INFO: System is already up to date" -ForegroundColor Cyan
            $needsRestart = $false
        }
    }
    catch {
        Write-Host "WARNING: Windows Update method failed: $_" -ForegroundColor Yellow
        $needsRestart = $false
    }
}

# ===== Deploy Windows UEFI CA 2023 to Secure Boot DB =====
Write-Host ""
Write-Host "Step 3/3: Deploying Windows UEFI CA 2023 (Registry Method)..." -ForegroundColor Cyan
Write-Host "      This step forces the DB update even if the KB was not fully persistant." -ForegroundColor Gray

if (-not $uefiCA2023InDB) {
    $deployResult = Install-UEFICA2023
    if ($deployResult) {
        $needsRestart = $true
    }
}
else {
    Write-Host "OK: Skipped (Already in DB)" -ForegroundColor Green
}

# ===== Verify Certificate Status =====
Write-Host ""
Write-Host "Verifying security boot certificates..." -ForegroundColor Cyan

try {
    $foundCerts = @()
    
    Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Subject -match "2023") {
            $foundCerts += $_
        }
    }
    
    if ($foundCerts.Count -gt 0) {
        Write-Host "OK: Found $($foundCerts.Count) new 2023 security boot certificates:" -ForegroundColor Green
        $foundCerts | ForEach-Object {
            $daysUntilExpiry = ($_.NotAfter - (Get-Date)).Days
            Write-Host "  * $($_.Subject)" -ForegroundColor Green
            Write-Host "    Expires: $($_.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
            Write-Host "    Days remaining: $daysUntilExpiry" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    else {
        Write-Host "WARNING: No 2023 certificates found yet" -ForegroundColor Yellow
        Write-Host "They may appear after system restart" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Cannot read certificates: $_" -ForegroundColor Red
}

# ===== Summary =====
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Certificate update check completed!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan

# ===== Ask for Restart (only if needed) =====
if ($needsRestart) {
    Write-Host ""
    Write-Host "IMPORTANT: TWO reboots are required for Secure Boot DB update" -ForegroundColor Yellow
    Write-Host ""
    do {
        $restart = Read-Host "Restart system now to complete update? (Y/N)"
    } until ($restart -eq "Y" -or $restart -eq "y" -or $restart -eq "N" -or $restart -eq "n")
    
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host ""
        Write-Host "System will restart in 10 seconds..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to cancel, otherwise will auto-restart" -ForegroundColor Yellow
        
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Host "OK: Restart cancelled" -ForegroundColor Green
        Write-Host "Please manually restart system TWICE to complete update" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    if ($uefiCA2023InDB) {
        Write-Host "Congratulations! Your Windows Secure Boot CA 2023 is successfully installed." -ForegroundColor Green
        Write-Host "Your new system certificate is valid until 2033." -ForegroundColor Green
    }
    else {
        Write-Host "No restart needed at this time." -ForegroundColor Green
    }
}

Write-Host ""
Read-Host "Press Enter to exit"
