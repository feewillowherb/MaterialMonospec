# Tasks: add-urban-inno-setup-bootstrapper

## 1. MaterialClient
- [x] 1.1 Create `scripts/urban-installer.iss` (ChineseSimplified, default `D:\MaterialClient.Urban` with `LocalAppData` fallback, `Uninstallable=no`, runs embedded `Setup.exe -s --installto "{app}"`)
- [x] 1.2 Update `scripts/pack-urban-ota.ps1` to invoke `ISCC.exe` after `vpk pack` and emit `MaterialClient.Urban-Installer.exe`

## 2. UrbanManagement.Admin
- [x] 2.1 Update `OtaPackageCatalogService` and `ClientUpdates.razor` to prefer `MaterialClient.Urban-Installer.exe` (falling back to `MaterialClient.Urban-win-Setup.exe`)

## 3. Verification
- [x] 3.1 Validate OpenSpec (`--strict`), build `UrbanManagement.Admin`, and run `ISCC.exe` / `pack-urban-ota.ps1` verification
