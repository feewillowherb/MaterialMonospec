# Architecture：UrbanManagement ABP Blazor 迁移

**Epic ID**: `urban-blazor-epic`
**版本**: 1.0
**状态**: Draft
**创建日期**: 2026-06-04
**关联文档**: prd.md

---

## 1. 架构概述

### 1.1 当前架构
```
┌─────────────────────────────────────────────┐
│            UrbanManagement.App              │
│  ┌───────────────────────────────────────┐ │
│  │  ABP Framework 10.x                    │ │
│  │  ├─ Modules (Auth, Setting, etc.)    │ │
│  │  ├─ DbContext & Repository            │ │
│  │  └─ Application Services              │ │
│  └───────────────────────────────────────┘ │
│              ↓                              │
│  ┌───────────────────────────────────────┐ │
│  │  MVC 层 (传统)                         │ │
│  │  ├─ Controllers (C#)                   │ │
│  │  ├─ Views (CSHTML + Razor)           │ │
│  │  └─ jQuery/Bootstrap 前端             │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 1.2 目标架构
```
┌─────────────────────────────────────────────┐
│            UrbanManagement.App              │
│  ┌───────────────────────────────────────┐ │
│  │  ABP Framework 10.x                    │ │
│  │  ├─ Modules (Auth, Setting, etc.)    │ │
│  │  ├─ DbContext & Repository            │ │
│  │  └─ Application Services              │ │
│  └───────────────────────────────────────┘ │
│              ↓                              │
│  ┌───────────────────────────────────────┐ │
│  │  Blazor Server 层 (现代化)             │ │
│  │  ├─ Components (C#)                    │ │
│  │  ├─ LeptonX Lite Theme                │ │
│  │  ├─ SignalR 双向通信                 │ │
│  │  └─ ABP 动态代理                     │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 1.3 架构迁移原则
1. **渐进式迁移**: MVC 和 Blazor 共存，逐步切换
2. **保持稳定**: Application 层和 Core 层保持不变
3. **最大化 ABP 利用**: 充分利用 ABP Blazor 基础设施
4. **可回退设计**: 每个阶段都可以安全回退

---

## 2. 核心架构决策

### 2.1 ADR-001: 采用 ABP Blazor Server
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
采用 ABP Framework 10.x 的 Blazor Server UI 模式，而非 Blazor WebAssembly。

#### 理由
| 优势 | 说明 |
|------|------|
| **ABP 原生支持** | ABP Framework 官方支持，与现有架构无缝集成 |
| **SignalR 双向通信** | 实时状态同步，减少轮询开销 |
| **服务器端渲染** | SEO 友好，首屏加载快 |
| **调试便利性** | 服务器端调试，类似传统 Web 开发 |
| **包大小** | 无需下载整个运行时到客户端 |

#### 后果
- 需要稳定的 SignalR 连接
- 服务器资源占用增加
- 需要处理连接断开重连逻辑

#### 替代方案
- Blazor WebAssembly: 考虑过但排除，因为 ABP 官方主要支持 Server 模式

### 2.2 ADR-002: 采用 LeptonX Lite 主题
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
使用 ABP 官方的 LeptonX Lite 免费主题，不使用商业版或自定义主题。

#### 理由
| 优势 | 说明 |
|------|------|
| **免费开源** | 无需额外授权费用 |
| **ABP 官方维护** | 与 ABP Framework 同步更新 |
| **现代化设计** | Bootstrap 5 基础，响应式布局 |
| **组件丰富** | 开箱即用的常用组件 |

#### 后果
- UI 风格受限于 LeptonX 设计
- 某些高级组件需要商业版
- 需要适配现有业务需求

#### 替代方案
- 自定义主题: 开发成本高，维护负担重
- 商业版 LeptonX: 增加成本，首期不采用

### 2.3 ADR-003: 动态 C# 客户端代理模式
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
使用 ABP 的动态 C# 客户端代理系统，在 Blazor 组件中直接注入 Application Service 接口。

#### 架构对比
```csharp
// 传统方式：需要手动处理 HTTP 请求
public class ProjectController : Controller
{
    [HttpPost]
    public async Task<IActionResult> Search(string keyword)
    {
        var client = new HttpClient();
        var response = await client.PostAsJsonAsync("/api/app/project/search", keyword);
        var projects = await response.Content.ReadFromJsonAsync<List<ProjectDto>>();
        return Json(new { success = true, data = projects });
    }
}

// ABP Blazor 方式：直接注入应用服务接口
@page "/projects"
@inject IProjectAppService ProjectAppService

@code {
    protected override async Task OnInitializedAsync()
    {
        // 直接调用，就像本地方法一样
        var projects = await ProjectAppService.GetListAsync(
            new PagedAndSortedResultRequestDto { SkipCount = 0, MaxResultCount = 10 }
        );
        // ABP 自动处理 HTTP、JSON 序列化、异常、认证
    }
}
```

#### 理由
- 消除手动 HTTP 调用代码
- 编译时类型检查
- 自动处理认证、异常、序列化
- 大幅减少代码量

#### 后果
- 依赖 ABP 动态代理生成机制
- 需要理解 ABP 的代理模式

### 2.4 ADR-004: 渐进式迁移策略
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
采用渐进式迁移策略，MVC 和 Blazor 共存，分 4 个阶段逐步迁移。

#### 迁移阶段
```
┌─────────────────────────────────────────────┐
│  Phase 1: ABP Blazor 基础设施搭建 (3-5 天)  │
├─────────────────────────────────────────────┤
│  ├─ 安装 ABP Blazor NuGet 包                │
│  ├─ 配置 LeptonX Lite 主题                  │
│  ├─ 创建基础组件和布局                      │
│  ├─ 建立 Blazor 路由映射                    │
│  └─ 验证 SignalR 连接                       │
├─────────────────────────────────────────────┤
│  Phase 2: 新功能 Blazor 优先 (5-7 天)       │
├─────────────────────────────────────────────┤
│  ├─ 称重记录审批模块（Blazor 实现）         │
│  ├─ 客户附件上传功能（Blazor 实现）          │
│  ├─ 数据同步状态监控（Blazor 实现）         │
│  └─ 持续集成测试                            │
├─────────────────────────────────────────────┤
│  Phase 3: 核心模块迁移 (7-10 天)            │
├─────────────────────────────────────────────┤
│  ├─ 项目管理（优先）                         │
│  ├─ 客户管理                                 │
│  ├─ 城市称重记录                             │
│  └─ 主页仪表板                               │
├─────────────────────────────────────────────┤
│  Phase 4: 收尾和优化 (3-5 天)               │
├─────────────────────────────────────────────┤
│  ├─ 移除 jQuery 和 LayUI 依赖               │
│  ├─ 清理旧的 MVC 控制器和视图               │
│  ├─ 性能调优（SignalR 优化）                │
│  └─ 文档更新                                │
└─────────────────────────────────────────────┘
```

#### 理由
- 降低风险，每阶段都可回退
- 新功能优先 Blazor，积累经验
- 逐步提升团队技能

#### 后果
- 迁移周期较长（2-3周）
- 需要维护两套系统并存期
- 需要严格的版本管理

### 2.5 ADR-005: 构造函数依赖注入模式
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
在 Blazor 组件中使用 ABP 扩展的构造函数依赖注入，而非标准 Blazor 的属性注入。

#### 实现对比
```csharp
// 标准 Blazor：属性注入
@code {
    [Inject] protected IProjectAppService ProjectAppService { get; set; }
}

// ABP 扩展：构造函数注入（更好的类型安全）
public partial class ProjectList
{
    private readonly IProjectAppService _projectAppService;
    private readonly IUiMessageService _messageService;
    private readonly NavigationManager _nav;

    public ProjectList(
        IProjectAppService projectAppService,
        IUiMessageService messageService,
        NavigationManager nav)
    {
        _projectAppService = projectAppService;
        _messageService = messageService;
        _nav = nav;
    }
}
```

#### 理由
- 编译时类型安全
- 依赖关系更清晰
- 更好的测试性
- 符合 ABP 架构模式

### 2.6 ADR-006: 模块化组件架构
**状态**: 已批准
**日期**: 2026-06-04

#### 决策
采用模块化组件架构，按功能模块组织 Blazor 组件。

#### 目录结构
```
UrbanManagement.App/
├── Components/
│   ├── Layout/
│   │   ├── MainLayout.razor           # 主布局（可覆盖 LeptonX）
│   │   ├── SideBarMenu.razor          # 侧边栏菜单
│   │   └── Toolbar.razor              # 工具栏
│   ├── Project/                       # 项目模块
│   │   ├── ProjectList.razor         # 项目列表
│   │   ├── ProjectForm.razor         # 项目表单
│   │   └── ProjectDetail.razor       # 项目详情
│   ├── UrbanWeighingRecord/           # 称重记录模块
│   └── Shared/                        # 共享组件
│       ├── ConfirmationDialog.razor
│       ├── LoadingSpinner.razor
│       └── ErrorDisplay.razor
```

#### 理由
- 按业务功能组织，便于维护
- 共享组件复用
- 清晰的模块边界

---

## 3. 技术栈架构

### 3.1 前端技术栈

#### 核心框架
```xml
<ItemGroup>
  <!-- ABP Blazor 核心 -->
  <PackageReference Include="Volo.Abp.AspNetCore.Components.Web" Version="10.*" />
  <PackageReference Include="Volo.Abp.AspNetCore.Components.Server" Version="10.*" />

  <!-- LeptonX Lite 主题 -->
  <PackageReference Include="Volo.Abp.AspNetCore.Components.Web.LeptonXLiteTheme" Version="10.*" />

  <!-- Blazorise 组件库 -->
  <PackageReference Include="Blazorise.Bootstrap5" Version="1.*" />
  <PackageReference Include="Blazorise.Icons.FontAwesome" Version="1.*" />
  <PackageReference Include="Blazorise.DataGrid" Version="1.*" />
</ItemGroup>
```

#### 组件库层次
```
┌─────────────────────────────────────┐
│  业务组件 (自定义)                   │
│  ├─ ProjectList                     │
│  ├─ WeighingRecordList              │
│  └─ ClientManagement                │
├─────────────────────────────────────┤
│  共享组件 (自定义)                   │
│  ├─ LoadingSpinner                  │
│  ├─ ErrorDisplay                    │
│  └─ ConfirmationDialog               │
├─────────────────────────────────────┤
│  Blazorise 组件库                   │
│  ├─ DataGrid                        │
│  ├─ Modal                           │
│  └─ Button                          │
├─────────────────────────────────────┤
│  ABP 组件                           │
│  ├─ AuthorizedView                  │
│  ├─ Alert                           │
│  └─ ObjectExtension                 │
├─────────────────────────────────────┤
│  LeptonX 布局组件                   │
│  ├─ MainLayout                      │
│  ├─ SideBarMenu                     │
│  └─ Toolbar                         │
└─────────────────────────────────────┘
```

### 3.2 后端技术栈

#### 保持不变
- ABP Framework 10.x
- Entity Framework Core
- PostgreSQL 数据库
- Application Services 接口

#### 新增能力
- SignalR Hub 支持
- Blazor Server 中间件
- 动态代理生成器

---

## 4. 数据流架构

### 4.1 传统 MVC 数据流
```
┌──────────────┐
│ Browser      │
└──────┬───────┘
       │ HTTP/JSON
┌──────▼────────┐
│ Controller    │ ← 返回 JSON
└──────┬────────┘
       │ C#
┌──────▼────────┐
│ App Service   │
└───────────────┘
```

### 4.2 ABP Blazor 数据流
```
┌──────────────┐
│ Browser       │
└──────┬───────┘
       │ SignalR
┌──────▼────────┐
│ Blazor UI     │ ← 直接注入 IAppService
│ + ABP Proxy   │   无需 HTTP 调用
└──────┬────────┘
       │ C# 方法调用
┌──────▼────────┐
│ App Service   │
└───────────────┘
```

### 4.3 SignalR 通信架构
```
┌─────────────────────────────────────────┐
│  Blazor Client                          │
│  ├─ Component Injection                │
│  ├─ Hub Connection                      │
│  └─ Event Subscription                  │
└─────────────────────────────────────────┘
              ↕ SignalR
┌─────────────────────────────────────────┐
│  ABP SignalR Hub                        │
│  ├─ Authentication                      │
│  ├─ Authorization                       │
│  └─ Event Broadcasting                  │
└─────────────────────────────────────────┘
              ↕
┌─────────────────────────────────────────┐
│  Application Services                   │
│  └─ Event Publishing                    │
└─────────────────────────────────────────┘
```

---

## 5. 部署架构

### 5.1 部署模式

#### 开发环境
```
UrbanManagement.App (Blazor Server)
├─ Kestrel Web Server
├─ SignalR Hub
├─ PostgreSQL Local
└─ ABP Module System
```

#### 生产环境
```
Load Balancer
    ├─ UrbanManagement Instance 1
    ├─ UrbanManagement Instance 2
    └─ UrbanManagement Instance N

Shared Resources:
├─ PostgreSQL Server
├─ Redis Cache (Optional)
└─ File Storage
```

### 5.2 配置管理

#### appsettings.json 结构
```json
{
  "Abp": {
    "Blazor": {
      "EnableRemoteEnvironment": false,
      "ClientSideTimeoutDuration": 300
    }
  },
  "SignalR": {
    "EnableDetailedErrors": false,
    " hubs": {
      "Notification": "/hubs/notification"
    }
  },
  "LeptonX": {
    "Theme": "Lite",
    "Style": "Bootstrap5"
  }
}
```

---

## 6. 性能架构

### 6.1 性能优化策略

#### 组件级优化
- 使用 `OwningComponentBase` 管理服务生命周期
- 实现 `ShouldRender` 优化重渲染
- 使用 `Virtualize` 处理大列表

#### SignalR 优化
- 自动重连机制
- 消息压缩
- 连接池管理

#### 数据加载优化
- 分页加载
- 延迟加载
- 缓存策略

### 6.2 性能监控指标

| 指标 | 目标值 | 监控方式 |
|------|--------|----------|
| 页面首屏加载 | < 2s | Performance API |
| SignalR 重连时间 | < 3s | Hub Connection 状态 |
| 内存占用 | < 500MB | Process Monitor |
| 并发连接数 | ≥ 50 | Load Test |

---

## 7. 安全架构

### 7.1 安全层次

#### 认证层次
```
┌─────────────────────────────────────┐
│  UI Layer (Blazor)                  │
│  ├─ AuthorizedView Component       │
│  └─ Permission Checking             │
├─────────────────────────────────────┤
│  SignalR Layer                      │
│  ├─ JWT Authentication              │
│  └─ Connection Authorization         │
├─────────────────────────────────────┤
│  Application Layer                   │
│  ├─ ABP Permission System           │
│  └─ Data Authorization              │
└─────────────────────────────────────┘
```

#### 权限控制
```csharp
// UI 层权限控制
<AuthorizedView Policy="UrbanManagement.Projects.Create">
    <Button Color="Color.Primary" Click="OpenCreateModal">
        添加项目
    </Button>
</AuthorizedView>

// 代码层权限检查
@inject IPermissionChecker PermissionChecker

@code {
    private async Task<bool> CanDeleteProject()
    {
        return await PermissionChecker.IsGrantedAsync("UrbanManagement.Projects.Delete");
    }
}
```

### 7.2 安全威胁与防护

| 威胁 | 防护措施 |
|------|----------|
| XSS 攻击 | Blazor 自动编码 |
| CSRF 攻击 | ABP Anti-Forgery |
| 未授权访问 | ABP Permission System |
| SignalR 劫持 | JWT 认证 |

---

## 8. 集成架构

### 8.1 ABP 服务集成

#### 权限系统集成
```csharp
@inject IPermissionChecker PermissionChecker
@inject ISettingProvider SettingProvider
@inject ICurrentUser CurrentUser
@inject ICurrentTenant CurrentTenant

@code {
    protected override async Task OnInitializedAsync()
    {
        // 权限检查
        var canCreate = await PermissionChecker.IsGrantedAsync("UrbanManagement.Projects.Create");

        // 读取设置
        var maxItems = await SettingProvider.GetAsync<int>("UrbanManagement.MaxProjectItems");

        // 当前用户信息
        var userName = CurrentUser.UserName;
        var userId = CurrentUser.Id;
    }
}
```

#### 事件总线集成
```csharp
public partial class ProjectList : ILocalEventHandler<ProjectCreatedEto>
{
    [Inject] protected IEventBus EventBus { get; set; }

    protected override async Task OnInitializedAsync()
    {
        EventBus.Subscribe<ProjectCreatedEto>(this);
    }

    public async Task HandleEventAsync(ProjectCreatedEto eventData)
    {
        await LoadProjectsAsync();
        await InvokeAsync(StateHasChanged);
    }
}
```

### 8.2 外部服务集成

#### 文件服务集成
```csharp
@inject IFileAppService FileAppService

@code {
    private async Task UploadFile(IBrowserFile file)
    {
        var content = await file.OpenReadStream(maxFileSize);
        await FileAppService.UploadAsync(new FileUploadInput
        {
            FileName = file.Name,
            ContentType = file.ContentType,
            Content = content
        });
    }
}
```

---

## 9. 测试架构

### 9.1 测试层次

```
┌─────────────────────────────────────┐
│  E2E Tests (Selenium/Playwright)   │
│  └─ 用户场景验证                   │
├─────────────────────────────────────┤
│  Integration Tests                  │
│  └─ 组件交互验证                   │
├─────────────────────────────────────┤
│  Unit Tests                         │
│  └─ 组件逻辑验证                    │
└─────────────────────────────────────┘
```

### 9.2 测试策略

#### 单元测试
- 组件逻辑测试
- 服务调用验证
- 边界条件测试

#### 集成测试
- 组件交互测试
- 数据流验证
- SignalR 连接测试

#### E2E 测试
- 完整用户场景
- 跨浏览器测试
- 性能测试

---

## 10. 迁移架构

### 10.1 迁移路径

#### 架构兼容性
```
迁移阶段：
┌─────────────────────────────────────┐
│  Phase 1: 双栈共存                  │
│  ├─ MVC 路由: /projects/*          │
│  └─ Blazor 路由: /blazor/projects  │
├─────────────────────────────────────┤
│  Phase 2: 功能迁移                  │
│  ├─ 新功能 → Blazor                │
│  └─ 旧功能 → MVC (暂保留)          │
├─────────────────────────────────────┤
│  Phase 3: 核心迁移                  │
│  ├─ 核心模块 → Blazor              │
│  └─ 辅助功能 → MVC (暂保留)        │
├─────────────────────────────────────┤
│  Phase 4: 完全迁移                  │
│  └─ 全部 → Blazor                  │
└─────────────────────────────────────┘
```

### 10.2 回退架构

#### 回退策略
```csharp
// 配置开关
public static class BlazorFeature
{
    public static bool IsEnabled { get; set; } = true;
}

// 路由配置
app.UseEndpoints(endpoints =>
{
    if (BlazorFeature.IsEnabled)
    {
        endpoints.MapRazorPages();
        endpoints.MapBlazorHub();
        endpoints.MapFallbackToPage("/_Host");
    }
    else
    {
        endpoints.MapControllerRoute(
            name: "default",
            pattern: "{controller=Home}/{action=Index}/{id?}");
    }
});
```

---

## 11. 监控与日志架构

### 11.1 应用监控

#### 性能监控
```csharp
@inject IPerformanceMonitor PerformanceMonitor

@code {
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            await PerformanceMonitor.RecordPageLoad("ProjectList");
        }
    }
}
```

#### 错误监控
```csharp
try
{
    await ProjectAppService.CreateAsync(input);
}
catch (Exception ex)
{
    await ErrorMonitor.LogException(ex);
    await MessageService.Error("创建失败", ex.Message);
}
```

### 11.2 日志架构

#### 日志层次
```
┌─────────────────────────────────────┐
│  Application Logs                    │
│  ├─ User Actions                    │
│  ├─ Business Events                 │
│  └─ System Errors                   │
├─────────────────────────────────────┤
│  Component Logs                      │
│  ├─ Lifecycle Events                │
│  ├─ Render Performance               │
│  └─ State Changes                   │
├─────────────────────────────────────┤
│  SignalR Logs                       │
│  ├─ Connection Events               │
│  ├─ Message Traffic                 │
│  └─ Reconnection Attempts            │
└─────────────────────────────────────┘
```

---

## 12. 技术债务管理

### 12.1 现有技术债务

| 债务项 | 影响 | 优先级 | 解决计划 |
|--------|------|--------|----------|
| jQuery 全局依赖 | 高 | P0 | Phase 4 清理 |
| LayUI 组件 | 中 | P1 | Phase 3 替换 |
| 缺乏类型安全 | 高 | P0 | Phase 1-3 逐步消除 |
| 代码重复 | 中 | P2 | Phase 3 重构 |

### 12.2 新增技术债务预防

#### 代码组织
- 组件复用优先
- 共享组件库
- 一致的命名规范

#### 文档维护
- 组件使用文档
- API 文档
- 架构决策记录

---

## 13. 架构演进路径

### 13.1 短期演进（1-3 个月）
```
当前状态 → Phase 1 完成 → Phase 2 完成
     ↓           ↓              ↓
  MVC+jQuery  双栈共存      新功能Blazor优先
```

### 13.2 中期演进（3-6 个月）
```
Phase 3 完成 → Phase 4 完成 → 稳定运行
     ↓              ↓            ↓
 核心迁移完成   完全迁移    生产优化
```

### 13.3 长期演进（6-12 个月）
```
稳定运行 → 功能增强 → 架构优化
   ↓          ↓          ↓
 功能完善   新功能开发  性能调优
```

---

## 14. 架构风险与缓解

### 14.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| SignalR 连接不稳定 | 高 | 中 | 自动重连 + 降级方案 |
| ABP 版本兼容性 | 中 | 低 | 使用稳定版本，充分测试 |
| LeptonX 限制 | 低 | 中 | 自定义扩展 |
| 性能下降 | 中 | 中 | 性能监控，优化策略 |

### 14.2 业务风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 用户体验变化 | 中 | 低 | 渐进式迁移，用户培训 |
| 功能缺失 | 高 | 低 | 详细测试，回退方案 |
| 数据迁移问题 | 高 | 低 | Application层不变 |

---

## 15. 架构成功标准

### 15.1 技术指标
- [ ] 100% C# 全栈开发
- [ ] jQuery 依赖为 0
- [ ] ABP 动态代理覆盖率 > 95%
- [ ] LeptonX 主题集成度 100%
- [ ] 单元测试覆盖 > 80%
- [ ] 页面响应时间 < 2s

### 15.2 架构质量
- [ ] 模块化组件结构清晰
- [ ] 依赖关系合理
- [ ] 可维护性提升
- [ ] 可扩展性增强
- [ ] 技术债务降低

---

## 16. 附录

### 16.1 参考文档
- [ABP Blazor UI 官方文档](https://docs.abp.io/en/abp/latest/UI/Blazor/Overall)
- [LeptonX Lite 文档](https://docs.abp.io/en/abp/latest/UI/Themes/LeptonX-Lite)
- [Blazor Server 最佳实践](https://docs.microsoft.com/en-us/aspnet/core/blazor/)

### 16.2 架构决策记录模板
每个 ADR 应包含：
- 标题和状态
- 决策背景
- 考虑的替代方案
- 决策理由
- 后果分析

### 16.3 技术栈版本信息
```
ABP Framework: 10.x
.NET: 8.0+
PostgreSQL: 15+
SignalR: ASP.NET Core SignalR
LeptonX: 10.x
Blazorise: 1.x
```

---

**文档状态**: Draft - 待审核
**下一步**: `/bmad:create-epics-and-stories` 创建 epics 和 stories
**相关文档**: prd.md
