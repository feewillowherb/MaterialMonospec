# fev-sqlite-write-contention-repro

## 目的 / Goal

`materialclient-sqlite-write-contention-fev`

Status: **active** · Runtime: **experimental .NET 10**

验证同一 SolidWaste 工作库被另一个 SQLite 写事务短暂占用时，称重诊断 API 是否能触发并采集 `CreateForCycleAsync` 的 `SQLite Error 5: 'database is locked'`。这是一项合成竞争实验，不代表已确认现场锁持有者。

FEV 文档：[`docs/2026-11-24-materialclient-sqlite-write-contention-fev/00-FEV-SQLite写入冲突.md`](../../../../docs/2026-11-24-materialclient-sqlite-write-contention-fev/00-FEV-SQLite写入冲突.md)。

## 边界与安全

- Graph 只通过 `GET /`、`POST /api/lpr/test-plate`、`POST /api/scale/weight` 与应用交互，不操作客户端 UI。
- 若启动客户端时出现授权码或登录窗口，暂停自动步骤，等待用户输入并完成登录；不得代填凭据。
- 原始 seed 数据库只读；实验只操作每次新建的 `runs/<runId>/working/MaterialClient.db` 副本。禁止覆盖旧 run。
- 不停止已有客户端进程、不写设置、不连接真实地磅或车辆；API 注入仅允许在用户确认测试环境与 `ScaleType.TestMode` 后进行。
- 无产品项目引用，不改产品代码。Run 需记录 git revision 和相对路径，不写秘密或绝对路径进 manifest。

## 流程

1. 生成唯一 Run 目录，将当前 SolidWaste seed 用 SQLite backup 复制为工作库。
2. 设置 `ConnectionStrings__Default` 指向工作库，并用 `scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -NoBuild -EnableDiagnosticHost` 启动客户端。只启动新进程，不传 `-StopRunning`。若该构建产物不匹配当前源码，应先由用户准备对应构建。
3. 轮询 `GET /`。登录、授权或有人值守服务未就绪时暂停等待用户，不做 UI 操作。
4. 检查 `WeighingRecords` 基线；调用 `/api/scale/weight` 注入离磅重量，等待判稳窗口。
5. 同一工作库上通过 `Microsoft.Data.Sqlite` 打开 `BEGIN IMMEDIATE` 写事务并保持短暂时间；事务持有期间通过 `/api/lpr/test-plate` 注入唯一测试牌号，再用 `/api/scale/weight` 注入稳定重量。
6. 采集 HTTP 响应、锁持有状态、记录数前后对比与匹配日志。锁事务到期或实验结束后及时释放。

## 判别

| 结果 | FEV 含义 |
|---|---|
| `pass` | API 注入成功，日志观测到 `CreateForCycleAsync` 建单错误与 `SQLite Error 5`，且该牌号未落库：外部竞争锁能合成复现近因。 |
| `fail` | 所有前置满足、确实持有锁且稳定建单操作发生，但观察窗口内没有目标锁错误：此合成路径未复现。 |
| `blocked` | API / 称重服务未就绪、非 TestMode、seed 不兼容、客户端未登录，或无法证实锁成功注入。 |

该实验不能证明现场由外部进程持锁，不能定位应用内部竞争写路径，也不能证明任何修复方案有效。FEV Verdict `FEASIBLE` 仅指合成近因可复现；P3 仅由用户判定。

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-sqlite-write-contention-repro/scripts/Invoke-FevSqliteWriteContentionRepro.ps1
```

Cook 使用 `dotnet run --project .../src/FevSqliteWriteContention.csproj`（experimental）。默认 seed 为 `.build-verify/MaterialClient.SolidWaste/MaterialClient.db`，可传 `-SeedDatabase` 覆盖。Cook 不启动或点击 UI；客户端准备步骤由 Graph 明确列出。运行前会要求人工确认测试环境。

## Evidence

每次运行写入新目录：`runs/<yyyy-MM-ddTHHmmss>/`。包括 `summary.json`、`report.md`、`manifest.yaml`、`http.json`、`lock.json`、数据库前后快照、日志摘录和仅供本次客户端使用的工作库。工作库不得复制回 seed。

## Acceptance

P0：诊断 API 可达；P1：测试车牌与重量注入成功且竞争事务确认持锁；P2：保存失败日志与数据库结果采集完成；P3：用户评审是否接受该实验作为 FEV 证据。Agent 不得判定 P3。
