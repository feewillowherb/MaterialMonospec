## Context

`ScaleType.DingSong` 当前按 12 字节 `02 ± 8位数字 marker 03` 解析（与耀华形态相近），有单测但**不符合** DS822-X 手册。现场 `_tmp/text.txt` 为 17 字节连续帧，校验符合手册 `CHK = xor|0x40`，命令为 `c`（`Adr=3`）。

权威协议：`docs/Device/顶松DS822-X_串口通讯协议.md`。

用户已确认：**直接替换**旧 12 字节；连续帧支持 **Adr=1 + Adr=3** 自动识别；**不改** `DingSongAddr4`。

Git：**Mode A**。Apply 时仅在 MaterialClient 从 trunk 切 `refactor-dingsong-to-ds822x`。

## Goals / Non-Goals

**Goals:**

- DingSong + HEX（`TF0`）稳定解析 DS822-X `A`/`a`（Adr=1）与 `C`/`c`（Adr=3）连续帧，校验通过后更新 `WeightUpdates`。
- 旧 12 字节顶松帧一律拒绝。
- 解析逻辑可单测；金标含现场 `C` 帧与构造的 `A` 帧。

**Non-Goals:**

- 不实现指令应答轮询（主机发 `A`/`C`/`K`/`N`/`O`/`V`）。
- 不支持手册其它连续 `Adr`（2/4/5/6/8/9/11/12）的字节格式（无完整手册表或非本现场）。
- 不改 `DingSongAddr4`、耀华、设置页枚举值、过磅业务。
- 不从 `C` 帧拆毛/皮/净业务记账（仍只发当前显示重量一个 `decimal`）。

## Decisions

1. **替换 `ParseHexWeightDingSong` / 接收路径，不新增枚举成员**  
   仍用 `ScaleType.DingSong`。接收改为粘包扫描（类似 Addr4）：找 `02`，读命令字节决定期望帧长，凑齐后验 `03` 与 `CHK`。  
   备选：新枚举 `DingSongDS822` — 否决（用户要求重构 DingSong）。  
   备选：旧 12 字节 fallback — 否决（用户要求 replace）。

2. **帧识别与长度**

   | 命令 | 期望长度 | 布局 |
   |---|---|---|
   | `A` / `a` | 22 | `02 ADD cmd (±) nnnnnn p tttttt e ff CHK 03` |
   | `C` / `c` | 17 | `02 ADD cmd [12 字节显示位] CHK 03` |

   - `ADD`：`A`–`Z`（`0x41`–`0x5A`）。
   - `CHK`：对 `CHK` 之前所有字节异或，再 `| 0x40`，须等于 `CHK` 字节。
   - 非法帧：丢弃并自下一字节继续扫 `02`。

3. **`A` 帧重量**  
   净重 = 符号 + 6 位整数，再除以 `10^p`（`p` 为 ASCII 小数位数字 0–4，与耀华 Demo 小数规则对齐；若现场 `p` 超范围则丢弃帧）。皮重 / `e` / `ff` 本 change **不**写入 `WeightUpdates`（仍单通道重量）。  
   连续手册写 `(XON)AA…`：实现按 `ADD` + `A`/`a` 识别，不硬编码仅地址 `A`。

4. **`C` 帧重量（锁现场金标）**  
   手册写 `p1d1…p6d6`，但现场字节第二列多为 `0x20`，属性不落在 `0–3` ASCII。按现场可测规则：

   - 将 12 字节视为 6 组 `(hi, lo)`。
   - 每组取 **`hi`**：若为 ASCII 数字则作为显示位，否则该位空白。
   - 忽略 `lo`（现场为填充/属性，不足以实现手册灯态）。
   - 将 6 个显示位拼成整数（前导空白当无数字）；小数位默认 **0**（现场金标无可靠小数标记）。
   - `_tmp/text.txt` 单帧 MUST 解析为重量 **8**（显示位 `0,0,0,0,8,空白` → 8）。

   备选：严格按手册 `p∈0..3` — 否决，无法通过现场帧。  
   若后续仪表 `C` 帧编码不同，另开 change，不在本替换里猜多种变体。

5. **纯解析用命名 `record` + static `TryParse`，不注册 DI**  
   例如 `DingSongDs822Frame`（或分 `A`/`C` record）放在 Common 合适命名空间；`TruckScaleWeightService` 只负责串口粘包与发布。禁止 tuple。符合 `minimal-di` / `type-owned-methods`。

6. **`_byteCount` / 接收分支**  
   DingSong HEX 不再固定读 12 字节；改用独立粘包缓冲（可复用或并列于 Addr4 缓冲，**勿**与 Addr4 共用解析）。`DingSongAddr4` 分支保持原样。

7. **测试**  
   - 删除或改写断言「12 字节顶松可解析」的用例为「旧帧返回 null」。  
   - 新增：`C` 金标 → 8；构造合法 `A` 帧（自算 CHK）→ 期望净重；CHK 错误 / 错结束符 → null；Addr4 样例在 DingSong 路径仍 null。

## Risks / Trade-offs

- [BREAKING：旧 12 字节现场读不到重量] → 提案已标注；设置说明 / 实施时依赖仪表改 `Adr`/`modE`。
- [C 帧启发式与其它固件不一致] → 金标绑 `_tmp/text.txt`；偏差另开 change。
- [A 帧 22 字节粘包半帧] → 粘包缓冲 + 长度门闩，不齐不解析。
- [Parity 7E1 vs 代码固定 8N1] → 保持现有串口参数与其它秤型一致；现场 `modE=6`（8N1）对齐；7 位校验差异不在本 change 改串口层。

## Migration Plan

1. 发布含新解析的 MaterialClient；选「顶松」的现场将仪表设为连续发送且 `Adr=1` 或 `3`。
2. 仍发旧 12 字节的仪表：改通讯格式，或临时改用其它秤型（若适用）。
3. 回滚：恢复旧 `ParseHexWeightDingSong` 与固定 12 字节读。

## Open Questions

- 无阻塞问题。`C` 帧小数位若现场需要，待有带小数的抓包再扩展。
