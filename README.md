# Windows Secure Boot Certificate Auto-Updater

> [!WARNING]
> **Action Required: The June 2026 deadline is approaching! Download and run this tool immediately to update your Secure Boot certificate to the 2023 version.**
>
> If you don't know how to use Git, you can directly download the packaged zip file:
> 📦 **[Download Update-SecureBootCert.zip](https://github.com/anomixer/Update-SecureBootCert/releases/latest/download/Update-SecureBootCert.zip)**

[中文說明 (Traditional Chinese)](./README_TW.md)

> Automatically checks, downloads, and installs Windows Secure Boot certificate updates, ensuring your system continues to function correctly after the certificate expiration in June 2026.

## 📑 Table of Contents

- [Quick Start](#quick-start)
- [Why Update?](#why-update)
- [Supported Systems](#supported-systems)
- [Key Features](#key-features)
- [Installation](#installation)
- [KB Update Information](#kb-update-information)
- [LTSC Version Support](#ltsc-version-support)
- [Non-ESU User Guide](#non-esu-user-guide)
- [Technical Principles of Non-ESU Mode](#technical-principles-of-non-esu-mode)
- [Verifying the Update](#verifying-the-update)
- [Enterprise Deployment](#enterprise-deployment)
- [FAQ](#faq)
- [🚨 Emergency Rescue (Post-June 2026)](#-emergency-rescue-post-june-2026-)
- [BIOS Legacy Mode Users (Post-June 2026)](#bios-legacy-mode-users-post-june-2026)
- [References](#references)

---

## Quick Start

### Basic Usage

**One-Click Execution (Recommended)**
```
Double-click RunMe.bat
```
- ✅ Easiest method! Just double-click.
- ✅ Automatically requests administrator privileges.
- ✅ Automatically bypasses execution policies.

**Process Flow**:
1. Automatically requests administrator privileges.
2. Checks certificate status.
3. Downloads and installs updates.
4. Deploys new certificates to the Secure Boot DB.
5. Prompts for reboot (two reboots required).

### System Requirements

- ✅ Windows 10 (22H2/21H2/LTSC 2021)
- ✅ Windows 11 (All versions)
- ✅ Windows Server 2016/2019/2022/2025
- ⚠️ Administrator privileges required
- ⚠️ Internet connection required

---

## Why Update?

### Certificate Expiration Schedule

| Expiring Certificate | Expiration Date | New Certificate | Storage Location | Purpose |
|---|---|---|---|---|
| **Microsoft Corporation KEK CA 2011** | June 2026 | Microsoft Corporation KEK 2K CA 2023 | Stored in KEK | Signing updates for DB and DBX. |
| **Microsoft Windows Production PCA 2011** | October 2026 | Windows UEFI CA 2023 | Stored in DB | Signing the Windows bootloader. |
| **Microsoft UEFI CA 2011** | June 2026 | Microsoft UEFI CA 2023 | Stored in DB | Signing 3rd-party bootloaders and EFI apps. |
| **Microsoft UEFI CA 2011** | June 2026 | Microsoft Option ROM UEFI CA 2023 | Stored in DB | Signing 3rd-party Option ROMs. |

### Consequences of Not Updating

- ❌ **Computer may NEVER boot into Windows 10/11 again** (Secure Boot failure prevents startup).
- ❌ **System completely unable to install ANY security updates**.
- ❌ **All new software and drivers will be unusable**.
- ❌ **Computer exposed to EXTREME security risks** (cannot patch vulnerabilities).
- ⚠️ **Risk increases drastically after June 2026**.

---

## Supported Systems

### Windows 10

| Version | Support Status | KB5073724 | ESU Required | End of Support |
|------|---------|-----------|---------|---------|
| 22H2 | ✅ Fully Supported | ✅ | ✅ ESU (Extended to 2026-10) | **2025-10-14 (Expired)** |
| 21H2 | ✅ Fully Supported | ✅ | ❌ Not Supported | 2024-06-11 (Expired) |
| Enterprise LTSC 2021 | ✅ Fully Supported | ✅ | ✅ **Mandatory** | 2027-01-12 |
| IoT Enterprise LTSC 2021 | ✅ Fully Supported | ✅ | ✅ **Mandatory** | 2032-01-13 |

### Windows 11

| Version | Support Status | Auto Deployment |
|------|---------|---------|
| 25H2 | ✅ Fully Supported | ✅ From 2026-01 |
| 24H2 | ✅ Fully Supported | ✅ From 2026-01 |
| 23H2 | ✅ Fully Supported | ⚠️ Manual trigger required |
| 22H2 | ✅ Fully Supported | ⚠️ Manual trigger required |

---

## Key Features

### 1. 🔍 Intelligent Status Detection (Step 1)
- **Secure Boot Status Check**: Detects if Secure Boot is enabled.
- **BIOS Certificate Read**: Directly reads certificate info from BIOS/UEFI.
- **Expiration Warning**: Clearly marks certificate status with Red/Yellow/Green colors.
- **Old 2011 Certificate Check**: Identifies expiring certificates.

### 2. ⚡ Fully Automatic Updates (Step 2)
- **Non-ESU Auto-Support**: Automatically downloads updates via Microsoft Update Catalog.
- **Smart Skip**: Automatically skips download if the target certificate already exists.
- **Windows 10**: Automatically installs KB5073724.
- **Windows 11**: Uses monthly updates.

### 3. 🚀 Certificate Deployment (Step 3)
- **Auto Registry Configuration**: Sets `AvailableUpdates`.
- **New Certificate Deployment**: Writes Windows UEFI CA 2023 to Secure Boot DB.
- **Deployment Verification**: Confirms write success.
- **Reboot Management**: Prompts for the required two reboots.

### 4. Fully Automatic Download Function 🆕
- **Auto-Fetch**: Scrapes Microsoft Update Catalog page.
- **Auto-Parse**: Extracts update GUID and download links.
- **Auto-Download**: Downloads .cab files.
- **Auto-Install**: Uses DISM command.
- **Smart Architecture Detection**: (x64/x86/ARM64).
- **No Manual Operation Needed** - Completely automated!

### 5. User-Friendly Interface
- Colored output, clear and readable.
- Detailed status reports.
- Automatic administrator privilege elevation.
- Clear reboot prompts (twice).

---

## Installation

### Method 1: Automatic Installation (Recommended)

```powershell
# Run the script (automatically calls PowerShell)
Double-click RunMe.bat

# The script automatically handles:
# - Checking and installing KB5073724 (Windows 10)
# - Checking monthly updates (Windows 11)
# - Deploying UEFI CA 2023
# - Verifying certificates
```

### Fallback: Manual Installation (If Auto-Download Fails)

This tool has built-in automatic downloading from the Microsoft Update Catalog. However, if network issues cause failure, you can perform it manually:

1. Automatically opens [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724).
2. Select the version matching your system architecture.
3. Download the `.msu` file.
4. Double-click to install.
5. Return to the script to continue.

### Method 2: Enterprise Deployment

Using WSUS, Intune, or SCCM:

```powershell
# WSUS: Configure Product and Classification
Product: Windows 10, version 1903 and later
Classification: Security Updates

# Intune: Use Windows Update for Business
# SCCM: Create Software Update Deployment
```

---

## KB Update Information

### KB5073724 (Windows 10 Main Update)

- **Release Date**: January 13, 2026
- **Build Versions**: 
  - 19045.6809 (Windows 10 22H2)
  - 19044.6809 (Windows 10 21H2 / LTSC 2021)
- **Features**: Includes new Secure Boot certificates (2023 version).
- **Download**: [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)

**Applicable Versions**:
- Windows 10 Version 22H2 (All editions)
- Windows 10 Version 21H2 (All editions)
- Windows 10 Enterprise LTSC 2021 (Requires ESU)
- Windows 10 IoT Enterprise LTSC 2021 (Requires ESU)

**Special Notes**:
- Includes phased Secure Boot certificate deployment.
- Only devices showing sufficient success signals will receive the new certificate automatically.
- Removes old modem drivers (agrsm64.sys, agrsm.sys, smserl64.sys, smserial.sys).

### KB5036210 (UEFI CA 2023 Deployment)

- **Release Date**: February 13, 2024
- **Applicable Systems**: Windows 10/11 (All editions)
- **Function**: Deploys Windows UEFI CA 2023 certificate to Secure Boot DB.
- **Deployment Method**: 

```powershell
# 1. Set Registry
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdates" -Value 0x40

# 2. Start Scheduled Task
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"

# 3. Reboot Twice

# 4. Verify
[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
# Should return True
```

### Servicing Stack Update (SSU)

Depending on your situation, you may need:

- **KB5031539**: For offline images (2023-10-13)
- **KB5005260**: For WSUS/Standalone packages (2021-08-10)

---

## LTSC Version Support

### Support Confirmation

✅ **KB5073724 fully supports Windows 10 LTSC 21H2**, including:
- Windows 10 Enterprise LTSC 2021 (21H2) - Build 19044.6809
- Windows 10 IoT Enterprise LTSC 2021 (21H2) - Build 19044.6809

### Support Timeline

| Version | End of Support | Notes |
|------|-------------|------|
| Enterprise LTSC 2021 | 2027-01-12 | Requires ESU |
| IoT Enterprise LTSC 2021 | 2032-01-13 | Longer support |

### ESU Requirements

⚠️ **IMPORTANT**: LTSC version users **MUST join the ESU (Extended Security Updates) program** to receive KB5073724.

**ESU Registration**:
1. Via Microsoft 365 Admin Center
2. Via Volume Licensing Service Center (VLSC)
3. Contact a Microsoft Authorized Reseller

### LTSC Installation Steps

```powershell
# 1. Ensure ESU program enrollment
# 2. Run the update tool
Double-click RunMe.bat

# The tool automatically:
# - Detects LTSC version
# - Searches and downloads KB5073724
# - Installs updates
# - Deploys UEFI CA 2023
# - Prompts for two reboots
```

---

## Non-ESU User Guide

### Situation Overview

- ⚠️ KB5073724 is primarily for **ESU Users**.
- ⚠️ Non-ESU systems **cannot receive it via Windows Update**.
- ✅ Can be **downloaded from Microsoft Update Catalog** and installed automatically by this tool.
- ⚠️ **Note**: Without ESU, the KB installation might act as if "removed" (Rollback) upon reboot. This is normal.
- ✅ **Solution**: This tool's **Step 3 (Registry Method)** works independently of the KB, forcing the Secure Boot DB update.

### Using This Tool

When running the tool:

1. The tool attempts to automatically download and install KB5073724.
2. If you lack ESU, installation may appear successful but be removed after reboot.
3. **DO NOT WORRY!** Please run this tool **AGAIN** after reboot.
4. The tool will detect the KB is missing but proceed to execute **Step 3**.
5. **Step 3** forces the Secure Boot DB update via registry.

### Alternatives

If the standalone installer doesn't work:

1. **Upgrade to Windows 11**: Free and continuous updates.
2. **Get ESU (Extended Support)**: Extend Windows 10 support.
   - **Free Plan**: Windows 10 users can register for the Consumer ESU program by simply logging in with a Microsoft ID, granting **one year of free extended Windows updates** (until 2026/10/13). ([Official Page](https://www.microsoft.com/en-us/windows/extended-security-updates?r=1))
3. **Wait**: Microsoft *might* release a non-ESU version before certificate expiration (unless they're feeling generous!).
4. **Manual Certificate Deployment**: Download certificate files from [Microsoft GitHub](https://github.com/microsoft/secureboot_objects) and install manually.

### Manual Certificate Deployment (Advanced)

```powershell
# Method 1: Via PowerShell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdates" -Value 0x40
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
# Reboot twice

# Method 2: Via BIOS
# 1. Download .bin certificate file from GitHub
# 2. Reboot into BIOS/UEFI settings
# 3. Find Secure Boot settings
# 4. Import the new certificate file
```

---

## Technical Principles of Non-ESU Mode

**This program can install UEFI CA 2023 for you even WITHOUT an ESU subscription, solving all the aforementioned problems!**

You might ask: "Microsoft says three certificates are expiring (KEK, UEFI CA, PCA), why focus only on **UEFI CA 2023**?"

### 1. Trust Chain Mechanism

Secure Boot doesn't check if the driver itself is expired, but checks "**who signed it**".

*   **Current Situation**: Drivers are signed by Microsoft with old keys; your BIOS trusts old keys via `UEFI CA 2011`.
*   **After 2026**: New hardware drivers and software will be signed with **New Keys**, originating from **"Windows UEFI CA 2023"**.

**By adding "Windows UEFI CA 2023" to the BIOS Allowlist (DB):**
Any driver or system update tracing back to this new source will be considered safe and allowed to load.

### 2. Solving Three Major Issues

| Issue (Certificate Expiry) | Solution (Tool Step 3) | Result |
| :--- | :--- | :--- |
| **Microsoft Corporation KEK CA 2011**<br>(Database update failure) | **Force Key Rotation**<br>The registry command triggers BIOS to update the entire trust list. | ✅ Restores database update capability<br>✅ KEK and DB updated in sync |
| **Microsoft UEFI CA 2011**<br>(Cannot boot new 3rd-party OS/drivers) | **Deploy CA 2023**<br>Adds new root of trust to DB. | ✅ **Allows loading new drivers**<br>✅ Supports new Linux/Windows Bootloaders |
| **Microsoft Windows Production PCA 2011**<br>(Cannot install Windows updates) | **Deploy CA 2023**<br>Windows update packages use new signatures. | ✅ **Allows update installation**<br>✅ System kernel verification passes |

### 3. Validity of the Non-ESU Method

**Step 3 (Registry Method)** of this tool executes:
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdates = 0x40`

This is not a "hack", but invokes Microsoft's official **Keys Update mechanism**.
Even without installing KB5073724, as long as the system has this update mechanism built-in (most Windows 10/11 versions do), this command forces the BIOS to read and write new certificate data.

**Conclusion**: As long as the script finally shows a **Green OK (UEFI CA 2023 is in DB)**, your system is immune to the 2026 cliff, regardless of whether the KB installation was rolled back.

---

## Verifying the Update

### Check if KB5073724 is Installed

```powershell
Get-HotFix -Id "KB5073724"
```

### Check for 2023 Certificates

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "2023" }
```

### Check Secure Boot DB

```powershell
[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
# Should return True
```

### Check System Build

```powershell
# Windows 10 22H2 should be 19045.6809
# Windows 10 21H2 should be 19044.6809
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object CurrentBuildNumber, UBR
```

---

## Enterprise Deployment

### Pre-deployment Preparation

1. **Test Environment Verification**
   - Deploy in test environment first.
   - Verify compatibility of all critical applications.
   - Confirm hardware (especially modem) compatibility.

2. **Check OEM Firmware Updates**
   - Microsoft recommends installing OEM (Dell, HP, Lenovo) firmware updates first.
   - Firmware updates are foundational for correct Secure Boot updates.

### Deployment Strategies

#### Using WSUS

```powershell
# Configure Product and Classification
Product: Windows 10, version 1903 and later
Classification: Security Updates

# KB5073724 will sync automatically
```

#### Using Microsoft Intune

```powershell
# Create Windows Update for Business policy
# Configure Update Rings:
# - Test Ring (10% devices)
# - Production Ring (90% devices)
```

#### Using Group Policy

```powershell
# Force Deploy UEFI CA 2023
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdatesPolicy" -Value 0x5944
```

### Phased Deployment Recommendation

1. **Week 1**: Deploy to 10% pilot machines.
2. **Week 2**: Monitor and resolve issues.
3. **Weeks 3-4**: Expand to 50%.
4. **Weeks 5-6**: Complete remaining 50%.

### Monitoring and Reporting

```powershell
# Check deployment status
Get-HotFix -Id "KB5073724" -ComputerName (Get-ADComputer -Filter *).Name

# Check certificate status
Invoke-Command -ComputerName (Get-ADComputer -Filter *).Name -ScriptBlock {
    [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
}
```

---

## FAQ

### Q1: I don't see update KB5073724 on my system?

**A**: Please confirm:
1. Joined ESU program (Mandatory for LTSC, recommended for general Win10).
2. ESU license properly activated.
3. Windows Update service running normally.
4. If still missing, use the **Microsoft Update Catalog** option in this tool to download manually.

### Q2: How many reboots are needed?

**A**: **Two reboots** are required:
- First Reboot: Download and install Windows updates.
- Second Reboot: Complete Secure Boot DB update.

### Q3: What if my old modem stops working?

**A**: KB5073724 removes old modem drivers. If you still need them:
1. Contact hardware manufacturer for updated drivers.
2. Consider upgrading hardware.
3. If old hardware is mandatory, you might need to delay this update (not recommended).

### Q4: Are LTSC 2019 or earlier supported?

**A**: KB5073724 is primarily for LTSC 2021 (21H2). Earlier LTSC versions may have different update packages; please check Microsoft documentation.

### Q5: What happens if I don't install it?

**A**: If not installed:
- After June 2026, Secure Boot might fail.
- Cannot install new security updates.
- Cannot use newly signed software and drivers.
- System security compromised.

### Q6: Does it work in Virtual Machines?

**A**: Yes, but note:
- VM needs UEFI and Secure Boot enabled.
- Some virtualization platforms might not fully support Secure Boot DB updates.
- Recommend testing on physical machine before deploying to virtual environment.

### Q7: What if update fails?

**A**: If update fails:
1. Check Windows Update logs.
2. Ensure latest Servicing Stack Update (SSU) is installed.
3. Try manual download from Microsoft Update Catalog.
4. Contact Microsoft support.

---

## 🚨 Emergency Rescue (Post-June 2026) 🚨

**If you are seeing this after June 2026 and your computer is locked out of Windows by Secure Boot, DO NOT PANIC! Follow these steps to rescue your system.**

### Method A: Temporarily Disable Secure Boot (Recommended/Fastest)

This is the simplest method, requiring only BIOS setting changes.

1.  **Enter BIOS/UEFI Settings**: Press `Del`, `F2`, or `F10` (depends on manufacturer) continuously during boot.
2.  **Find Secure Boot Option**: Usually under `Security` or `Boot` tab.
3.  **Set Secure Boot to `Disabled`**.
4.  **Save and Restart** (`F10`): You should now be able to boot into Windows normally.
5.  **Run This Tool**:
    *   Run `RunMe.bat` (or `Update-SecureBootCert.ps1`) as administrator.
    *   Select `Y` to start update.
    *   Wait for the script to complete Step 3 (Deploy Certificates).
6.  **Re-enable Secure Boot**:
    *   Restart computer, enter BIOS again.
    *   Set Secure Boot back to **`Enabled`**.
    *   Save and Restart.
7.  **Congratulations!** Your computer now has the new certificates and can operate securely.

### Method B: Manually Import Certificate via BIOS (Advanced)

If you cannot access Windows or Method A fails, you can import certificates directly via BIOS.

**Preparation** (Requires another working computer):
1.  Prepare a **FAT32 formatted** USB drive.
2.  Download Microsoft official certificate file (`.bin` format):
    *   [Windows UEFI CA 2023 Certificate (GitHub)](https://github.com/microsoft/secureboot_objects)
    *   This link leads to Microsoft's official GitHub repo.
3.  Copy the `.bin` file to the root of the USB drive.

**Rescue Steps**:
1.  Plug USB into the faulty computer.
2.  Boot into BIOS Setup Menu.
3.  Go to Secure Boot settings page.
4.  Look for **Key Management** or **Custom Mode**.
5.  Select **"Enroll Key"** or **"Append to DB"**.
    *   Note: Select **DB (Authorized Signatures)**. **NEVER** touch PK or KEK unless you know exactly what you are doing.
6.  Select `No filesystem` or your USB device.
7.  Select the `.bin` file you just copied.
8.  Confirm import (Might show "Success").
9.  Save BIOS settings and restart.

---

## BIOS Legacy Mode Users (Post-June 2026)

If you currently boot using the old **Legacy BIOS (CSM)** mode instead of UEFI, please note:

### 1. Booting Unaffected, but Driver Risks Exist
*   Since Legacy mode doesn't use Secure Boot, you will **NOT** be locked out of boot (BIOS doesn't check DB).
*   **HOWEVER**, the Windows OS kernel still verifies driver signatures. If your Windows 10 lacks this update, future installation or loading of new hardware drivers signed with new certificates may fail (e.g., installing new NVIDIA drivers might be blocked).
*   **Recommendation**: Still execute this tool to ensure OS-level compatibility.

### 2. Risks Specific to Future Windows 11 Upgrade/Reinstall
*   Windows 11 mandates **UEFI + Secure Boot**.
*   If you decide to switch from Legacy to UEFI and reinstall Windows 11 after June 2026:
    *   Your old BIOS (with outdated DB) will **refuse to boot** the new Windows 11 installation media (as it's signed with new certificates).
*   **Solution**:
    *   Refer to **[Emergency Rescue Method A](#method-a-temporarily-disable-secure-boot-recommendedfastest)** above.
    *   Specifically: Turn off Secure Boot to install -> Enter Windows and run this tool -> Turn Secure Boot back on.

---

## References

### Microsoft Official Documentation

- [Windows Secure Boot Certificate Expiration and CA Update](https://support.microsoft.com/en-us/topic/windows-%E5%AE%89%E5%85%A8%E9%96%8B%E6%A9%9F%E6%86%91%E8%AD%89%E5%88%B0%E6%9C%9F%E5%92%8C-ca-%E6%9B%B4%E6%96%B0-7ff40d33-95dc-4c3c-8725-a9b95457578e)
- [KB5073724 Official Page](https://support.microsoft.com/en-us/topic/bd960b49-050e-432f-a9d5-2454cb377fed)
- [KB5036210 - UEFI CA 2023 Deployment](https://support.microsoft.com/en-us/topic/kb5036210-%E5%B0%87-windows-uefi-ca-2023-%E6%86%91%E8%AD%89%E9%83%A8%E7%BD%B2%E5%88%B0%E5%AE%89%E5%85%A8%E9%96%8B%E6%A9%9F%E5%85%81%E8%A8%B1%E7%9A%84%E7%B0%BD%E7%AB%A0%E8%B3%87%E6%96%99%E5%BA%AB-db-a68a3eae-292b-4224-9490-299e303b450b)
- [Windows 10 LTSC Lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-enterprise-ltsc-2021)
- [ESU Program Information](https://learn.microsoft.com/en-us/windows-server/get-started/extended-security-updates-deploy)

### Download Links

- [Microsoft Update Catalog KB5073724 Download](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)
- [Secure Boot Objects (GitHub)](https://github.com/microsoft/secureboot_objects)

### Related Articles

- [HKEPC Original Article](https://www.hkepc.com/24893/)
- [Windows Secure Boot Guide](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-secure-boot)

---

**Last Updated**: 2026-01-26  
**Version**: 1.0  
**Author**: anomixer
