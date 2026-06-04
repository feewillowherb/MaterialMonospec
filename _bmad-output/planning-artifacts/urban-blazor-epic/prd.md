# PRD：UrbanManagement ABP Blazor 迁移

**Epic ID**: `urban-blazor-epic`
**版本**: 1.0
**状态**: Draft
**创建日期**: 2026-06-04
**影响范围**: UrbanManagement Web 应用

---

## 1. 产品概述

### 1.1 产品名称
UrbanManagement ABP Blazor 迁移项目

### 1.2 一句话描述
将 UrbanManagement Web 应用从 ASP.NET Core MVC + jQuery 迁移到 ABP Framework 10 + Blazor Server + LeptonX Lite，实现前后端不分离的纯 C# 技术栈，完全支持 AI 工程化开发。

### 1.3 产品背景
UrbanManagement 当前采用传统的 ASP.NET Core MVC 架构，已基于 ABP Framework 构建，但前端仍使用 MVC + jQuery + Bootstrap 5 + LayUI，存在前后端语言分裂、ABP 资源利用不足、技术债务累积等问题。

---

## 2. 目标与成功指标

### 2.1 主要目标
1. **技术栈统一**: 实现前后端不分离，统一为 C# 技术栈
2. **AI 工程化**: 最大化 AI 辅助开发效率，目标提升 ≥50%
3. **ABP 基础设施利用**: 充分利用现有 ABP Framework 10 能力
4. **现代化 UI**: 采用 LeptonX Lite 主题，提供现代化用户体验
5. **渐进式迁移**: 保持系统稳定性，分阶段实施

### 2.2 成功指标
| 指标类别 | 具体指标 | 目标值 | 测量方法 |
|---------|---------|--------|----------|
| **技术指标** | C# 全栈覆盖率 | 100% | 代码统计 |
| | jQuery 依赖 | 0 | 依赖检查 |
| | ABP 动态代理覆盖率 | >95% | 代码分析 |
| | 页面响应时间 | <2s | 性能测试 |
| **ABP 利用率** | 模块化 UI 系统使用 | 100% | 功能检查 |
| | ABP 服务集成度 | 95%+ | 代码分析 |
| **开发效率** | 新功能开发时间减少 | ≥50% | 时间统计 |
| | AI 辅助代码生成准确率 | >90% | 质量评估 |
| | 文件数量减少 | 60% | 代码统计 |
| | 代码行数减少 | 50% | 代码统计 |

---

## 3. 用户画像与场景

### 3.1 目标用户
| 角色 | 场景 | 痛点 |
|------|------|------|
| **开发团队** | 需要维护和扩展 UrbanManagement | 前后端语言分裂，上下文切换成本高 |
| **AI 辅助开发** | 使用 Claude 等工具辅助开发 | jQuery 代码生成质量低，重构困难 |
| **运维团队** | 需要部署和维护系统 | LayUI 停滞维护，存在安全风险 |

### 3.2 核心用户故事

#### Epic 1: ABP Blazor 基础设施 (Core Tier)
**作为** 开发团队
**我想要** 搭建 ABP Blazor 基础设施
**以便** 为后续迁移提供稳定的技术基础

**验收标准:**
- [ ] ABP Blazor Server 运行正常
- [ ] LeptonX Lite 主题渲染成功
- [ ] SignalR 连接稳定
- [ ] MVC 和 Blazor 路由共存
- [ ] 可以回退到纯 MVC

#### Epic 2: 假设验证 (Assumption-Validation Tier)
**作为** 产品负责人
**我想要** 验证技术迁移的关键假设
**以便** 确保迁移方案的可行性

**验收标准:**
- [ ] ABP Blazor 性能测试通过（< 2s 首屏）
- [ ] SignalR 稳定性测试通过（重连 < 3s）
- [ ] LeptonX 主题满足业务需求
- [ ] AI 辅助效率提升 ≥ 50%
- [ ] 团队 C# 技能充分验证

#### Epic 3: 完整迁移 (Full Tier)
**作为** 开发团队
**我想要** 完成所有核心模块的 Blazor 迁移
**以便** 提供完整的现代化管理系统

**验收标准:**
- [ ] 项目管理模块完整迁移
- [ ] 客户管理模块完整迁移
- [ ] 城市称重记录模块完整迁移
- [ ] 主页仪表板完整迁移
- [ ] 所有核心功能正常工作

#### Epic 4: 质量加固 (Quality-Delivery Tier)
**作为** 运维团队
**我想要** 完成生产环境准备
**以便** 系统可以安全上线

**验收标准:**
- [ ] 旧依赖完全清理
- [ ] 性能基准达标
- [ ] 回归测试通过率 100%
- [ ] 回滚演练成功
- [ ] 运维文档完整

