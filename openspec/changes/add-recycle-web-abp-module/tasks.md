## 1. 实施前核对（UrbanManagement）

- [ ] 1.1 确认 `add-recycle-business-persistence` 已在 `dev-recycle-resource-alignment`，并读取现有 `XiaoShanResource` 的 SSO、mock 路由和 Core 的 `IRecycleProjectContext`。
- [ ] 1.2 按 Mode B 从该基线创建 `add-recycle-web-abp-module` 分支；只改 UrbanManagement。不新建 Recycle 表，不改 MaterialClient。

## 2. 工程名改为 Recycle（UrbanManagement）

- [x] 2.1 将工程目录、csproj、程序集和根命名空间改为 `UrbanManagement.Recycle`，并更新解决方案入口。
- [x] 2.2 将会话 Cookie 改为 `Recycle.Session`，认证方案改为 `Recycle`，DataProtection 应用名改为 `UrbanManagement.Recycle`。中文产品名和 5041 保持不变。
- [x] 2.3 将 compose 服务改为 `um-recycle`、镜像改为 `urbanmanagement-recycle`，宿主机端口变量改为 `UM_RECYCLE_PUBLIC_PORT`，默认仍为 5334。
- [x] 2.4 更新子仓 `AGENTS.md` 里该站点的工程名。不重命名历史 change 目录 `add-xiaoshan-resource-web`。

## 3. ABP 宿主（UrbanManagement）

- [x] 3.1 新增 `UrbanManagementRecycleModule`，依赖共享宿主模块，使既有 Recycle AppService 可解析。
- [x] 3.2 保留 5041 SSO、登录页和登出。未登录的业务请求拒绝且不写行。`Testing` 环境仍跳过 SSO，供本机 FEV 调用业务接口。
- [x] 3.3 配置 `ConnectionStrings:Default` 与 `RecyclePersistence:BoundSourceProId`。请求体、查询和会话中的项目标识不得决定归属。
- [x] 3.4 不在该站点暴露 Urban 称重、通行、授权、客户端日志或 Recycle 设备状态的 conventional API。

## 4. 页面改接（UrbanManagement）

- [x] 4.1 用 AppService 适配器替换 `/api/vehicles`、`/api/contracts`、`/api/productions`、`/api/transports`，删除内存 mock。
- [ ] 4.2 Vue 改为 Guid 和精确公斤/吨。重量输入不得固定一位小数。车辆或公司后续修改不得回写已有单据快照。
- [x] 4.3 运输清单后补只接受同一 SourceProId 的合同和材料。没有外部平台响应时不得标为同步成功。

## 5. 验证（UrbanManagement）

- [ ] 5.1 验证工程名为 `UrbanManagement.Recycle`，旧 Cookie 不能登录，5041 登录后发出 `Recycle.Session`。
- [ ] 5.2 验证服务可解析、匿名拒绝、错误或缺失绑定失败关闭，以及请求体中的其他项目标识不改变归属。
- [ ] 5.3 在浏览器中验证四页的新增、查询和重启后仍在；核对 1234.5 kg 显示为 1.2345 t。
- [ ] 5.4 运行构建与 `openspec validate add-recycle-web-abp-module --strict`。未有目标环境证据不得声明 ICD 交付。合入、提交和推送另按授权执行。
