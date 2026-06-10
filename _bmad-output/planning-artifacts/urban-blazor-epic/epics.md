# Epics and Stories：UrbanManagement ABP Blazor 迁移

**Epic ID**: `urban-blazor-epic`
**版本**: 1.0
**状态**: Draft
**创建日期**: 2026-06-04
**关联文档**: prd.md, architecture.md

---

## 需求清单

### 功能需求 (FRs)
- **FR-1**: ABP Blazor 基础设施搭建
- **FR-2**: 核心模块迁移
- **FR-3**: ABP 服务集成
- **FR-4**: 质量保证

### 非功能需求 (NFRs)
- **性能需求**: 页面加载 < 2s，SignalR 重连 < 3s
- **安全需求**: 内网无用户 Auth；客户端 API 用 BuildLicenseNo / FdBuildLicenseNo / ClientRecordId；XSS/CSRF 基线
- **可维护性需求**: 代码减少 50%，测试覆盖 > 80%

---

## FR 覆盖映射

| FR | Epic | 描述 |
|----|------|------|
| FR-1.1 | Epic 1 | ABP Blazor NuGet 包安装 |
| FR-1.2 | Epic 1 | LeptonX Lite 主题配置 |
| FR-1.3 | Epic 1 | Blazor 组件结构创建 |
| FR-1.4 | Epic 1 | MVC/Blazor 路由共存 |
| FR-1.5 | Epic 1 | SignalR 连接配置 |
| FR-2.1 | Epic 3 | 项目管理模块迁移 |
| FR-2.2 | Epic 3 | 客户管理模块迁移 |
| FR-2.3 | Epic 3 | 称重记录模块迁移 |
| FR-2.4 | Epic 3 | 主页仪表板迁移 |
| FR-3.1 | Epic 3 | 安全模型对齐（内网无用户 Auth） |
| FR-3.2 | Epic 3 | 设置系统集成 |
| FR-3.3 | Epic 3 | 事件总线集成 |
| FR-3.4 | Epic 3 | 动态代理集成 |
| FR-4.1 | Epic 4 | 性能优化 |
| FR-4.2 | Epic 4 | 回归测试 |
| FR-4.3 | Epic 4 | 回滚机制 |
| FR-4.4 | Epic 4 | 监控配置 |

---

## Epic 列表

### Epic 1: ABP Blazor 基础设施 (Core Tier)
搭建 ABP Blazor 基础设施，为后续迁移提供稳定的技术基础。
**FRs covered**: FR-1.1, FR-1.2, FR-1.3, FR-1.4, FR-1.5

### Epic 2: 假设验证 (Assumption-Validation Tier)
验证技术迁移的关键假设，确保迁移方案的可行性。
**FRs covered**: 验证所有假设

### Epic 3: 完整迁移 (Full Tier)
完成所有核心模块的 Blazor 迁移，提供完整的现代化管理系统。
**FRs covered**: FR-2.1, FR-2.2, FR-2.3, FR-2.4, FR-3.1, FR-3.2, FR-3.3, FR-3.4

### Epic 4: 质量加固 (Quality-Delivery Tier)
完成生产环境准备，确保系统可以安全上线。
**FRs covered**: FR-4.1, FR-4.2, FR-4.3, FR-4.4

---

## Epic 1: ABP Blazor 基础设施 (Core Tier)

**目标**: 最短可运行、可验证、可回环的路径

**范围**:
- ABP Blazor 基础设施搭建
- LeptonX Lite 主题配置
- 一个简单的验证页面（如：Hello World）
- MVC 和 Blazor 路由共存

**验收标准**:
- [ ] Blazor 页面能正常渲染
- [ ] SignalR 连接稳定
- [ ] 可以回退到纯 MVC

**假设**: A-01, A-02（需要配置关闭开关）

**非目标**: 完整业务功能、性能优化

### Story 1.1: ABP Blazor NuGet 包安装

**用户故事**:
作为开发团队，
我想要安装 ABP Blazor NuGet 包，
以便开始使用 Blazor Server 功能。

