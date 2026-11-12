# Common 与 MaterialClient.* 项目边界核对

日期：2026-11-12。方式：检查 src 下全部 csproj 的 ProjectReference、ABP Module DependsOn，并抽样核对职责落点。静态事实为 CONFIRMED；架构判断为 INFERRED。未执行编译与运行期 DI 验证。

## 判断

**INFERRED：存在职责与命名边界混杂，但项目引用方向整体有序。** 不能把它描述成所有项目互相引用的混乱图。当前更接近“共享大底座 + 产品扩展数据模块 + 带业务逻辑的桌面宿主”，尚未实现“纯共享内核 + 独立产品用例 + 可替换基础设施”。

## 项目引用图（CONFIRMED）

箭头表示项目直接引用；省略同一节点重复边。

```text
Common.EntityFrameworkCore → Common
Common.Urban / Common.Recycle → Common + Common.EntityFrameworkCore
UI → Common
AttendedWeighing → Common + UI
MaterialClient → Common + Common.EntityFrameworkCore + UI + AttendedWeighing
MaterialClient.Urban → Common + Common.EntityFrameworkCore + Common.Urban + UI
MaterialClient.Recycle → Common + Common.EntityFrameworkCore + Common.Recycle + UI + AttendedWeighing
Toolkit → Common + Common.EntityFrameworkCore
```

证据：各同名目录下 csproj 的 ProjectReference；如 `repos/MaterialClient/src/MaterialClient.Common.Urban/MaterialClient.Common.Urban.csproj:19`、`repos/MaterialClient/src/MaterialClient.Urban/MaterialClient.Urban.csproj:55`、`repos/MaterialClient/src/MaterialClient.AttendedWeighing/MaterialClient.AttendedWeighing.csproj:30`。Demo 未在扫描结果中出现 ProjectReference，不能据此推定其用途或活跃状态。

在所检查的直接项目引用中，Common 没有反向引用 UI 或三个桌面宿主，也未发现项目引用环。ABP 产品模块显式依赖对应 Common 产品模块。命名空间相似不等于循环依赖。

## 确认的混杂点

| 事实（CONFIRMED） | 边界判断（INFERRED） | 实际影响 |
|---|---|---|
| Common.csproj 同时引入 EF SQLite、HTTP、串口、原生 SDK、ReactiveUI，固定 win-x64 | Common 是共享实现集合，不能视为纯 Domain/Core | headless 可以做，但测试构建依赖和平台依赖偏重 |
| Common 内有 RecycleReceivingService、RecycleWeighingService、SolidWasteService、UrbanAnomalyDetector 等产品业务实现 | “共用”同时包含复用规则和产品专用能力 | 产品差异修改可能影响共同底座，归属不直观 |
| Common.Urban 与 Common.Recycle 包含 Entity、Service、DbContext、Migration，并引用共享 EF 项目 | 它们是垂直产品数据/业务模块，名称不能解释为纯领域层 | 使用业务模块时同时引入数据库装配；并非必然错误，但隔离级别有限 |
| Urban 宿主 Services 中有 UrbanServerUploadService、UrbanPassageUploadService、ServerApprovalSyncCoordinator；Recycle 宿主有 RecycleDataSyncService | 可独立测试的后台用例仍与桌面宿主共处 | 复用后台业务可能需要引用桌面项目，测试入口更难保持轻量 |
| CommonModule 在初始化时默认启动 ImageCleanupBackgroundService | 引入公共模块存在主动生命周期副作用 | headless 集成宿主需要明确禁用或替换，不能仅依靠不创建窗口 |

定位：`repos/MaterialClient/src/MaterialClient.Common/MaterialClient.Common.csproj:5`；`repos/MaterialClient/src/MaterialClient.Common/MaterialClientCommonModule.cs:40`；`repos/MaterialClient/src/MaterialClient.Common.Urban/MaterialClientCommonUrbanModule.cs:12`；`repos/MaterialClient/src/MaterialClient.Common.Recycle/MaterialClientCommonRecycleModule.cs:12`。产品服务落点见上述各项目 Services 目录。

## 不应误判的地方

- Common 中保留 `IUrbanWeighingRecordSideEffects` 或 `IRecycleWaybillExtensionStore`，产品模块实现它们，是依赖倒置的有效接缝；接口带产品名称不是直接的反向依赖证据。证据：`repos/MaterialClient/src/MaterialClient.Common/Services/Urban/IUrbanWeighingRecordSideEffects.cs:9` 与 `repos/MaterialClient/src/MaterialClient.Common.Recycle/Services/RecycleWaybillExtensionStore.cs:10`。
- UI 引用业务接口、产品宿主组合 EF 与 UI 是正常方向。问题在于具体职责是否穿透，不能用“宿主引用太多项目”单独判为错误。
- 产品专属 DbContext 与迁移已经拆出，说明产品持久化有隔离进展；不能因为 Common 仍大就否定这些边界。
- Common.Urban / Common.Recycle 当前按产品纵向切分，可以是有意设计。若目标只要求业务测试，先分离初始化与 I/O 接缝即可，不必强制按每一层增加程序集。

## 建议的责任归属

| 职责 | 建议归属 |
|---|---|
| 跨产品称重不变量、稳定判断、状态迁移、基础契约 | 共享业务内核，尽量不依赖 UI、EF、SDK |
| 产品匹配、接收、同步流程 | 对应产品的无窗口业务模块 |
| EF 映射、DbContext、Migration、持久化实现 | 共享或产品基础设施模块 |
| SDK、串口、文件、远端 HTTP | 对应外部适配实现 |
| View、ViewModel、Dispatcher、弹窗 | UI/有人称重功能模块 |
| 启动、前台驻留、配置与模块组合、退出顺序 | 各桌面宿主 |

这是责任目标，不是要求立即创建同名项目。先明确现有类型的 owner 与允许依赖，再用实际测试成本决定物理拆分。

## 下一步核对与改进顺序

1. 修复已确认的 UI Repository 穿透，避免测试路径跨过应用边界。
2. 对 Common 的后台启动建立显式测试配置；识别构造和模块初始化中的设备/文件/网络副作用。
3. 选择 Urban 单轮上传作为试点，使其可在无桌面宿主下执行测试；保持宿主负责触发与生命周期。
4. 为 Recycle/SolidWaste/Urban 的 Common 实现逐个标注“共享规则、产品规则、适配器”，按具体用例迁移，避免单纯改名搬目录。
5. 最后评估 Common 纯业务与硬件/基础设施的程序集隔离，并设置允许引用规则，防止边界再次退化。

待验证：产品接口默认实现与产品实现是否正确替换、不同组合根是否意外注册无关产品服务、搬移程序集对 ABP 扫描与启动次序的影响。静态引用图无法证明这些运行时性质。
