# UrbanManagement 文档

本目录存放 [UrbanManagement](../../repos/UrbanManagement)（城市管理 Web 应用）的运维与发布文档。

## 文档索引

| 文档 | 说明 |
|------|------|
| [windows-server-deploy.md](./windows-server-deploy.md) | Windows Server 发布与部署流程手册 |
| [appsettings.secret.json.example](./appsettings.secret.json.example) | 生产环境敏感配置模板（复制后按需修改，勿提交密钥） |

## 发布脚本

子仓库提供 PowerShell 发布脚本，推荐用于本地或 CI 构建：

| 路径 | 说明 |
|------|------|
| `repos/UrbanManagement/scripts/publish.ps1` | 执行 `dotnet publish`、校验产物、可选打 zip |

```powershell
# 在 repos/UrbanManagement 目录下
.\scripts\publish.ps1

# 自包含 + 打 zip
.\scripts\publish.ps1 -SelfContained -Zip
```

参数与完整用法见 [windows-server-deploy.md §3.1](./windows-server-deploy.md#31-使用发布脚本推荐)。

## 调研（上云 / 萧山分流）

客户端卡口/成品进出与服务端三通道上报的对照，见日期夹（非本目录运维手册）：

- [`docs/2026-08-28-urbanmanagement-passage-xiaoshan-upload/`](../2026-08-28-urbanmanagement-passage-xiaoshan-upload/00-调研总览.md)

## 相关资源

- 子仓库代码：`repos/UrbanManagement/`
- 子仓库编码规范：`repos/UrbanManagement/AGENTS.md`
- 附件存储说明：见 `AGENTS.md` → Attachment storage