**验收标准**:
```gherkin
Given 项目已安装 ABP Framework 10.x
When 开发人员在 UrbanManagement.App.csproj 中添加 Blazor 包
Then 所有必需的 NuGet 包都被正确安装
And 包版本兼容 ABP Framework 10.x
And 项目可以成功编译
```

**技术需求**:
- 安装 `Volo.Abp.AspNetCore.Components.Web`
- 安装 `Volo.Abp.AspNetCore.Components.Server`
- 安装 `Volo.Abp.AspNetCore.Components.Web.LeptonXLiteTheme`
- 安装 `Blazorise.Bootstrap5`
- 安装 `Blazorise.Icons.FontAwesome`
- 安装 `Blazorise.DataGrid`

**文件修改**:
- `UrbanManagement.App/UrbanManagement.App.csproj`

---

### Story 1.2: LeptonX Lite 主题配置

**用户故事**:
作为开发团队，
我想要配置 LeptonX Lite 主题，
以便获得现代化的管理界面外观。

**验收标准**:
```gherkin
Given ABP Blazor 包已安装
When 开发人员在 Program.cs 中配置 LeptonX 主题
Then LeptonX 样式正确加载
And 布局组件正常渲染
And 主题样式应用到所有页面
```

**技术需求**:
- 在 Program.cs 中添加 `AddLeptonXLiteTheme()`
- 配置主题启动类
- 验证主题资源文件加载
- 设置主题基本配置项

**文件修改**:
- `UrbanManagement.App/Program.cs`
- `UrbanManagement.App/Startup/AbpBlazorStartup.cs` (新建)

---

### Story 1.3: Blazor 组件结构创建

**用户故事**:
作为开发团队，
我想要创建 Blazor 组件目录结构，
以便组织 Blazor 组件代码。

**验收标准**:
```gherkin
Given LeptonX 主题已配置
When 开发人员创建 Blazor 组件目录结构
Then Components/ 目录包含所有必需的子目录
And 共享组件目录存在
And 布局组件目录存在
```

**技术需求**:
- 创建 `Components/Layout/` 目录
- 创建 `Components/Shared/` 目录
- 创建 `Components/Pages/` 目录
- 创建基础组件基类 `UrbanManagementComponentBase`

**文件创建**:
- `UrbanManagement.App/Components/Layout/MainLayout.razor`
- `UrbanManagement.App/Components/Shared/LoadingSpinner.razor`
- `UrbanManagement.App/Components/Shared/ErrorDisplay.razor`
- `UrbanManagement.App/Components/UrbanManagementComponentBase.cs`

---

### Story 1.4: MVC 和 Blazor 路由共存

**用户故事**:
作为开发团队，
我想要建立 MVC 和 Blazor 路由共存机制，
以便渐进式迁移而不影响现有功能。

**验收标准**:
```gherkin
Given Blazor 组件结构已创建
When 开发人员配置路由共存机制
Then MVC 路由继续正常工作
And Blazor 路由可以访问
And 两者不会发生冲突
And 可以通过配置开关切换
```

**技术需求**:
- 配置 Blazor 端点映射
- 配置 MVC 端点映射
- 设置优先级和回退规则
- 实现配置开关功能

**文件修改**:
- `UrbanManagement.App/Program.cs`
- `UrbanManagement/appsettings.json`
- `UrbanManagement.App/Pages/_Host.cshtml` (新建)

---

### Story 1.5: SignalR 连接配置

**用户故事**:
作为开发团队，
我想要配置 SignalR 连接，
以便实现 Blazor 实时通信。

**验收标准**:
```gherkin
Given 路由共存机制已建立
When 开发人员配置 SignalR 连接
Then SignalR Hub 正常运行
And 客户端可以建立连接
And 连接断开后自动重连
And 连接状态可以监控
```

**技术需求**:
- 配置 SignalR Hub 端点
- 实现 Blazor SignalR 连接
- 添加自动重连逻辑
- 实现连接状态监控

**文件修改**:
- `UrbanManagement.App/Program.cs`
- `UrbanManagement.App/Components/SignalRConnectionHandler.cs` (新建)

