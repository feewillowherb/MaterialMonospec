## 1. 分支

- [x] 1.1 `repos/UrbanManagement` 自 `update-urban-mssql-provider` 切出 `add-urban-docker-deployment`

## 2. 应用改动（UrbanManagement）

- [x] 2.1 `StorageOptions.TusTempPath`（默认 `Uploads/_tus`）；`IStoragePathResolver.GetTusTempRootAbsolute()`；`TusAttachmentUploadConfigurationProvider` 改用解析结果
- [x] 2.2 单元测试：默认路径、相对路径、绝对路径
- [x] 2.3 `ReadinessHealthCheck`（数据库 `SELECT 1` + 附件根目录存在）；映射 `/health/live`、`/health/ready`（在 Blazor 兜底路由之前）
- [x] 2.4 `DataProtection:KeysPath` 配置时持久化密钥环
- [x] 2.5 `dotnet build` 与全部测试通过；本机 LocalDB 启动后 `/health/live`、`/health/ready` 返回 200

## 3. 容器定义（UrbanManagement `deploy/docker/`）

- [x] 3.1 `Dockerfile`（aspnet:10.0、发布产物、导入工具、预建目录归属 1654、`USER 1654`、`8080`）
- [x] 3.2 `compose.yaml`（`mssql` / `redis` / `um-app`，Phase 1，验收默认关闭同步，`mem_limit`）
- [x] 3.3 `.env.example`（只列变量名）

## 4. 部署 Graph（主仓 `pipelines/graphs/ops/deploy-urban-acceptance/`）

- [x] 4.1 Graph 工件：`config.yaml`、`contract.yaml`、`pipeline.md`、`acceptance.md`、`secrets.example.yaml`、cook 脚本、远端脚本；索引写入 `pipelines/graphs/ops/AGENTS.md`
- [x] 4.2 cook：本机发布打包 → 上传 → fstab 挂载 → 生成配置与 `.env` → 构建镜像 → 启动 `mssql`/`redis` → 建库与 `um_app` → 导入测试源 → 启动 `um-app` → 虚拟机内验证
- [x] 4.3 执行 Graph；Run identity 与结果回写蓝图 `05`（§1.7：deploy `2026-11-03T103715`、verify `2026-11-03T104337`）

## 5. 验收

- [x] 5.1 宿主 `5333` portproxy 与防火墙（人执行，命令见 `pipeline.md`）
- [x] 5.2 外部访问 `http://191.12.234.212:5333/health/ready` 返回 200，接口探测通过（verify run `2026-11-03T105420`，result `pass`）
- [x] 5.3 ~~客户端提交测试数据（激活、称重上报、附件上传）在新栈落库，附件写入共享目录~~ 用户决定不验证（2026-11-03）；无客户端落库证据

## 6. 收尾

- [x] 6.1 `openspec validate add-urban-docker-deployment --strict`
- [x] 6.2 子仓提交到 `add-urban-docker-deployment` 分支（本地 `c2a5a70`，未推送；合入 `main` 按用户指示，在 `update-urban-mssql-provider` 之后 squash）
