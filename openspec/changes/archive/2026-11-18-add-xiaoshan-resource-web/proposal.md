## Why

萧山资源化利用需要一个独立于城管管理端的网页。当前只要按参考图还原车辆管理、合同管理和新建合同对话框。页面上的车辆和合同是 mock，由本站 API 提供，不落库。登录使用 FdSoft.SSO。产品编码是 5041，产品名称是「萧山资源化利用网页端」。

## What Changes

- 在 UrbanManagement 仓库新增 Web 项目 `UrbanManagement.XiaoShanResource`。它单独监听端口，不进入现有网关兜底路由，也不引用 `UrbanManagement.Admin`、`UrbanManagement.Hosting` 或 `UrbanManagement.Core`。
- 登录页由该项目的 ASP.NET 渲染。浏览器只把账号和密码交给本站；服务端 `POST /GetToken`，`switchType=0`、`productType=2`、`toProductIds` 只含配置的 5041。只有业务码 200 且返回产品为 5041 时，才写入 Cookie `XiaoShanResource.Session`。
- 登录后的车辆管理、合同管理和新建合同对话框用 Vue 3 + Element Plus 实现。Vue 从本站 API 获取车辆和合同 mock，筛选、分页、录入、编辑、删除和保存也走这组 API。数据只留在 `UrbanManagement.XiaoShanResource` 进程内存里，进程重启后回到种子。不建表、不写 migration、不调用城管管理端或 Core 的业务 API，也不保存 PDF。
- 侧栏只有「车辆管理」和「合同管理」。页签只在对应页面打开后出现。不实现仪表盘、消纳场地、生产管理、运输清单、系统管理。
- 退出只删除 `XiaoShanResource.Session`。不调用 SSO `logout`。
- 不修改城管管理端、网关路由、MaterialClient 或 FdSoft.SSO。FD_Base 的 5041 产品行由单独的 SSO 实验写入，不属于本站表结构。

## Capabilities

### New Capabilities

- `xiaoshan-resource-web`: 萧山资源化利用网页端以产品 5041 登录，并用 Vue 3 + Element Plus 展示三块 mock 画面

### Modified Capabilities

- `urban-role-hosting`: 服务项目清单增加 `UrbanManagement.XiaoShanResource`。该项目不承载 Blazor，也不依赖 UrbanManagement 数据库
- `urban-container-deployment`: 同一套 compose 增加 `um-xiaoshanresource`。它使用自己的镜像和宿主端口，不进入 `um-gateway`，也不挂 UrbanManagement 数据库

## Impact

- **子仓库**：`repos/UrbanManagement`。新增 `src/UrbanManagement.XiaoShanResource` 及其 Vue 前端，并加入解决方案。
- **分支**：Mode A — `add-xiaoshan-resource-web`
- **输入**：[`docs/2026-11-13-xiaoshan-resource-utilization/`](../../../docs/2026-11-13-xiaoshan-resource-utilization/00-调研总览.md)
- **一起发布**：`deploy/docker/compose.yaml` 增加 `um-xiaoshanresource`，镜像 `urbanmanagement-xiaoshanresource`，宿主端口默认 5334。SSO 地址复用 `UM_ADMIN_SSO_BASE_URL`，产品编码在 compose 里固定为 5041。
- **不动**：`um-gateway` 路由、城管管理端 Cookie `UrbanAdmin.Session` 与产品 5040、现有服务的端口和数据库依赖