---

### Story 1.6: Hello World 验证页面

**用户故事**:
作为开发团队，
我想要创建一个简单的验证页面，
以便验证 Blazor 基础设施正常工作。

**验收标准**:
```gherkin
Given SignalR 连接已配置
When 开发人员创建 Hello World 页面
Then 页面可以在浏览器中正常访问
And LeptonX 主题样式正确显示
And ABP 服务可以正常注入
And SignalR 连接状态正常
```

**技术需求**:
- 创建简单的 Blazor 页面
- 注入 ABP 服务（如 ICurrentUser）
- 显示基本信息
- 验证主题渲染

**文件创建**:
- `UrbanManagement.App/Components/Pages/HelloWorld.razor`

---

## Epic 2: 假设验证 (Assumption-Validation Tier)

**目标**: 验证 Core tier 中的假设

**范围**:
- 实现一个完整的业务模块（如：项目管理）
- 性能测试（加载时间、并发用户）
- SignalR 稳定性测试（网络波动场景）
- AI 辅助开发效率统计
- 用户试用和反馈收集

**验收标准**:
- [ ] A-01~A-05 所有假设都有验证结果
- [ ] 每个假设有 disposition（keep/replace）
- [ ] 不符合预期的假设有替代方案

**产出**: Assumption Validation Report

### Story 2.1: 完整业务模块实现（项目管理）

**用户故事**:
作为产品负责人，
我想要实现一个完整的项目管理模块，
以便验证 Blazor 在真实业务场景下的表现。

**验收标准**:
```gherkin
Given 基础设施已搭建完成
When 开发人员实现项目管理模块
Then 模块包含完整的 CRUD 功能
And 用户界面响应流畅
And 数据操作正确
And 错误处理完善
```

**技术需求**:
- 实现项目列表页面（分页、搜索、排序）
- 实现项目创建/编辑表单
- 实现项目详情查看
- 实现数据验证和错误处理
- 不引入用户登录/权限 UI（与 ADR-007 一致）

**文件创建**:
- `UrbanManagement.App/Components/Project/ProjectList.razor`
- `UrbanManagement.App/Components/Project/ProjectForm.razor`
- `UrbanManagement.App/Components/Project/ProjectDetail.razor`

---

### Story 2.2: 性能测试

**用户故事**:
作为产品负责人，
我想要进行性能测试，
以便验证 Blazor 是否满足性能要求。

**验收标准**:
```gherkin
Given 项目管理模块已实现
When 性能测试执行
Then 页面首屏加载时间 < 2s
And 并发 50 用户时响应时间 < 3s
And 内存占用 < 500MB
And CPU 占用合理
```

**技术需求**:
- 使用性能测试工具
- 测试首屏加载时间
- 测试并发用户性能
- 测试内存占用
- 生成性能测试报告

**产出**: `Performance-Test-Report.md`

---

### Story 2.3: SignalR 稳定性测试

**用户故事**:
作为产品负责人，
我想要测试 SignalR 连接的稳定性，
以便确保在局域网环境下连接可靠。

**验收标准**:
```gherkin
Given 性能测试已完成
When 执行 SignalR 稳定性测试
Then 网络波动后重连时间 < 3s
And 连接断开后自动恢复
And 消息传输不丢失
And 多客户端同时连接稳定
```

**技术需求**:
- 模拟网络波动场景
- 测试重连机制
- 测试消息可靠性
- 测试多客户端连接
- 生成稳定性测试报告

**产出**: `SignalR-Stability-Report.md`

---

### Story 2.4: AI 辅助效率统计

**用户故事**:
作为产品负责人，
我想要统计 AI 辅助开发的效率，
以便验证 AI 工程化假设。

**验收标准**:
```gherkin
Given SignalR 测试已完成
When 统计开发效率和准确率
Then AI 辅助代码生成准确率 > 90%
And 开发时间比传统方式减少 ≥ 50%
And 代码返工率 < 15%
And 一次性可用率 > 85%
```

