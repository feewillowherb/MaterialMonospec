## Context

称重保存后发布本地事件，处理器只写日志。Web 已有 ReceiveAsync 接收路径，匿名请求返回 401，带设备身份的接收入库仍待验证。

## Goals / Non-Goals

**Goals**

- 打通落盘、受信设备上传、Web 幂等接收和台账可见链路，覆盖断网恢复和重复提交。

**Non-Goals**

- 生产部署及提交合入单独授权。

## Decisions

沿用 /api/transports/receive 与现有接收 DTO、项目绑定和来源唯一键。先查证 5020 激活凭证的签发方、受众和设备项目绑定，再确定接收认证策略。保存称重与持久待传状态需原子提交，事件可唤醒上传；超时重传复用来源标识和 kg 原值。依赖 fix-recycle-5020-project-readiness 提供 138 联调项目。

回收宿主的称重周期副作用由 `MaterialClient.Common.Recycle` 中的 `RecycleWeighingRecordSideEffects` 实现，并暴露为 `IUrbanWeighingRecordSideEffects`，替换空实现。周期结束时才标记待上传。设备接收中间件在应用服务之外调用项目查询，`ValidateAsync` 必须带工作单元，否则查询异常会被当成 401。

## Risks / Trade-offs

- 以实际业务链路的可观察结果判定验收，并记录环境、单据标识和服务响应摘要。138 历史证据见 [调研总览](../../../docs/2026-11-19-recycle-client-to-web-fev/00-调研总览.md)，部署 Run `deploy-urban-lab-138/2026-11-19T164403` 仅用于追溯当时部署。
