## 1. Git / branch (MaterialClient)

- [x] 1.1 在 MaterialClient 从 trunk 切出同名分支 `refactor-dingsong-to-ds822x`（Mode A）；编排仓仅改本 change 工件时可在同名分支或 main 按 openspec-git-workflow 处理

## 2. DS822-X 解析类型（Common）

- [x] 2.1 新增命名 `record` + static `TryParse`（无 DI、无 tuple）：校验 `02`/`03`、`ADD`∈A–Z、`CHK=(xor前缀)|0x40`
- [x] 2.2 `A`/`a`：22 字节 → 净重（符号 + 6 位 / `10^p`，`p`∈0–4）；失败返回 null
- [x] 2.3 `C`/`c`：17 字节 → 按 design 六组 `(hi,lo)` 取数字位；金标 `02 41 63 30 20 30 20 30 20 30 20 38 20 3C 30 74 03` → **8**

## 3. TruckScaleWeightService

- [x] 3.1 `ScaleType.DingSong` + HEX：粘包缓冲扫描，按命令字母分派 A/C；完整合法帧才 `ConvertWeight` 并 `OnNext`
- [x] 3.2 移除 / 停用旧 12 字节 `ParseHexWeightDingSong` 成功路径；旧样例必须 null
- [x] 3.3 确认 `DingSongAddr4` 分支与 `_byteCount` 行为未改

## 4. 测试

- [x] 4.1 新增 / 改写测试：`C` 金标 → 8；构造合法 `A` 帧（自算 CHK）→ 期望净重；坏 CHK → null
- [x] 4.2 旧 12 字节顶松样例在 DingSong 路径 → null；H610 在 DingSong → null、在 Addr4 → 610 仍通过

## 5. 验收

- [x] 5.1 跑通相关 Common 单测；有仪表时用 `Adr=3` 对照屏幕，或用 hex 回放 `_tmp/text.txt`（Agent 不宣布 L3 通过）