**技术需求**:
- 记录开发时间
- 统计代码生成准确率
- 分析返工率
- 对比传统开发方式
- 生成效率分析报告

**产出**: `AI-Efficiency-Report.md`

---

### Story 2.5: 团队技能验证

**用户故事**:
作为产品负责人，
我想要验证团队 C# 技能是否足够，
以便确保团队能够完成 Blazor 开发。

**验收标准**:
```gherkin
Given 效率统计已完成
When 评估团队技能水平
Then 团队成员能够理解 Blazor 概念
And 团队成员能够完成基本开发任务
And AI 辅助下能够解决复杂问题
And 学习曲线可接受
```

**技术需求**:
- 评估团队 Blazor 理解程度
- 评估实际开发能力
- 评估 AI 辅助效果
- 识别技能缺口
- 制定培训计划

**产出**: `Team-Skills-Assessment.md`

---

### Story 2.6: 用户试用反馈

**用户故事**:
作为产品负责人，
我想要收集用户试用反馈，
以便验证 LeptonX 主题是否满足业务需求。

**验收标准**:
```gherkin
Given 团队技能已验证
When 用户试用项目管理模块
Then 用户能够完成基本操作
And 用户界面满意度 > 80%
And 功能易用性评分 > 4/5
And 没有严重的可用性问题
```

**技术需求**:
- 准备试用环境
- 培训试用用户
- 收集用户反馈
- 分析用户体验问题
- 生成用户体验报告

**产出**: `User-Feedback-Report.md`

---

### Story 2.7: 假设验证报告

**用户故事**:
作为产品负责人，
我想要生成假设验证报告，
以便总结所有假设的验证结果。

**验收标准**:
```gherkin
Given 所有测试和反馈已完成
When 生成假设验证报告
Then 每个假设都有明确的验证结果
Then 每个假设都有 disposition (keep/replace/remove)
Then 不符合预期的假设有替代方案
Then 报告包含继续/停止的明确建议
```

**技术需求**:
- 汇总所有验证结果
- 分析每个假设的验证情况
- 制定不符合预期假设的替代方案
- 提供明确的下一步建议
- 生成综合验证报告

**产出**: `Assumption-Validation-Report.md`

---

## Epic 3: 完整迁移 (Full Tier)

**目标**: 完整迁移所有核心模块

**前置**: 依赖 validate-abp-blazor-assumptions

**范围**:
- 项目管理模块完整迁移
- 客户管理模块完整迁移
- 城市称重记录模块完整迁移
- 主页仪表板完整迁移
- 异常处理和边界情况
- 设置、事件总线、动态代理等 ABP 服务集成（不含 Identity/权限 UI）

**验收标准**:
- [ ] 所有核心功能正常工作
- [ ] 异常情况有适当的错误提示
- [ ] ABP 基础设施充分利用
- [ ] 用户体验符合预期

**非目标**: 新功能（应在 Assumption-Validation 中验证后再决定是否添加）

### Story 3.1: 项目管理模块完整迁移

**用户故事**:
作为开发团队，
我想要完整迁移项目管理模块，
以便用户可以在 Blazor 界面中管理项目。

**验收标准**:
```gherkin
Given 假设验证已完成
When 迁移项目管理模块
Then 所有项目管理功能正常工作
And 用户界面符合预期
And 性能符合要求
And 错误处理完善
```

**技术需求**:
- 迁移项目列表功能
- 迁移项目创建功能
- 迁移项目编辑功能
- 迁移项目删除功能
- 实现数据验证（内站无页面级权限）

**文件修改**:
- 完善项目管理相关组件

---

### Story 3.2: 客户管理模块完整迁移

**用户故事**:
作为开发团队，
我想要完整迁移客户管理模块，
以便用户可以在 Blazor 界面中管理客户信息。

**验收标准**:
```gherkin
Given 项目管理模块已迁移
When 迁移客户管理模块
Then 所有客户管理功能正常工作
And 搜索和筛选功能正常
And 数据导入导出功能正常
And 内站管理功能无需登录即可使用（与现有行为一致）
```

