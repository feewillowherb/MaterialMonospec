## Context

LPR 行已有每行 `LprDeviceType`（厂商）与共用 `AddLprDialog`。本变更增加**另一维度**：设备装在哪类点位。与厂商类型无关。设置 JSON 已在 `LicensePlateRecognitionConfigs`；缺字段须能加载。

Urban 设置页已有仅 Urban 可见的分区；站点类型的「可切换」与此同构：用现有宿主判定（Urban 宿主 vs 标准/固废/回收），不要新发明产品探测。

## Goals / Non-Goals

**Goals:**

- 基线枚举：地磅 / 卡口 / 成品；代码标识 `Scale` / `Checkpoint` / `FinishedProduct`（或同等英文名，UI 中文）。
- 新行与反序列化缺省 = 地磅。
- Urban：增加、编辑可选三种；表格可见该列。
- 非 Urban：控件不可改（隐藏 Combo 或只读地磅），确认与保存的行 MUST 为地磅。
- 本期运行时忽略该字段。

**Non-Goals:**

- 不按站点类型过滤识别流、道闸、称重、匹配、上云。
- 不改 UrbanManagement 服务端模型。
- 不拆独立 Edit 对话框。
- 不把该字段写进内核 SQLite 新表（仍走现有 LPR JSON）。

## Decisions

1. **字段挂在每行配置，不挂 SystemSettings 全局**  
   与「一行一个厂商」一致。备选：全局模式。放弃：城管会混装三种点。

2. **非 Urban 强制地磅写在 UI 确认与宿主加载，不在 SDK**  
   打开 Add/Edit 时锁定；非 Urban 保存前将集合中非地磅行规范为地磅（防止旧 JSON 或手改文件带出卡口）。备选：仅隐藏 Combo、允许脏 JSON 残留。放弃：用户要求强制。

3. **无业务语义用规范写死，而不是空注释**  
   DeviceManager / `ILprDevice` / 道闸 / 称重匹配 MUST NOT 读取该属性。后续 change 再赋义。

4. **Avalonia Combo + 转换器**  
   与 `LprDeviceType` 相同模式。非 Urban 用 `IsEnabled=false` 或 `IsVisible` 绑宿主标志，避免 WPF Trigger。

## Risks / Trade-offs

- [非 Urban 打开曾在 Urban 保存的卡口行] → 加载进设置 VM 时显示地磅；用户一点保存就会写成地磅。可接受（强制）。
- [后续误把字段当过滤] → spec 明确禁止；代码审查对照 DeviceManager。

## Migration Plan

旧 JSON 无字段 → 反序列化为地磅。回滚：忽略未知 JSON 属性或删列（旧客户端忽略新字段）。

## Open Questions

无。
