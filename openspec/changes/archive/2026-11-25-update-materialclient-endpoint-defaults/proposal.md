# Change: 将服务端点默认地址收敛到代码（区分 Release/Debug）并禁止发布 appsettings.json

## Why

在完成 `refactor-clean-materialclient-appsettings` 后，4 个 MaterialClient 宿主的 `appsettings.json` 与 `appsettings.secret.json` 中仍残留服务端 `BaseUrl` 配置，且代码内置回退值仍指向 `http://localhost:5000`：
1. 正式站点部署时仍必须依赖外部 `appsettings*.json` 才能连上生产服务端，无法实现“生产零配置”；
2. `appsettings.secret.json` 的加载优先级高于 `appsettings.json`，其内残留的 `BasePlatform:BaseUrl` 与 `MaterialPlatform:BaseUrl` 会导致测试时修改 `appsettings.json` 被静默覆盖；
3. 发布包仍附带 `appsettings.json`，增加现场误编辑或覆盖漂移风险。

## What Changes

- **在 `MaterialClientConfigurationDefaults` 中内置服务端点默认地址（区分 Release / Debug）**：
  - `Release` 默认使用正式生产地址：
    - `BasePlatform:BaseUrl` = `http://base.publicapi.findong.com`
    - `MaterialPlatform:BaseUrl` = `http://mt.publicapi.findong.com`
    - `UrbanManagement:BaseUrl` = `http://191.12.234.212:5233`
    - `RecycleSync:ApiUrl` = `http://localhost`（站点外发接口，保持安全默认值待现场按处置点配置）
  - `#if DEBUG` 默认使用测试/本地地址，防止开发机 F5 调试误连生产库：
    - `BasePlatform:BaseUrl` = `http://192.168.3.135:8551`
    - `MaterialPlatform:BaseUrl` = `http://localhost:5000`
    - `UrbanManagement:BaseUrl` = `http://192.168.3.138:5333`
    - `RecycleSync:ApiUrl` = `http://localhost`
- **统一消费方回退逻辑**：
  - `RefitClientRegistrationExtensions`、`MaterialClientUrbanModule`、`MaterialClientRecycleModule` 在配置缺失或为空时回退至 `MaterialClientConfigurationDefaults` 对应默认地址；
  - 若外部 `appsettings.json`、环境变量或 User Secrets 显式配置了对应 URL，则以显式配置为准（测试时直接覆盖正式站点）。
- **彻底清理 4 个宿主的 `appsettings.json` 与 `appsettings.secret.json` 中的 URL，并禁止发布 `appsettings.json`**：
  - 4 个宿主的 `appsettings.json` 统一收敛为空对象 `{}`；
  - 4 个宿主的 `.csproj` 对 `appsettings.json` 设置 `<CopyToPublishDirectory>Never</CopyToPublishDirectory>`，确保发布产物不包含 `appsettings.json`；
  - 从 4 个宿主的 `appsettings.secret.json` 中移除 `BasePlatform:BaseUrl` 与 `MaterialPlatform:BaseUrl`（避免覆盖测试期 `appsettings.json`）；
  - **显式排除不变**：`AliyunOss` 与 `Encryption:AesKey` 继续保留在 `appsettings.secret.json` 中，本次不修改。

## Capabilities

### Modified Capabilities
- `client-configuration-defaults`: 新增 Release/Debug 服务端点代码默认值、外部 `appsettings.json` 覆写优先规则，以及 `appsettings.json` 不随发布包输出的要求。

## Impact

- **受影响仓库**：仅 `repos/MaterialClient`（Mode A：Trunk-direct，分支名 `update-materialclient-endpoint-defaults`）。
- **受影响项目**：`MaterialClient.Common`、`MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Urban`、`MaterialClient.Recycle`、`MaterialClient.Common.Tests`。
- **兼容性**：非破坏性。正式发布包不带 `appsettings.json` 即可直连正式环境；测试或特殊站点在 `.exe` 同目录放置 `appsettings.json` 即可覆盖任意服务端 URL。
