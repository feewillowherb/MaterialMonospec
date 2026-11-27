# Design: Inno Setup D-Drive First-Install Bootstrapper

## Division of Responsibilities

- **Inno Setup (`MaterialClient.Urban-Installer.exe`)**: First-time interactive Chinese wizard only.
  - `DefaultDirName={code:GetDefaultInstallDir}` → returns `D:\MaterialClient.Urban` when `D:\` exists, else `{localappdata}\MaterialClient.Urban`.
  - `DisableDirPage=no` so the customer can browse to another drive if desired.
  - `Uninstallable=no`, `CreateUninstallRegKey=no`, `PrivilegesRequired=lowest` → zero UAC friction, zero duplicate uninstall entries.
  - `Compression=none` because `MaterialClient.Urban-win-Setup.exe` is already compressed by Velopack (fast build < 2s).
  - Extracts `Setup.exe` to `{tmp}` and runs `Setup.exe -s --installto "{app}"` with `waituntilterminated`.
- **Velopack (`Update.exe` + `current\` + `data\`)**: Owns installation layout, shortcuts, uninstall registration, and all subsequent selective Delta OTA updates in-place inside `{app}`.

## Admin Download Resolution

- `OtaPackageCatalogService.GetUrbanCatalogAsync` issues a lightweight `HEAD` request to `/updates/urban/MaterialClient.Urban-Installer.exe` on the same reachable feed base URL; if `200 OK`, returns `SetupDownloadUrl = "/updates/urban/MaterialClient.Urban-Installer.exe"` and `SetupFileName = "MaterialClient.Urban-Installer.exe"`, otherwise falls back to `MaterialClient.Urban-win-Setup.exe`.