---

## 4. 功能需求

### 4.1 核心功能需求

#### FR-1: ABP Blazor 基础设施
- **FR-1.1** 安装 ABP Blazor NuGet 包
  - `Volo.Abp.AspNetCore.Components.Web`
  - `Volo.Abp.AspNetCore.Components.Server`
  - `Volo.Abp.AspNetCore.Components.Web.LeptonXLiteTheme`
- **FR-1.2** 配置 LeptonX Lite 主题
  - 主题样式加载
  - 布局组件配置
  - 响应式设计
- **FR-1.3** 创建 Blazor 组件结构
  - Components/ 目录结构
  - 共享组件库
  - 页面组件
- **FR-1.4** 建立 MVC 和 Blazor 路由共存机制
  - 路由配置
  - 中间件顺序
  - 回退开关
- **FR-1.5** 配置 SignalR 连接
  - SignalR Hub 配置
  - 自动重连机制
  - 连接状态监控

#### FR-2: 核心模块迁移
- **FR-2.1** 项目管理模块迁移
  - 项目列表页面
  - 项目创建/编辑表单
  - 项目详情查看
  - 数据表格和分页
- **FR-2.2** 客户管理模块迁移
  - 客户列表页面
  - 客户信息管理
  - 搜索和筛选
- **FR-2.3** 城市称重记录模块迁移
  - 称重记录列表
  - 记录详情查看
  - 数据上传功能
  - 审批流程
- **FR-2.4** 主页仪表板迁移
  - 统计卡片
  - 数据图表
  - 快捷操作

#### FR-3: ABP 服务集成
- **FR-3.1** 权限系统集成
  - 权限检查UI
  - 权限控制组件
  - 用户权限管理
- **FR-3.2** 设置系统集成
  - 设置读取UI
  - 设置配置界面
  - 多租户支持
- **FR-3.3** 事件总线集成
  - 本地事件订阅
  - 事件处理
  - 状态同步
- **FR-3.4** 动态代理集成
  - 应用服务注入
  - 自动HTTP处理
  - 异常处理

#### FR-4: 质量保证
- **FR-4.1** 性能优化
  - 组件渲染优化
  - SignalR 连接优化
  - 内存管理
- **FR-4.2** 回归测试
  - 功能测试套件
  - UI测试
  - 集成测试
- **FR-4.3** 回滚机制
  - 配置开关
  - 数据库迁移回滚
  - 紧急恢复流程
- **FR-4.4** 监控配置
  - 性能监控
  - 错误日志
  - 用户行为分析

### 4.2 非功能需求

#### 性能需求
| 指标 | 目标值 | 测量方法 |
|------|--------|----------|
| 页面加载时间 | < 2s | Performance API |
| SignalR 重连时间 | < 3s | 网络波动测试 |
| 并发用户支持 | ≥ 50 | 负载测试 |
| 内存占用 | < 500MB | 性能监控 |

#### 安全需求
- 保持现有 ABP 安全机制
- SignalR 连接使用 JWT 认证
- 权限控制沿用 ABP 权限系统
- 防止 XSS 和 CSRF 攻击

#### 可维护性需求
- 代码行数减少 50%
- 文件数量减少 60%
- 单元测试覆盖 > 80%
- 代码复杂度降低

---

## 5. 技术约束与依赖

### 5.1 技术约束

#### 必须使用
- ABP Framework 10.x
- Blazor Server (非 WebAssembly)
- LeptonX Lite 主题（免费版本）
- PostgreSQL 数据库
- .NET 8.0+

#### 必须移除
- jQuery 依赖
- LayUI 依赖
- Bootstrap 5（由 LeptonX 替代）

#### 保持不变
- Application 层接口
- Core 层实体和领域逻辑
- 数据库结构
- 现有 API 接口

### 5.2 依赖关系

#### 内部依赖
- 依赖现有 UrbanManagement ABP 架构
- 依赖现有数据库结构
- 依赖现有 Application Services
- 依赖现有权限系统

#### 外部依赖
- ABP Framework 10.x 稳定版本
- LeptonX Lite 主题包
- Blazorise 组件库
- SignalR JavaScript 客户端

---

## 6. 风险与假设

### 6.1 关键假设
| ID | 假设描述 | L-level | Risk Score | 验证方法 |
|----|---------|---------|------------|----------|
| A-01 | ABP Blazor Server 性能满足内网管理系统需求 | L2 | 15 | 负载测试 |
| A-02 | SignalR 连接在局域网环境下稳定 | L2 | 12 | 网络波动测试 |
| A-03 | LeptonX Lite 主题满足城市管理业务需求 | L1 | 8 | 用户试用反馈 |
| A-04 | AI 辅助开发效率提升 ≥ 50% | L2 | 20 | 开发时间统计 |
| A-05 | 团队 C# 技能足以支持 Blazor 开发（AI 辅助） | L2 | 10 | 实际开发验证 |

