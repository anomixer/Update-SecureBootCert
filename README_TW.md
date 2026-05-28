# Windows 安全啟動憑證自動更新工具

> [!WARNING]
> **【緊急通知】憑證即將於 6 月到期！請立即下載並執行此工具，將您的 Secure Boot 憑證更新至 2023 版本以防系統無法開機。**
> **Action Required: The June 2026 deadline is approaching! Download and run this tool immediately to update your Secure Boot certificate to the 2023 version.**
>
> 如果您不會使用 Git，可以直接下載已打包的 ZIP 檔案：
> 📦 **[下載 Update-SecureBootCert.zip](https://github.com/anomixer/Update-SecureBootCert/releases/latest/download/Update-SecureBootCert.zip)**

[English Readme](./README.md)

> 自動檢查、下載並安裝 Windows 安全啟動憑證更新，確保系統在 2026 年 6 月憑證到期後仍能正常運作。

## 📑 目錄

- [快速開始](#快速開始)
- [為什麼需要更新](#為什麼需要更新)
- [支援的系統](#支援的系統)
- [主要功能](#主要功能)
- [安裝方式](#安裝方式)
- [KB 更新資訊](#kb-更新資訊)
- [LTSC 版本支援](#ltsc-版本支援)
- [非 ESU 用戶指引](#非-esu-用戶指引)
- [非 ESU 模式之技術原理：為什麼有效](#非-esu-模式之技術原理為什麼有效)
- [驗證更新](#驗證更新)
- [企業部署](#企業部署)
- [常見問題](#常見問題)
- [🚨 緊急救援 (2026/6 以後)](#-緊急救援如果已經無法開機-20266-以後-)
- [BIOS Legacy Mode 用戶注意事項 (2026/6 以後)](#bios-legacy-mode-用戶注意事項-20266-以後)
- [參考資料](#參考資料)

---

## 快速開始

### 基本使用

**一鍵執行（推薦）**
```
雙擊執行 RunMe.bat
```
- ✅ 最簡單！雙擊即可
- ✅ 自動請求管理員權限
- ✅ 自動繞過執行原則

**執行流程**：
1. 自動請求管理員權限
2. 檢查憑證狀態
3. 下載並安裝更新
4. 部署新憑證到 Secure Boot DB
5. 提示重新啟動（需要兩次）

### 系統要求

- ✅ Windows 10 (22H2/21H2/LTSC 2021)
- ✅ Windows 11 (所有版本)
- ✅ Windows Server 2016/2019/2022/2025
- ⚠️ 需要管理員權限
- ⚠️ 需要網路連線

---

## 為什麼需要更新

### 憑證到期時間表

| 即將到期的憑證 | 到期日期 | 新證書 | 儲存地點 | 目的 |
|---|---|---|---|---|
| **Microsoft Corporation KEK CA 2011** | 2026年6月 | Microsoft Corporation KEK 2K CA 2023 | 儲存在 KEK 中 | 簽署資料庫和 DBX 的更新。 |
| **Microsoft Windows 生產 PCA 2011** | 2026年10月 | Windows UEFI CA 2023 | 儲存在資料庫中 | 用於簽署 Windows 開機載入器。 |
| **Microsoft UEFI CA 2011*** | 2026年6月 | Microsoft UEFI CA 2023 | 儲存在資料庫中 | 簽署協力廠商開機載入程式和 EFI 應用程式。 |
| **Microsoft UEFI CA 2011*** | 2026年6月 | Microsoft 選項 ROM UEFI CA 2023 | 儲存在資料庫中 | 簽署第三方選項 ROM |

### 不更新的後果

- ❌ **電腦可能再也進不去 Windows 10/11**（Secure Boot 失效後無法啟動）
- ❌ **系統完全無法安裝任何安全更新**
- ❌ **所有新的軟體和驅動程式都無法使用**
- ❌ **電腦暴露在極高的安全風險中**（無法修補漏洞）
- ⚠️ **2026年6月後風險急劇增加**

---

## 支援的系統

### Windows 10

| 版本 | 支援狀態 | KB5073724 | ESU 要求 | 支援結束 |
|------|---------|-----------|---------|---------|
| 22H2 | ✅ 完全支援 | ✅ | ✅ ESU (續命至 2026-10) | **2025-10-14 (已結束)** |
| 21H2 | ✅ 完全支援 | ✅ | ❌ 不支援 | 2024-06-11 (已結束) |
| Enterprise LTSC 2021 | ✅ 完全支援 | ✅ | ✅ **必須** | 2027-01-12 |
| IoT Enterprise LTSC 2021 | ✅ 完全支援 | ✅ | ✅ **必須** | 2032-01-13 |

### Windows 11

| 版本 | 支援狀態 | 自動部署 |
|------|---------|---------|
| 25H2 | ✅ 完全支援 | ✅ 2026-01 起 |
| 24H2 | ✅ 完全支援 | ✅ 2026-01 起 |
| 23H2 | ✅ 完全支援 | ⚠️ 需手動觸發 |
| 22H2 | ✅ 完全支援 | ⚠️ 需手動觸發 |

---

## 主要功能

### 1. 🔍 智能狀態檢測 (Step 1)
- **Secure Boot 狀態檢查**: 檢測 Secure Boot 是否啟用
- **BIOS 憑證讀取**: 直接讀取 BIOS/UEFI 中的憑證資訊
- **到期日預警**: 用紅/黃/綠色清楚標示憑證狀態
- **檢查 2011 舊憑證**: 識別即將到期的舊憑證

### 2. ⚡ 全自動更新 (Step 2)
- **無 ESU 自動支援**: 透過 Microsoft Update Catalog 自動下載更新
- **智能跳過**: 如果目標憑證已存在，自動跳過下載步驟
- **Windows 10**: 自動安裝 KB5073724
- **Windows 11**: 使用每月更新

### 3. 🚀 憑證部署 (Step 3)
- **自動設定註冊表**: 設定 AvailableUpdates
- **部署新憑證**: 將 Windows UEFI CA 2023 寫入 Secure Boot DB
- **驗證部署**: 確認寫入成功
- **重啟管理**: 提示所需的兩次重啟

### 4. 全自動下載功能 🆕
- **自動抓取** Microsoft Update Catalog 頁面
- **自動解析** 更新 GUID 和下載連結
- **自動下載** .cab 檔案
- **自動安裝** 使用 DISM 命令
- **智能架構偵測** (x64/x86/ARM64)
- **無需手動操作** - 完全自動化！

### 5. 友善的使用者介面
- 彩色輸出，清晰易讀
- 詳細的狀態報告
- 自動管理員權限提升
- 明確的重啟提示（兩次）

---

## 安裝方式

### 方法 1: 自動安裝（推薦）

```powershell
# 執行腳本 (會自動呼叫 PowerShell)
雙擊 RunMe.bat

# 腳本會自動處理：
# - 檢查並安裝 KB5073724 (Windows 10)
# - 檢查每月更新 (Windows 11)
# - 部署 UEFI CA 2023
# - 驗證憑證
```

### 備用方案: 手動安裝 (若自動失敗)

本工具內建自動從 Microsoft Update Catalog 下載的功能。但如果因網路問題導致自動下載失敗，您可以手動執行：

1. 自動開啟 [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)
2. 選擇符合您系統架構的版本
3. 下載 `.msu` 檔案
4. 雙擊安裝
5. 回到腳本繼續

### 方法 2: 企業部署

使用 WSUS、Intune 或 SCCM：

```powershell
# WSUS: 設定產品和分類
產品: Windows 10, version 1903 and later
分類: Security Updates

# Intune: 使用 Windows Update for Business
# SCCM: 建立軟體更新部署
```

---

## KB 更新資訊

### KB5073724 (Windows 10 主要更新)

- **發布日期**: 2026年1月13日
- **組建版本**: 
  - 19045.6809 (Windows 10 22H2)
  - 19044.6809 (Windows 10 21H2 / LTSC 2021)
- **功能**: 包含新的 Secure Boot 憑證 (2023 版本)
- **下載**: [Microsoft Update Catalog](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)

**適用版本**:
- Windows 10 版本 22H2 (所有版本)
- Windows 10 版本 21H2 (所有版本)
- Windows 10 Enterprise LTSC 2021 (需要 ESU)
- Windows 10 IoT Enterprise LTSC 2021 (需要 ESU)

**特別說明**:
- 包含分階段的安全啟動憑證部署
- 只有展現足夠成功更新訊號的裝置才會自動收到新憑證
- 移除了舊的數據機驅動程式 (agrsm64.sys, agrsm.sys, smserl64.sys, smserial.sys)

### KB5036210 (UEFI CA 2023 部署)

- **發布日期**: 2024年2月13日
- **適用系統**: Windows 10/11 (所有版本)
- **功能**: 部署 Windows UEFI CA 2023 憑證到 Secure Boot DB
- **部署方式**: 

```powershell
# 1. 設定註冊表
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdates" -Value 0x40

# 2. 啟動排程任務
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"

# 3. 重新啟動兩次

# 4. 驗證
[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
# 應該返回 True
```

### 服務堆疊更新 (SSU)

根據情況可能需要：

- **KB5031539**: 離線映像專用 (2023-10-13)
- **KB5005260**: WSUS/獨立套件專用 (2021-08-10)

---

## LTSC 版本支援

### 支援確認

✅ **KB5073724 完全支援 Windows 10 LTSC 21H2**，包括：
- Windows 10 Enterprise LTSC 2021 (21H2) - Build 19044.6809
- Windows 10 IoT Enterprise LTSC 2021 (21H2) - Build 19044.6809

### 支援時間表

| 版本 | 支援結束日期 | 備註 |
|------|-------------|------|
| Enterprise LTSC 2021 | 2027-01-12 | 需要 ESU |
| IoT Enterprise LTSC 2021 | 2032-01-13 | 支援時間較長 |

### ESU 要求

⚠️ **重要**: LTSC 版本用戶**必須加入 ESU (Extended Security Updates) 計劃**才能獲得 KB5073724

**ESU 註冊方式**:
1. 透過 Microsoft 365 管理中心
2. 透過 Volume Licensing Service Center (VLSC)
3. 聯繫 Microsoft 授權經銷商

### LTSC 安裝步驟

```powershell
# 1. 確保已加入 ESU 計劃
# 2. 執行更新工具
雙擊 RunMe.bat

# 工具會自動：
# - 檢測 LTSC 版本
# - 搜尋並下載 KB5073724
# - 安裝更新
# - 部署 UEFI CA 2023
# - 提示重啟兩次
```

---

## 非 ESU 用戶指引

### 情況說明

- ⚠️ KB5073724 主要針對 **ESU 用戶**
- ⚠️ 非 ESU 系統**無法透過 Windows Update** 獲得
- ✅ 可以從 **Microsoft Update Catalog 下載**，由本工具自動執行
- ⚠️ **注意**：如果沒有 ESU，KB 安裝後可能會在重啟時被移除（Rollback）。這是正常現象。
- ✅ **解決方案**：本工具的 **Step 3 (Registry Method)** 可以獨立於 KB 運作，強制更新 Secure Boot DB。

### 使用本工具

當執行工具時：

1. 工具會嘗試自動下載並安裝 KB5073724。
2. 如果您沒有 ESU，安裝可能會顯示成功，但重啟後被移除。
3. **不用擔心！** 請在重啟後**再次執行本工具**。
4. 工具會檢測到 KB 未安裝，但會繼續執行 **Step 3**。
5. **Step 3** 會透過註冊表強制部署 Secure Boot DB 更新。

### 替代方案

如果獨立安裝程式無法運作：

1. **升級到 Windows 11**: 免費且持續獲得更新
2. **獲取 ESU (延長支援)**: 延長 Windows 10 支援
   - **免費方案**: Windows 10 用戶只需登入 Microsoft ID 即可註冊消費者版 ESU 計畫，**免費延長一年**的 Windows 更新權利 (至 2026/10/13 止)。([官方網頁](https://www.microsoft.com/zh-tw/windows/extended-security-updates?r=1))
3. **等待**: Microsoft 可能會在憑證到期前提供非 ESU 版本 (除非微軟佛心!)
4. **手動部署憑證**: 從 [Microsoft GitHub](https://github.com/microsoft/secureboot_objects) 下載憑證檔案手動安裝

### 手動憑證部署（進階）

```powershell
# 方法 1: 透過 PowerShell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdates" -Value 0x40
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
# 重啟兩次

# 方法 2: 透過 BIOS
# 1. 從 GitHub 下載 .bin 憑證檔案
# 2. 重啟進入 BIOS/UEFI 設定
# 3. 找到 Secure Boot 設定
# 4. 匯入新的憑證檔案
```

---

## 非 ESU 模式之技術原理：為什麼有效？

**本程式就算你沒有訂閱 ESU，也能幫你安裝好 UEFI CA 2023，解決上述的所有問題！**

您可能會問：「微軟說有三個憑證要過期（KEK, UEFI CA, PCA），為什麼我們只專注於 **UEFI CA 2023**？」

### 1. 信任鏈機制 (Trust Chain)

Secure Boot 的運作並不是檢查驅動程式本身是否過期，而是檢查「**是由誰簽署的**」。

*   **目前的狀況**：驅動程式由微軟用舊鑰匙簽署，您的 BIOS 透過 `UEFI CA 2011` 信任舊鑰匙。
*   **2026 年後**：新硬體驅動程式、軟體將改用 **新密鑰** 簽署，其源頭是 **「Windows UEFI CA 2023」**。

**只要將「Windows UEFI CA 2023」加入 BIOS 的白名單 (DB)：**
任何追溯到這個新源頭的驅動程式、系統更新，都會被視為安全並允許載入。

### 2. 解決三大問題

| 面臨問題 (憑證過期) | 解決方案 (本工具 Step 3) | 結果 |
| :--- | :--- | :--- |
| **Microsoft Corporation KEK CA 2011**<br>(資料庫更新失效) | **強制密鑰輪替**<br>Step 3 觸發的註冊表命令會請求 BIOS 更新整個信任列表。 | ✅ 恢復資料庫更新能力<br>✅ KEK 與 DB 同步更新 |
| **Microsoft UEFI CA 2011**<br>(無法啟動新第三方系統/驅動) | **部署 CA 2023**<br>將新信任根加入 DB。 | ✅ **允許載入新驅動**<br>✅ 支援新版 Linux/Windows Bootloader |
| **Microsoft Windows Production PCA 2011**<br>(無法安裝 Windows 更新) | **部署 CA 2023**<br>Windows 更新包使用新憑證簽署。 | ✅ **允許安裝更新**<br>✅ 系統核心驗證通過 |

### 3. 非 ESU 方法的有效性

本工具的 **Step 3 (Registry Method)** 執行的是：
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdates = 0x40`

這不是「破解」，而是調用微軟官方設計的 **Keys Update (密鑰輪替)** 機制。
即使沒有安裝 KB5073724，只要系統內建了這個更新機制（大多數 Windows 10/11 版本都有），就能透過此命令強制 BIOS 讀取並寫入新的憑證資料。

**結論**：只要腳本最後顯示 **綠色的 OK (UEFI CA 2023 is in DB)**，您的系統就已經具備了 2026 年後的免疫力，無論之前的 KB 安裝是否被回滾。

---

## 驗證更新

### 檢查 KB5073724 是否已安裝

```powershell
Get-HotFix -Id "KB5073724"
```

### 檢查 2023 憑證

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "2023" }
```

### 檢查 Secure Boot DB

```powershell
[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
# 應該返回 True
```

### 檢查系統組建

```powershell
# Windows 10 22H2 應該是 19045.6809
# Windows 10 21H2 應該是 19044.6809
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object CurrentBuildNumber, UBR
```

---

## 企業部署

### 部署前準備

1. **測試環境驗證**
   - 先在測試環境部署
   - 驗證所有關鍵應用程式的相容性
   - 確認硬體（特別是數據機）的相容性

2. **檢查 OEM 韌體更新**
   - Microsoft 建議先安裝 OEM（Dell, HP, Lenovo）的韌體更新
   - 韌體更新是 Secure Boot 更新正確應用的基礎

### 部署方式

#### 使用 WSUS

```powershell
# 設定產品和分類
產品: Windows 10, version 1903 and later
分類: Security Updates

# KB5073724 會自動同步
```

#### 使用 Microsoft Intune

```powershell
# 建立 Windows Update for Business 原則
# 設定更新環：
# - 測試環 (10% 裝置)
# - 生產環 (90% 裝置)
```

#### 使用 Group Policy

```powershell
# 強制部署 UEFI CA 2023
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -Name "AvailableUpdatesPolicy" -Value 0x5944
```

### 分階段部署建議

1. **第 1 週**: 部署到 10% 試點機器
2. **第 2 週**: 監控並解決問題
3. **第 3-4 週**: 逐步擴大到 50%
4. **第 5-6 週**: 完成剩餘 50%

### 監控與報告

```powershell
# 檢查部署狀態
Get-HotFix -Id "KB5073724" -ComputerName (Get-ADComputer -Filter *).Name

# 檢查憑證狀態
Invoke-Command -ComputerName (Get-ADComputer -Filter *).Name -ScriptBlock {
    [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
}
```

---

## 常見問題

### Q1: 我的系統沒有看到 KB5073724 更新？

**A**: 請確認：
1. 已加入 ESU 計劃（LTSC 用戶必須，一般 Win10 用戶也建議加入）
2. ESU 授權已正確啟用
3. Windows Update 服務正常運作
4. 如果仍然沒有，使用本工具的 Microsoft Update Catalog 選項手動下載

### Q2: 安裝後需要重新啟動幾次？

**A**: 需要重新啟動**兩次**：
- 第一次重啟：下載與安裝 Windows 更新
- 第二次重啟：完成 Secure Boot DB 更新

### Q3: 我的舊數據機不能用了怎麼辦？

**A**: KB5073724 移除了舊的數據機驅動程式。如果您仍需使用：
1. 聯繫硬體製造商獲取更新的驅動程式
2. 考慮升級硬體
3. 如果必須使用舊硬體，可能需要延遲安裝此更新（不推薦）

### Q4: LTSC 2019 或更早版本支援嗎？

**A**: KB5073724 主要針對 LTSC 2021 (21H2)。更早的 LTSC 版本可能有不同的更新包，請查看 Microsoft 官方文件。

### Q5: 不安裝會怎樣？

**A**: 如果不安裝：
- 2026年6月後，Secure Boot 功能可能失效
- 無法安裝新的安全更新
- 無法使用新簽署的軟體和驅動程式
- 系統安全性嚴重受損

### Q6: 可以在虛擬機中使用嗎？

**A**: 可以，但需要注意：
- 虛擬機需要啟用 UEFI 和 Secure Boot
- 某些虛擬化平台可能不完全支援 Secure Boot DB 更新
- 建議在實體機上測試後再部署到虛擬環境

### Q7: 更新失敗怎麼辦？

**A**: 如果更新失敗：
1. 檢查 Windows Update 日誌
2. 確保已安裝最新的服務堆疊更新 (SSU)
3. 嘗試從 Microsoft Update Catalog 手動下載
4. 聯繫 Microsoft 支援

---

## 🚨 緊急救援：如果已經無法開機 (2026/6 以後) 🚨

**如果您是在 2026/6 以後才看到這篇文章，且電腦已經遭到 Secure Boot 封鎖無法進入 Windows，先別慌！請按照以下步驟自救。**

### 方法 A：暫時關閉 Secure Boot (最推薦/最快速)

這是最簡單的方法，只需要進入 BIOS 修改設定。

1.  **進入 BIOS/UEFI 設定**：開機時狂按 `Del`、`F2` 或 `F10` (視廠牌而定)。
2.  **找到 Secure Boot 選項**：通常在 `Security` 或 `Boot` 分頁。
3.  **將 Secure Boot 設定為 `Disabled` (關閉)**。
4.  **儲存並重啟** (`F10`)：現在您應該可以正常進入 Windows 了。
5.  **執行本工具**：
    *   以管理員身分執行 `RunMe.bat` (或 `Update-SecureBootCert.ps1`)。
    *   選擇 `Y` 開始更新。
    *   等待腳本完成 Step 3 (部署憑證)。
6.  **恢復 Secure Boot**：
    *   重啟電腦，再次進入 BIOS。
    *   將 Secure Boot 設定回 **`Enabled` (開啟)**。
    *   儲存並重啟。
7.  **恭喜！** 您的電腦已經擁有新憑證，可以安全運作了。

### 方法 B：透過 BIOS 手動匯入憑證 (進階)

如果您無法進入 Windows，或者方法 A 無效，可以透過 BIOS 直接匯入憑證檔案。

**準備工作** (需要另一台可用的電腦)：
1.  準備一支 **FAT32 格式** 的 USB隨身碟。
2.  下載 Microsoft 官方憑證檔案 (`.bin` 格式)：
    *   [Windows UEFI CA 2023 憑證 (GitHub)](https://github.com/microsoft/secureboot_objects)
    *   此連結會導向 Microsoft 官方 GitHub 儲存庫。
3.  將 `.bin` 檔案複製到 USB 隨身碟根目錄。

**救援步驟**：
1.  將 USB 插上故障電腦。
2.  開機進入 BIOS 設定選單。
3.  進入 Secure Boot 設定頁面。
4.  尋找 **Key Management** (金鑰管理) 或 **Custom Mode** (自訂模式)。
5.  選擇 **"Enroll Key"** (匯入金鑰) 或 **"Append to DB"** (新增至 DB)。
    *   注意：是選 **DB (Authorized Signatures)**，**絕對不要**動 PK 或 KEK，除非您很清楚自己在做什麼。
6.  選擇 `No filesystem` 或您的 USB 裝置。
7.  選取剛剛放入的 `.bin` 檔案。
8.  確認匯入 (可能顯示 "Success")。
9.  儲存 BIOS 設定並重啟。

---

## BIOS Legacy Mode 用戶注意事項 (2026/6 以後)

如果您目前是使用舊版 **Legacy BIOS (CSM)** 模式而非 UEFI 模式開機，請注意以下幾點：

### 1. 開機不受影響，但驅動程式有風險
*   因為 Legacy 模式不使用 Secure Boot，所以**不會**發生無法開機的情況 (BIOS 不會檢查 DB)。
*   **但是**，Windows 作業系統核心仍會驗證驅動程式的簽章。若您的 Windows 10 未安裝本更新，未來可能無法安裝或載入使用新憑證簽署的新硬體驅動程式 (例如安裝新版NVIDIA Driver時，就會被擋)。
*   **建議**：仍建議執行本工具安裝更新，以確保 OS 層級的相容性。

### 2. 未來升級/重灌 Windows 11 的風險
*   Windows 11 強制要求 **UEFI + Secure Boot** 環境。
*   如果您在 2026/6 後決定將電腦從 Legacy 轉為 UEFI 並重灌 Windows 11：
    *   您的舊 BIOS (尚未更新 DB) 將會**拒絕啟動**新的 Windows 11 安裝隨身碟 (因其使用新憑證簽署)。
*   **解決方案**：
    *   請參考上方的 **[緊急救援方案 A](#方法-a-暫時關閉-secure-boot-最推薦最快速)**。
    *   也就是：先**關閉 Secure Boot** 進行安裝 -> 進入 Windows 執行本工具 -> 再**開啟 Secure Boot**。

---

## 重要注意事項

### 安裝前

- ✅ 建立系統還原點或完整備份
- ✅ 確保有足夠的磁碟空間（至少 1GB）
- ✅ 關閉防毒軟體（安裝期間）
- ✅ 確保網路連線穩定

### 安裝中

- ⚠️ 不要中斷安裝過程
- ⚠️ 不要關閉電腦
- ⚠️ 等待所有更新完成

### 安裝後

- ✅ 重新啟動兩次
- ✅ 驗證憑證安裝
- ✅ 檢查系統組建版本
- ✅ 測試關鍵應用程式

---

## 參考資料

### Microsoft 官方文件

- [Windows 安全開機憑證到期和 CA 更新](https://support.microsoft.com/zh-tw/topic/windows-%E5%AE%89%E5%85%A8%E9%96%8B%E6%A9%9F%E6%86%91%E8%AD%89%E5%88%B0%E6%9C%9F%E5%92%8C-ca-%E6%9B%B4%E6%96%B0-7ff40d33-95dc-4c3c-8725-a9b95457578e)
- [KB5073724 官方頁面](https://support.microsoft.com/zh-tw/topic/bd960b49-050e-432f-a9d5-2454cb377fed)
- [KB5036210 - UEFI CA 2023 部署](https://support.microsoft.com/zh-tw/topic/kb5036210-%E5%B0%87-windows-uefi-ca-2023-%E6%86%91%E8%AD%89%E9%83%A8%E7%BD%B2%E5%88%B0%E5%AE%89%E5%85%A8%E9%96%8B%E6%A9%9F%E5%85%81%E8%A8%B1%E7%9A%84%E7%B0%BD%E7%AB%A0%E8%B3%87%E6%96%99%E5%BA%AB-db-a68a3eae-292b-4224-9490-299e303b450b)
- [Windows 10 LTSC 生命週期](https://learn.microsoft.com/zh-tw/lifecycle/products/windows-10-enterprise-ltsc-2021)
- [ESU 計劃資訊](https://learn.microsoft.com/zh-tw/windows-server/get-started/extended-security-updates-deploy)

### 下載連結

- [Microsoft Update Catalog KB5073724 下載](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)
- [Secure Boot Objects (GitHub)](https://github.com/microsoft/secureboot_objects)

### 相關文章

- [HKEPC 原始文章](https://www.hkepc.com/24893/)
- [Windows安全開機指南](https://learn.microsoft.com/zh-tw/windows-hardware/design/device-experiences/oem-secure-boot)

---

## 授權

此工具為開源工具，供個人和企業免費使用。

## 支援

如有問題，請：
1. 查看本文件的[常見問題](#常見問題)部分
2. 參考 Microsoft 官方文件
3. 聯繫系統管理員或 Microsoft 支援

---

**最後更新**: 2026-01-26  
**版本**: 1.0  
**作者**: anomixer