**技术需求**:
- 迁移客户列表功能
- 迁移客户信息管理
- 迁移搜索和筛选
- 迁移数据导入导出
- 不集成 Identity/页面权限

**文件创建**:
- `UrbanManagement.App/Components/Client/ClientList.razor`
- `UrbanManagement.App/Components/Client/ClientForm.razor`

---

### Story 3.3: 城市称重记录模块完整迁移

**用户故事**:
作为开发团队，
我想要完整迁移城市称重记录模块，
以便用户可以在 Blazor 界面中查看和管理称重记录。

**验收标准**:
```gherkin
Given 客户管理模块已迁移
When 迁移城市称重记录模块
Then 称重记录列表正常显示
And 记录详情查看功能正常
And 数据上传功能正常
And 审批流程功能正常
```

**技术需求**:
- 迁移称重记录列表
- 迁移记录详情查看
- 迁移数据上传功能
- 迁移审批流程
- 实现实时状态更新

**文件创建**:
- `UrbanManagement.App/Components/WeighingRecord/WeighingRecordList.razor`
- `UrbanManagement.App/Components/WeighingRecord/WeighingRecordDetail.razor`

---

### Story 3.4: 主页仪表板完整迁移

**用户故事**:
作为开发团队，
我想要完整迁移主页仪表板，
以便用户可以在 Blazor 界面中查看系统概览信息。

**验收标准**:
```gherkin
Given 称重记录模块已迁移
When 迁移主页仪表板
Then 统计卡片正确显示
And 数据图表正常渲染
And 快捷操作功能正常
And 实时数据更新正常
```

**技术需求**:
- 迁移统计卡片组件
- 迁移数据图表组件
- 迁移快捷操作功能
- 实现实时数据更新
- 优化仪表板性能

**文件创建**:
- `UrbanManagement.App/Components/Dashboard/Dashboard.razor`
- `UrbanManagement.App/Components/Dashboard/StatCard.razor`
- `UrbanManagement.App/Components/Dashboard/DataChart.razor`

---

### Story 3.5: 安全模型与客户端 API 契约对齐

**用户故事**:
作为开发团队，
我想要 Blazor 迁移与内网无用户 Auth、客户端字段身份模型一致，
以便不引入登录体系且 API 行为与 OpenSpec 一致。

**验收标准**:
```gherkin
Given 所有模块已迁移
When 审查 Blazor 与 API 配置
Then 管理端无登录页、无 Identity 模块、无 AuthorizedView
Then 客户端上报 API 仍接受 BuildLicenseNo、FdBuildLicenseNo、ClientRecordId
Then ClientRecordId 幂等行为与迁移前一致
Then 文档与 ADR-007 一致
```

**技术需求**:
- 确认未引用 AbpIdentity* / OpenIddict 等用户认证模块
- Blazor 页面不注入 IPermissionChecker / ICurrentUser
- 保持 Receive/Approve 等 AppService 对许可证字段与 ClientRecordId 的处理

---

### Story 3.6: ABP 设置系统完整集成

**用户故事**:
作为开发团队，
我想要完整集成 ABP 设置系统，
以便用户可以配置系统参数。

**验收标准**:
```gherkin
Given 模块迁移与安全模型已对齐
When 集成 ABP 设置系统
Then 设置读取功能正常
Then 设置配置界面正常
Then 设置验证和保存正常
```

**技术需求**:
- 集成 ISettingProvider
- 创建设置配置界面
- 单租户内站（不引入多租户登录）
- 实现设置验证
- 优化设置性能

---

### Story 3.7: ABP 事件总线完整集成

**用户故事**:
作为开发团队，
我想要完整集成 ABP 事件总线，
以便组件之间可以通信。

**验收标准**:
```gherkin
Given 设置系统已集成
When 集成 ABP 事件总线
Then 事件发布功能正常
Then 事件订阅功能正常
Then 跨组件通信正常
Then 实时状态同步正常
```

**技术需求**:
- 集成 IEventBus
- 实现事件发布
- 实现事件订阅
- 处理事件异常
- 优化事件性能

