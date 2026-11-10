# Changelog

All notable changes to this project are listed here, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use `major.minor` (and `.patch` for small fixes).

## [Unreleased]

### Added
- **Traditional Chinese (zh-TW) window.** When Windows is set to Traditional Chinese (`zh-TW`, `zh-HK` or `zh-MO`), the GUI uses Traditional Chinese for everything it shows: the window, the state rows, the summary and hints, the certificate and event lists, the message boxes and the log file. `SBGUI_LANG=en` forces English and `SBGUI_LANG=zh-TW` forces Traditional Chinese (handy for screenshots). The engine and its log messages are unchanged, so the `SB-ENGINE` block still matches the script.

### Changed
- The GUI file is now UTF-8 without a BOM; it is read as UTF-8 both at runtime (`iex ([IO.File]::ReadAllText(..., [Text.Encoding]::UTF8))`) and by the GitHub Action. Its batch header (the lines `cmd.exe` runs) and the script and `RunMe.bat` stay ASCII. The Action now checks exactly that instead of requiring the whole GUI to be ASCII.

## [2.0] - 2026-10-23

A rewrite of the script and the GUI. Both now share the same engine (the `SB-ENGINE` block, kept identical in both files and checked by a GitHub Action).

### Changed
- **Full update.** The certificate step now sets `AvailableUpdates = 0x5944`, Microsoft's value for the full update: Microsoft Corporation KEK 2K CA 2023, Windows UEFI CA 2023, Microsoft UEFI CA 2023, Microsoft Option ROM UEFI CA 2023 and the boot manager signed with Windows UEFI CA 2023. Until 1.2.1 only Windows UEFI CA 2023 was added to the DB (`0x40`); that method is still available (`-DbOnly`, or the "old method" option in the GUI).
- **No overwriting.** If Windows has already queued an update (for example `0x4100`), `AvailableUpdates` is left as is and only the Secure-Boot-Update task is started.
- **"Up to date" means what Windows reports.** The result comes from `UEFICA2023Status`, `WindowsUEFICA2023Capable`, the KEK and the DB, not only from Windows UEFI CA 2023 being in the DB.
- **Certificates are read properly.** KEK and DB are parsed as EFI signature lists; every certificate is shown with its real expiry date (2023 certificates: 2035 and 2038, not "~2033"). Certificates added by the PC maker are listed too.
- The task is followed until it finishes, and its result, the new `AvailableUpdates` value and Windows' status are shown.
- **KB5073724 step:** only on Windows 10 21H2/22H2 (builds 19044/19045) older than build .6809 (checked with the build number, so a newer cumulative update counts too). It finds the right Catalog entry for the Windows version and processor, downloads the `.msu` only from a Microsoft host, and installs it with `wusa.exe` (`.cab` with DISM). The download is deleted afterwards.
- **Windows Update step** is optional in the script too (`-InstallWindowsUpdates`, or a question; off by default). It installs software updates only, skips hidden updates and updates that need user input, and accepts license terms where needed.
- The script asks for administrator rights **before** any question, and passes its parameters on to the elevated copy.
- **GUI:** the work runs in the background, so the window no longer freezes. New status grid (Secure Boot, Windows, KEK, DB, boot manager, Windows status, `AvailableUpdates`, task, BitLocker, pending restart), tabs for certificates and events, a hint line, an "Open log folder" button. The window can be resized and scales with the display settings. It cannot be closed while an update runs.
- **RunMe.bat:** checks administrator rights with `fltmc` and passes its arguments on to the script. It shows what the exit code means and where the logs are.

### Fixed
- **Microsoft Corporation UEFI CA 2011 was never detected** (the name pattern was wrong: "Microsoft UEFI CA 2011").
- **Windows Production PCA 2011** was shown as "expires soon" after it expired on 2026-10-19. Statuses are now calculated from the dates.
- **Windows Update results were misread** in the script and the GUI: success was taken for "already restarted", "succeeded with errors" for "failed", and a needed restart was missed. Now `ResultCode` and `RebootRequired` are read correctly.
- Script: the restart flag set after installing KB5073724 was reset by the next step.
- **Windows Server 2016/2019/2022 was treated as Windows 10** (build below 22000) and offered KB5073724.
- Script: it said "2023 certificates are already installed" based on the Windows certificate store (`Cert:\LocalMachine\Root`), which has nothing to do with Secure Boot. Those checks are removed.
- Script: `√` characters showed as garbage in Windows PowerShell 5.1 (UTF-8 file without BOM). The script and `RunMe.bat` are plain ASCII now; the GUI is read as UTF-8 explicitly.
- RunMe.bat: endless UAC prompts when the Server service was disabled (`net session`), and paths containing `'` broke the elevation.
- Error codes are shown as `0x80070490` instead of negative numbers.

