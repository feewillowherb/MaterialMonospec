## 1. 宿主项目

- [x] 1.1 新建 `UrbanManagement.XiaoShanResource` Web 项目并加入解决方案，不引用 Admin、Hosting 或 Core
- [x] 1.2 加入 SSO `GetToken` 登录、Cookie `XiaoShanResource.Session`、`/login`、`/logout`、`/api/session` 和无需数据库的健康检查
- [x] 1.4 在本进程内提供车辆和合同 mock API。Vue 通过这些 API 获取和修改数据，不使用数据库、Core 或 AppService
- [x] 1.3 提交配置使用产品编码 5041，登录页标题为「萧山资源化利用网页端」

## 2. Vue 页面

- [x] 2.1 用 Vue 3 与 Element Plus 做外壳：紫色顶栏「渣土消纳一体化平台」、仅车辆管理和合同管理两个菜单、按打开状态显示页签
- [x] 2.2 实现车辆管理页面：从本站 API 取列表，筛选、分页、录入、编辑、删除、批量删除都走该 API；批量导入不读取文件
- [x] 2.3 实现合同管理页面和新建合同对话框：从本站 API 取列表并提交保存；校验、PDF 文件名、产品明细放在该 API 的 mock 中；批量上报不调用外部系统
- [x] 2.4 将 Vue 构建结果放到该 Web 项目的 `wwwroot`，未登录访问页面时进入登录页

## 3. 验证

- [x] 3.1 构建 Web 项目并确认输出不含 `UrbanManagement.Admin.dll`、`UrbanManagement.Hosting.dll`、`UrbanManagement.Core.dll`
- [x] 3.2 运行 `openspec validate add-xiaoshan-resource-web --strict`

## 4. 138 compose

- [x] 4.1 在 `deploy/docker/compose.yaml` 增加 `um-xiaoshanresource`：镜像 `urbanmanagement-xiaoshanresource`，宿主端口默认 5334，SSO 地址复用 `UM_ADMIN_SSO_BASE_URL`，产品编码固定 5041。不进入网关，不挂 UrbanManagement 数据库，不等待 `um-migrator`