---

### Story 3.8: 异常处理和边界情况

**用户故事**:
作为开发团队，
我想要完善异常处理和边界情况，
以便系统在各种情况下都能稳定运行。

**验收标准**:
```gherkin
Given 事件总线已集成
When 完善异常处理
Then 所有异常都有友好提示
Then 网络错误有重试机制
Then 边界情况有正确处理
Then 系统不会意外崩溃
```

**技术需求**:
- 实现全局异常处理
- 实现网络错误重试
- 处理边界情况
- 实现日志记录
- 优化错误恢复

---

## Epic 4: 质量加固 (Quality-Delivery Tier)

**目标**: 生产环境准备和运维能力

**前置**: 依赖 migrate-urban-to-abp-blazor

**范围**:
- 移除 jQuery 和 LayUI 依赖
- 清理旧的 MVC 控制器和视图
- 性能优化（SignalR、组件渲染）
- 回归测试套件
- 回滚和降级演练
- 监控和告警配置
- 文档更新（运维、故障排查）

**验收标准**:
- [ ] 旧依赖完全清理
- [ ] 性能基准达标（页面加载 < 2s）
- [ ] 回归测试通过率 100%
- [ ] 回滚演练成功
- [ ] 运维文档完整

### Story 4.1: 移除 jQuery 和 LayUI 依赖

**用户故事**:
作为开发团队，
我想要移除 jQuery 和 LayUI 依赖，
以便简化技术栈和减少安全风险。

**验收标准**:
```gherkin
Given 所有功能已迁移
When 移除 jQuery 和 LayUI 依赖
Then 项目不再引用 jQuery 包
Then 项目不再引用 LayUI 包
Then 所有功能仍正常工作
Then 页面加载性能提升
```

**技术需求**:
- 移除 jQuery NuGet 包
- 移除 LayUI 相关文件
- 清理相关代码引用
- 验证功能完整性
- 测试页面性能

**文件删除/修改**:
- 删除 jQuery 相关文件
- 删除 LayUI 相关文件
- 更新包引用

---

### Story 4.2: 清理旧的 MVC 控制器和视图

**用户故事**:
作为开发团队，
我想要清理旧的 MVC 控制器和视图，
以便简化代码结构。

**验收标准**:
```gherkin
Given jQuery 和 LayUI 已移除
When 清理旧的 MVC 代码
Then 所有旧的 Controller 被删除
Then 所有旧的 View 文件被删除
Then 路由配置已更新
Then 系统仍正常工作
```

**技术需求**:
- 识别可删除的 Controller
- 识别可删除的 View 文件
- 更新路由配置
- 验证功能完整性
- 更新文档

**文件删除**:
- 删除旧的 MVC Controller
- 删除旧的 View 文件

---

### Story 4.3: 性能优化

**用户故事**:
作为开发团队，
我想要进行性能优化，
以便确保系统满足性能要求。

**验收标准**:
```gherkin
Given 旧代码已清理
When 进行性能优化
Then 页面加载时间 < 2s
Then SignalR 重连时间 < 3s
Then 内存占用 < 500MB
Then 并发用户数 ≥ 50
```

**技术需求**:
- 优化组件渲染性能
- 优化 SignalR 连接
- 优化内存使用
- 实现缓存策略
- 优化数据库查询

**产出**: `Performance-Optimization-Report.md`

---

### Story 4.4: 回归测试套件

**用户故事**:
作为质量保证团队，
我想要创建回归测试套件，
以便确保所有功能正常工作。

**验收标准**:
```gherkin
Given 性能优化已完成
When 创建回归测试套件
Then 所有核心功能都有测试用例
Then 测试通过率 100%
Then 测试自动化完成
Then CI/CD 集成完成
```

**技术需求**:
- 创建单元测试
- 创建集成测试
- 创建 E2E 测试
- 实现测试自动化
- 集成 CI/CD 流程

**产出**: 测试套件和测试报告

---

### Story 4.5: 回滚和降级演练

