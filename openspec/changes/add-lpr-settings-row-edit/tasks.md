## 1. Shared dialog mode

- [x] 1.1 Add add-vs-edit mode (and bound `DialogTitle`) on `AddLprDialogViewModel`; keep one Window type
- [x] 1.2 Bind `AddLprDialog` window `Title` to the mode; do not hard-code only「添加车牌识别设备」
- [x] 1.3 Prefill edit after defaults so existing UserName/Port/Channel are not wiped; `EditLprAsync` already replaces the row

## 2. Settings grid

- [x] 2.1 Show the LPR DataGrid「编辑」button (`IsVisible` true / remove hide)
- [x] 2.2 Confirm `EditLprCommand` still passes the row and `AddLicensePlateRecognitionCommand` still appends

## 3. Verify

- [ ] 3.1 Manual: add a row, edit every vendor field, cancel leaves collection unchanged; save settings persists
- [ ] 3.2 Manual: edit Hikvision and Vzvision rows; vendor switch still shows the right field groups
