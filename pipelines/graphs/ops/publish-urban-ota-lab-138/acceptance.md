# Acceptance: publish-urban-ota-lab-138

- **P0**: 本机 `pack` 成功或 SSH 连通 138（Agent 判定）
- **P1**: `urban` 发布制品（含 Full / Delta `.nupkg`、`releases.win.json`、`RELEASES`、`Setup.exe`）已上传至 `<remoteUpdatesDir>/urban`（Agent 判定）
- **P2**: `GET http://192.168.3.138:5333/updates/urban/releases.win.json` 与 `RELEASES` 返回 `200` 且 `Cache-Control` 含 `no-cache`，且清单包含目标版本（Agent 判定）
- **P3**: 人工在工控机实测从旧版经 138 更新源升级至目标版本并确认采纳（**仅用户判定**）
