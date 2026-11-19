## Why

调研观测到 138 上有效 5020 项目行数为 0。现有项目上下文在未绑定时拒绝业务请求。

## What Changes

- 通过受支持的项目来源同步有效 5020 项目，配置可信 SourceProId，验证迁移和授权后的业务访问。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-project-persistence` — 138 的 5020 项目就绪。

## Impact

UrbanManagement 的项目同步、Recycle 配置及 138 联调环境。