**Guess Ratio**: 50% (5/10) → 需要 Assumption-Validation tier

### 6.2 风险评估

| 风险项 | 影响 | 概率 | 缓解措施 |
|--------|------|------|----------|
| **SignalR 连接问题** | 高 | 中 | ABP 自动重连 + 降级方案 |
| **ABP 版本兼容性** | 中 | 低 | 使用 ABP 10.x 最新稳定版 |
| **LeptonX 学习曲线** | 低 | 低 | ABP 官方文档完善，AI 辅助 |
| **现有数据迁移** | 低 | 低 | Application 层不变，只迁移 UI |
| **性能影响** | 中 | 中 | ABP 内置优化，可配置 |

### 6.3 回退策略
```
ABP 架构的优势：可以随时回退

1. MVC 和 Blazor 可共存
   - 路由级别隔离
   - 独立部署

2. 每个模块独立迁移
   - 项目管理迁移后可独立回退
   - 其他模块不受影响

3. 最终回退方案
   - 禁用 Blazor 路由
   - 恢复 MVC 作为主路由
   - Application 层无需修改
```

---

## 7. 实施计划

### 7.1 迁移阶段

#### Phase 1: ABP Blazor 基础设施 (3-5 天)
```
目标：搭建 ABP Blazor 基础设施
├─ Day 1-2: 安装 ABP Blazor NuGet 包，配置 LeptonX Lite 主题
├─ Day 3-4: 创建基础组件结构，配置路由和导航
└─ Day 5: SignalR 连接测试，ABP 服务集成验证
```

#### Phase 2: 新功能 Blazor 优先 (5-7 天)
```
目标：新功能优先使用 Blazor 开发
├─ Day 1-3: 称重记录审批模块（Blazor 实现）
├─ Day 4-5: 客户附件上传功能（Blazor 实现）
└─ Day 6-7: 数据同步状态监控（Blazor 实现）
```

#### Phase 3: 核心模块迁移 (7-10 天)
```
目标：完成核心模块的 Blazor 迁移
├─ Week 3: 项目管理模块迁移
└─ Week 4: 客户管理 + 主页迁移
```

#### Phase 4: 收尾和优化 (3-5 天)
```
目标：清理和优化
├─ Day 1-2: 移除 jQuery/LayUI 依赖
├─ Day 3-4: 性能优化
├─ Day 5: 文档更新
└─ Day 6-7: 部署准备
```

### 7.2 检查点

#### Phase 1 检查点
- [ ] LeptonX 主题正常渲染
- [ ] ABP 动态代理工作正常
- [ ] SignalR 连接稳定
- [ ] ABP 服务注入成功

#### Phase 2 检查点
- [ ] 新功能完全使用 Blazor
- [ ] ABP 权限集成正常
- [ ] 无第三方组件依赖（除 ABP）

#### Phase 3 检查点
- [ ] 核心模块迁移完成
- [ ] ABP 事件总线集成
- [ ] 性能无明显下降

#### Phase 4 检查点
- [ ] 旧依赖清理完成
- [ ] ABP 基础设施充分利用
- [ ] 文档完整

---

## 8. 开放问题

| ID | 问题描述 | 优先级 | 预计解决时间 |
|----|---------|--------|-------------|
| OQ-1 | SignalR 连接池配置优化 | 中 | Phase 1 |
| OQ-2 | 大数据表格性能优化 | 高 | Phase 3 |
| OQ-3 | 现有 jQuery 插件替代方案 | 中 | Phase 4 |
| OQ-4 | 移动端响应式支持 | 低 | Phase 4 |

---

## 9. 附件

### 9.1 参考文档
- [ABP Blazor UI 官方文档](https://docs.abp.io/en/abp/latest/UI/Blazor/Overall)
- [LeptonX Lite 文档](https://docs.abp.io/en/abp/latest/UI/Themes/LeptonX-Lite)
- 原始技术分析：`docs/urban-blazor-epic.md`

### 9.2 技术架构
详见原始文档第 2 节 "ABP Blazor UI 技术方案"

### 9.3 AI 工程化分析
详见原始文档第 3 节 "AI 工程化深度分析"

---

## 10. 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|----------|------|
| 1.0 | 2026-06-04 | 初始版本，基于 urban-blazor-epic.md 转换 | BMAD Workflow |

---

**文档状态**: Draft - 待审核
**下一步**: `/bmad:create-architecture` 创建架构文档
