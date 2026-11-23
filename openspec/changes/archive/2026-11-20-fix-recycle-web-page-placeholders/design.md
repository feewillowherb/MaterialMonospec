## Context

车辆、合同和运输清单的列表行在 `RecycleWebEndpoints` 的 `*PageRow.FromDto` 里组装。车辆状态、市上报、录入时间、合同附件名和运输阶段目前是固定字或空字符串。运输的 `WeighedAt`、`UnloadPoint` 已在 `RecycleTransportDto` 中，`TransporterName` 在运输实体上但没有进入读 DTO。车辆 `CreationTime` 是 ABP 审计字段，也没有进入 `RecycleVehicleDto`。

合同 `SyncStatus` 以枚举名返回。`Succeeded` 只在已记录平台响应 `code` 200 时写入。生产管理已从侧栏隐藏，`/productions` 回到车辆管理。

用户要求本变更直接在 UrbanManagement `main` 上实施。

## Goals / Non-Goals

**Goals:**

- 三页只显示已存储的车辆、合同和运输事实。
- 去掉保存后不会留下的控件和筛选。
- 合同筛选按原始枚举匹配，标签使用中文。
- 当前版本继续隐藏生产管理。

**Non-Goals:**

- 不接入附件文件，不挂载 uploads。
- 不从运输记录推导车辆「运输中」。
- 不改日产量页面字段，不改市平台上报的发送、跳过和重试。
- 不加表，不改迁移。

## Decisions

1. 车辆读 DTO 增加 `CreationTime`，运输读 DTO 增加 `TransporterName`。投影从实体读取，不新增列。
2. 时间显示固定为 `Asia/Shanghai` 的 `yyyy-MM-dd HH:mm`。车辆 `CreationTime` 按 UTC 换算，包括从数据库读出后失去 `DateTimeKind` 的值。`DateTimeKind.Utc` 的过磅时间同样换算；`Unspecified` 的过磅时间和收货时间视为钟面时间，不再加八小时。
3. 合同上报状态继续返回 `None`、`Pending`、`Succeeded`、`Failed`。页面把前两个显示为「未上报」，`Succeeded` 显示为「已上报」，`Failed` 显示为「上报失败」。筛选比较枚举值，「未上报」匹配 `None` 和 `Pending`。
4. 运输状态由投影计算：无皮重为「待补皮重」，已称重且没有 `ReceivingTime` 为「待收货」，已有收货时间为「已收货」。列表不再使用 `loopPhase`。
5. 卸点列绑定已有的 `UnloadPoint`。收货服务继续用合同 `ShipAddress` 写入卸点，页面只预览购买方和地址。
6. 收货和过磅的提示读取 HTTP 状态与响应体。合同批量上报无论成功、部分成功或失败都重新读取列表。
7. 生产管理的隐藏留在路由：侧栏没有入口，`/productions` 重定向到 `/vehicles`。日产量接口保留。

## Risks / Trade-offs

- [Risk] 容器时区与浏览器时区不一致，同一条 UTC 时间会显示成不同日期。→ 显示换算固定使用 `Asia/Shanghai`，不依赖容器本地时区。
- [Risk] 去掉运输勾选列后，页面不能再发起运输批量上报。→ 后端两个上报路由保留，方向仍由 `add-recycle-web-platform-reporting` 处理。
- [Risk] `Succeeded` 若将来能在没有 `code` 200 时写入，页面会把它显示成「已上报」。→ 本变更不放宽 `RecycleSyncAttempt.CreateObserved` 的既有限制。

## Migration Plan

无数据库迁移。发布时重新构建 Recycle 前端并更新 Recycle 镜像。回退该提交即可恢复旧页面。

## Open Questions

无。生产管理重新打开时再处理标识编号、发送时间和上报文案。
