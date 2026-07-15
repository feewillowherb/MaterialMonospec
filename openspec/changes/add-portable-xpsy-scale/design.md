## Context

MaterialClient 地磅读重由 `ITruckScaleWeightService` / `TruckScaleWeightService` 统一提供 `WeightUpdates`。现有协议分支：

| ScaleType | 路径 |
|-----------|------|
| Yaohua + `CommunicationMethod=TF0` | HEX 12 字节 STX/ETX |
| DingSong | HEX 专用解析 |
| TestMode | 无串口，HTTP/`SetWeight` |
| 非 TF0 的 String | `ReadTo('=')` + 反转，但校验为 `^[+-]\d{8}[A-Fa-f]$` |

便携式 XP-SY（手册 / 旧端 `DiBangScaleReceiver`）为 **9 字节 ASCII**：8 载荷（`0-9`/`.`/`-`）+ `=`，低位先发，反转后解析。现有 String 校验会丢弃合法帧；默认 TF0 会误入 HEX。需独立类型分支，算法对齐旧端。

实现范围仅 MaterialClient；OpenSpec 工件在本主仓库。

## Goals / Non-Goals

**Goals:**

- 设置中可选「便携式XP-SY」，保存后 `TruckScaleWeightService` 按该类型初始化并解析
- 帧同步与解析与旧端一致，至少覆盖：`51.07000=`→70.15、`51.0700-=`→-70.15、`.0151000=`→1510
- 解析成功后经既有 `ConvertWeight` 转成软件用吨，并推送到 `WeightUpdates`
- 用 mock 串口单测覆盖上述样例

**Non-Goals:**

- 自动协议探测（旧端有 Detect；本变更仅显式 `ScaleType`）
- 修改耀华 / 顶松 / TestMode 行为
- 改称重稳定判定、录单、UrbanManagement
- 新增独立配置字段或配置名兼容层（如「析平便携式01」）——枚举 Description 用「便携式XP-SY」即可

## Decisions

### 1. 新增 `ScaleType.PortableXPSY`，不用「改通讯方式凑 String」

- **选择**：`[Description("便携式XP-SY")] PortableXPSY`
- **理由**：与 DingSong/TestMode 一致；不依赖用户改 `CommunicationMethod`；避免与现有 String 校验冲突
- **备选**：仅设非 TF0 通信方式 → 校验仍挡掉 XP-SY 帧，不可行

### 2. 初始化强制 ASCII/`=` 路径

- **选择**：`InitializeAsync` 在 `ScaleType == PortableXPSY` 时设置 `_receType = ReceType.String`、`_endChar = "="`（或等价 9 字节缓冲接收），**忽略** TF0 是否使能 HEX
- **理由**：设置默认常为 TF0，不强制则必错
- **备选**：UI 强制改 CommunicationMethod → 易漏、难测

### 3. 独立接收/解析方法，对齐旧端

- **选择**：`ReceivePortableXPSY` + `ParsePortableXPSY`（命名可微调）：
  - 定界：载荷 8 字节合法且尾字节 `=`
  - 校验字符：`0-9`、`.`、`-`（勿用 `IsValidWeightFormat`）
  - 反转 8 字符 → `decimal`/`double`（`InvariantCulture`）→ `ConvertWeight` → `_weightSubject`
- **理由**：旧端已验证；与「符号+8 数字+校验字母」String 模式解耦
- **备选**：放宽 `IsValidWeightFormat` 兼两用 → 误判风险高，拒绝

### 4. 帧同步优先固定 9 字节扫描（推荐）

- **选择**：移植 `FindPortableXPSYFrameStart` 思路，缓冲扫描找合法 9 字节帧；成功后再丢弃已消费字节。若实现成本需压，可用 `ReadTo('=')` + 长度/字符校验作 **MVP**，真机粘包再升级扫描
- **理由**：载荷首字节非常量，不能按固定帧头找；扫描更稳
- **备选**：仅 `ReadTo` → 实现快，噪声下可能抖

### 5. UI 仅扩展下拉项

- **选择**：`ScaleTypeOptions` 增加 `PortableXPSY`；`ScaleTypeConverter` 依赖 Description，无硬编码表则可不改
- **理由**：设置页已有地磅类型 ComboBox

### 6. 数据流（概念上的多值组合用命名类型，禁止 tuple）

```mermaid
flowchart LR
  serial[SerialPort] --> recv[ReceivePortableXPSY]
  recv --> parse[Parse: reverse 8 + InvariantCulture]
  parse --> conv[ConvertWeight]
  conv --> rx[WeightUpdates]
  rx --> weighing[Attended / Urban weighing]
```

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 默认 TF0 仍走 HEX | 初始化按 ScaleType 覆盖 `_receType`；单测断言 PortableXPSY 不调 HEX |
| 复用旧 String 校验失败 | 独立校验；单测喂手册样例 |
| `ReadTo` + `DiscardInBuffer` 丢半帧 | 优先 9 字节扫描；真机冒烟 |
| 仪表单位与 `ScaleUnit` 不符 | 文档/设置沿用现有单位；联调核对 kg→t |
| 与现有非 TF0 String 行为混淆 | 代码按 ScaleType 分支，注释标明 XP-SY ≠ 现有 String 格式 |

## Migration Plan

1. 发布含新枚举的客户端；旧配置未选该类型则行为不变
2. 现场：地磅类型选「便携式XP-SY」，串口/波特率按仪表（常见 9600 8N1），保存并重启地磅服务
3. 回滚：改回耀华/顶松/测试模式即可；无 DB 迁移

## Open Questions

- 真机是否必须首版即上 9 字节扫描，还是允许 `ReadTo` MVP？**建议首版直接扫描**（旧端已有，增量小）。
- 负重/零点抖动是否需要额外过滤？**本变更不做**，交给现有稳定判定。
