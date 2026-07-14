# local-image-retention-cleanup Specification

## Purpose

Defines MaterialClient local disk image retention cleanup: configuration, periodic Worker behavior, and registration for all product clients that depend on Common.

## Requirements

### Requirement: ImageCleanup 配置契约

系统 MUST 从 `appsettings.json` 的 `BackgroundServices:ImageCleanup` 节读取本地图片清理配置，并绑定到强类型 options（如 `ImageCleanupOptions`）。配置 MUST 至少包含：

| 键 | 类型 | 含义 | 默认 |
|----|------|------|------|
| `Enabled` | bool | 是否注册并运行清理后台任务 | `true` |
| `RetentionDays` | int | 保留天数；早于「今天 − RetentionDays」的图片可删 | `90` |
| `IntervalHours` | int | 清理任务执行间隔（小时） | `24` |
| `InitialDelayHours` | int | 首次执行前相对延迟（小时）；`0` 表示立即清理。不是日内固定钟点 | `1` |

#### Scenario: 默认配置加载

- **WHEN** 应用启动且节存在或缺省
- **THEN** options MUST 可用，且未显式配置的字段取上表默认值

#### Scenario: 禁用清理

- **WHEN** `BackgroundServices:ImageCleanup:Enabled` 为 `false`
- **THEN** 系统 MUST NOT 注册或 MUST NOT 执行清理 Worker 的删除逻辑

### Requirement: 定期清理过期 Camera 与 Lpr 磁盘文件

系统 MUST 提供基于 ABP `AsyncPeriodicBackgroundWorkerBase`（或等价周期性后台 Worker）的图片清理任务。Worker 首次 tick 后 MUST 先等待 `InitialDelayHours`（相对延迟，非固定钟点；`<= 0` 则不等待）再执行清理，之后按 `IntervalHours` 周期执行。每次执行 MUST 扫描并删除应用程序目录下以下根目录中超过保留期的图片文件：

- `PhotoJianKong`（非 Urban 枪机）
- `Lpr`（LPR 与新写入的 UrbanPhoto）
- `PhotoUrban`（仅历史兼容；新写入已改用 `Lpr`）

保留截止时间 MUST 为本地日期的「今天 − RetentionDays」对应日的开始（或等价：目录日期 / 文件时间严格早于 cutoff）。对可识别的 `{root}/{yyyy}/{MM}/{dd}` 目录 MUST 按目录日期判定；对无法解析日期的历史扁平文件（如旧版 `Lpr/*.jpg`）MUST 按文件 `LastWriteTime`（本地或 UTC，实现统一）判定。删除失败 MUST 记录 Warning 并继续，MUST NOT 抛出未处理异常中断整个 Worker。`RetentionDays < 1` 时 MUST 跳过删除并记录 Warning。

#### Scenario: 启动后延迟再清理

- **GIVEN** `InitialDelayHours` 为 `1`
- **WHEN** Worker 首次 tick
- **THEN** 系统 MUST 等待约 1 小时后再执行删除逻辑
- **AND** 后续周期仍按 `IntervalHours` 执行

#### Scenario: 零延迟立即清理

- **GIVEN** `InitialDelayHours` 为 `0`
- **WHEN** Worker 首次 tick
- **THEN** 系统 MUST 立即执行清理（无需等待钟点）

#### Scenario: 删除超过保留期的日期目录文件

- **GIVEN** `RetentionDays` 为 `90`
- **AND** 今天为 2026-07-14
- **AND** 存在 `PhotoJianKong/2026/01/01/cam_1_xxx.jpg` 与 `Lpr/2026/01/01/浙A_….jpg`
- **WHEN** 清理任务执行
- **THEN** 上述两文件 MUST 被删除（因 2026-01-01 早于 cutoff）

#### Scenario: 保留期内 Lpr 目录文件不被删除

- **GIVEN** `RetentionDays` 为 `90`
- **AND** 今天为 2026-07-14
- **AND** 存在 `Lpr/2026/07/01/cam_1_xxx.jpg`（UrbanPhoto 或 LPR）
- **WHEN** 清理任务执行
- **THEN** 该文件 MUST NOT 被删除

#### Scenario: 历史 PhotoUrban 仍可被清理

- **GIVEN** 存在 `PhotoUrban/2026/01/01/cam_1_xxx.jpg` 且目录日早于 cutoff
- **WHEN** 清理任务执行
- **THEN** 该文件 MUST 被删除

#### Scenario: 历史扁平 Lpr 按文件时间清理

- **GIVEN** 存在 `Lpr/old_plate.jpg`（无年月日子目录）且 `LastWriteTime` 早于 cutoff
- **WHEN** 清理任务执行
- **THEN** 该文件 MUST 被删除

#### Scenario: 不清理票据与调试目录

- **WHEN** 清理任务执行
- **THEN** MUST NOT 以本任务名义删除 `PhotoPiaoJu` 或 `LprDebug` 下的文件

### Requirement: 全部产品客户端具备清理任务

本地图片清理是**全部产品客户端**的标配能力。系统 MUST 在 `MaterialClientCommonModule`（或等价公共模块）中统一注册 `ImageCleanup` Worker，使得依赖 Common 的产品入口——至少包括 `MaterialClient`（Standard / SolidWaste）、`MaterialClient.Urban`、`MaterialClient.Recycle`——在 `BackgroundServices:ImageCleanup:Enabled == true`（默认 true）时均可执行清理。MUST NOT 做成仅某一产品线才有的功能。

#### Scenario: Standard 宿主具备清理

- **WHEN** `MaterialClient` 启动且 `ImageCleanup:Enabled` 为 `true`
- **THEN** ImageCleanup Worker MUST 已注册并按配置周期运行

#### Scenario: Urban 宿主具备清理

- **WHEN** Urban 客户端启动且 `ImageCleanup:Enabled` 为 `true`
- **THEN** ImageCleanup Worker MUST 已注册并按配置周期运行

#### Scenario: Recycle 宿主具备清理

- **WHEN** Recycle 客户端启动且 `ImageCleanup:Enabled` 为 `true`
- **THEN** ImageCleanup Worker MUST 已注册并按配置周期运行

#### Scenario: 公共模块统一注册

- **WHEN** 任一产品宿主完成 ABP 应用初始化且 Enabled 为 true
- **THEN** Worker MUST 由 Common 公共模块注册路径生效，而非仅某一宿主 Module 私有注册