**用户故事**:
作为运维团队，
我想要进行回滚和降级演练，
以便确保系统可以安全回退。

**验收标准**:
```gherkin
Given 回归测试已完成
When 进行回滚演练
Then 回滚机制工作正常
Then 回滚时间 < 5 分钟
Then 数据完整性得到保证
Then 回滚后系统正常工作
```

**技术需求**:
- 准备回滚方案
- 执行回滚演练
- 验证数据完整性
- 测试回滚时间
- 优化回滚流程

**产出**: `Rollback-Plan.md` 和演练报告

---

### Story 4.6: 监控和告警配置

**用户故事**:
作为运维团队，
我想要配置监控和告警，
以便及时发现问题。

**验收标准**:
```gherkin
Given 回滚演练已完成
When 配置监控和告警
Then 所有关键指标都有监控
Then 异常情况有告警
Then 告警通知及时送达
Then 监控数据可视化
```

**技术需求**:
- 配置性能监控
- 配置错误监控
- 配置告警规则
- 配置告警通知
- 创建监控仪表板

**文件创建**:
- 监控配置文件
- 告警配置文件
- 监控仪表板

---

### Story 4.7: 文档更新

**用户故事**:
作为技术写作团队，
我想要更新所有文档，
以便支持系统运维和故障排查。

**验收标准**:
```gherkin
Given 监控配置已完成
When 更新所有文档
Then 运维文档完整
Then 故障排查指南完整
Then API 文档更新
Then 用户文档更新
```

**技术需求**:
- 编写运维文档
- 编写故障排查指南
- 更新 API 文档
- 更新用户手册
- 创建培训材料

**产出**:
- `Operations-Guide.md`
- `Troubleshooting-Guide.md`
- 更新后的 API 文档
- 用户培训材料

---

## Epic Retrospective

### Epic 1 Retrospective
**执行时间**: Phase 1 完成后
**参与者**: 开发团队、产品负责人

### Epic 2 Retrospective
**执行时间**: Phase 2 完成后
**参与者**: 开发团队、产品负责人、质量保证

### Epic 3 Retrospective
**执行时间**: Phase 3 完成后
**参与者**: 开发团队、产品负责人、质量保证、用户代表

### Epic 4 Retrospective
**执行时间**: Phase 4 完成后
**参与者**: 所有利益相关者

---

## 交付物清单

### Phase 1 交付物
- [ ] ABP Blazor 基础设施
- [ ] Hello World 验证页面
- [ ] 技术配置文档

### Phase 2 交付物
- [ ] 项目管理模块（完整实现）
- [ ] 性能测试报告
- [ ] SignalR 稳定性报告
- [ ] AI 效率分析报告
- [ ] 团队技能评估报告
- [ ] 用户反馈报告
- [ ] 假设验证综合报告

### Phase 3 交付物
- [ ] 完整迁移的模块
- [ ] 集成测试报告
- [ ] 性能优化报告

### Phase 4 交付物
- [ ] 清理后的代码库
- [ ] 回归测试套件
- [ ] 回滚方案和演练报告
- [ ] 监控配置
- [ ] 完整文档集

---

## 成功标准总结

### 技术指标
- [ ] 100% C# 全栈开发
- [ ] jQuery 依赖为 0
- [ ] ABP 动态代理覆盖率 > 95%
- [ ] LeptonX 主题集成度 100%
- [ ] 单元测试覆盖 > 80%
- [ ] 页面响应时间 < 2s

### ABP 利用率
- [ ] 模块化 UI 系统使用
- [ ] ABP 服务完全集成
- [ ] 确认无登录/权限 UI（ADR-007）
- [ ] 设置系统 UI 展现
- [ ] 主题系统启用

### 开发效率
- [ ] 新功能开发时间减少 50%
- [ ] AI 辅助代码生成准确率 > 90%
- [ ] 文件数量减少 60%
- [ ] 代码行数减少 50%

---

**文档状态**: Draft - 待审核
**下一步**: `/bmad:check-implementation-readiness` 检查实现就绪状态
**相关文档**: prd.md, architecture.md
