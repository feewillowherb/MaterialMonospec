## Why

Web 补全 DTO 把合同、明细、材料 ID 全部置空，只传文本，服务的关联 ID 校验无法覆盖这条页面路径。合同页面写入形状也只能携带一个运输人，无法兑现现行多运输人场景。

## What Changes

- 用项目内真实合同、合同明细、材料标识完成运输单；补齐合同多运输人的页面写入与回读。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-web-persistence-api` — 运输补全的项目内业务选择。

## Impact

UrbanManagement Recycle Web 及既有合同和运输应用服务。