### Added
- Windows' own update status (`UEFICA2023Status`, `UEFICA2023Error`, `WindowsUEFICA2023Capable`), the meaning of `AvailableUpdates`, the Secure-Boot-Update task's last run, BitLocker, pending restart, and the recent Secure Boot events (System log, TPM-WMI) with an explanation for each.
- Advice for known problems: no PK-signed KEK (event 1803), firmware blocked (1802), firmware error (1795/1796), BitLocker (1032), missing task, Secure Boot off.
- Optional BitLocker suspension for 2 restarts (`-SuspendBitLocker`, a question, or a GUI option).
- Log files in `%ProgramData%\Update-SecureBootCert` (script transcript and GUI log).
- Parameters: `-CheckOnly`, `-Unattended`, `-InstallWindowsUpdates`, `-SkipKB`, `-DbOnly`, `-SuspendBitLocker`, `-Restart`, `-NoPause`, `-LogPath`.
- Exit codes: 0 up to date, 1 error, 2 update needed or not finished, 3 cancelled, 3010 restart needed.
- GitHub Action (`.github/workflows/check-scripts.yml`): parses both files, checks that the engine blocks are identical, checks that the script and `RunMe.bat` are ASCII and that the GUI's batch header is ASCII, and runs PSScriptAnalyzer.
- `.gitattributes` keeps CRLF line endings for all `.bat`, `.cmd` and `.ps1` files.

### Removed
- The PSWindowsUpdate module (it only downloaded KB5073724 and never installed it).
- The Windows certificate store checks.

### Docs
- README (English and Traditional Chinese) rewritten. Corrected: a PC without the 2023 certificates still starts and still gets normal updates (it loses boot-security updates); legacy BIOS does not block drivers; `AvailableUpdatesPolicy` must not be written by hand; the rescue import uses the `.der` files from microsoft/secureboot_objects. The download link now points to this repository. Added the exit codes, status values, events, troubleshooting and credits. Added GUI screenshots (`docs/screenshots`).

## [1.2.1] - 2026-10-23

### Fixed
- The GUI label "Windows UEFI CA 2023 in the Secure Boot DB" was cut off. The captions column is wider now.

### Changed
- Version number 1.2.1 in the GUI, `Update-SecureBootCert.ps1`, `RunMe.bat` and the README.

## [1.2] - 2026-10-23

### Added
- **`Update-SecureBootCert-GUI.cmd`**: a window for the steps of `Update-SecureBootCert.ps1`, in a single file that opens with a double-click (asks for administrator rights once).
  - Shows Secure Boot, the Windows version, whether Windows UEFI CA 2023 is in the Secure Boot DB, whether KB5073724 is installed and the value of `AvailableUpdates`.
  - Lists the certificates found in the firmware (KEK and DB) with their status: valid, expired or expiring.
  - Lets you choose the steps: install KB5073724 (Windows 10 only), install all pending Windows updates, and deploy Windows UEFI CA 2023 to the Secure Boot DB.
  - Nothing is changed until you click **Start update** and confirm. The confirmation reminds you to have your BitLocker recovery key.
  - **Restart now** button (30 seconds to cancel with `shutdown /a`); two restarts are needed.
  - Log of every step at the bottom of the window.
- `CHANGELOG.md`, a version badge and a Changelog section in the README.
- `.gitattributes` to keep CRLF line endings in the GUI file.

### Changed
- The version number (1.2) is now in the header of `Update-SecureBootCert.ps1`, `RunMe.bat` and the GUI.

### Notes
- The GUI does not install the PSWindowsUpdate module that the script uses to download KB5073724; it uses the Microsoft Update Catalog download and DISM, as the script does next.
- `Update-SecureBootCert.ps1` and `RunMe.bat` behave as in 1.1 (only comment lines changed).

## [1.1] - 2026-07-13

### Changed
- Adjusted the expired-certificate logic for the post-June 2026 deadline.

## [1.0] - 2026-01-26

### Added
- First version: `Update-SecureBootCert.ps1`, `RunMe.bat` and the READMEs (English and Traditional Chinese).

[2.0]: ../../releases/tag/v2.0
[1.2.1]: ../../releases/tag/v1.2.1
[1.2]: ../../releases/tag/v1.2
[1.1]: ../../releases/tag/v1.1
[1.0]: ../../releases/tag/v1.0
