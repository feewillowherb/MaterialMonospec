## 1. 数据目录

- [x] 1.1 增加 `Client:DataDirectory` 解析：绝对路径存在时作为数据根，为空时使用 exe 目录，目录不存在时启动失败且不在 exe 目录创建数据库
- [x] 1.2 让数据库连接字符串和附件相对路径都使用这个数据根
- [x] 1.3 为路径解析补测试：旧目录中的相对数据库和附件路径不落到新 exe 目录

## 2. 固废宿主

- [x] 2.1 新增 `MaterialClient.SolidWaste` WinExe，引用 Common、内核 EF、SolidWaste、UI 和 AttendedWeighing
- [x] 2.2 固废宿主只依赖 SolidWaste 模块，启动时迁移内核和 `SolidWasteDbContext` 并回填缺失扩展行
- [x] 2.3 固废宿主固定固废模式和产品码，使用独立单实例互斥名

## 3. 标准宿主

- [x] 3.1 去掉标准宿主对 SolidWaste 项目和模块的引用
- [x] 3.2 标准宿主只迁移内核和 `StandardDbContext`
- [x] 3.3 授权窗口只显示当前宿主传入的模式；已保存模式属于另一产品时退出且不改设置、不删授权

## 4. 安装与验证

- [x] 4.1 新增固废安装脚本，使用独立 AppId，卸载不删除数据库和附件
- [x] 4.2 标准安装脚本在自启动目标已是固废 exe 时不改写
- [x] 4.3 用一份已有固废库验证固废宿主能打开原库，标准宿主对同一数据目录退出且不改模式

## 5. Review decision implementation and evidence

- [x] 5.1 Fix the supported 495aa3e3 schema/migration manifest; prepare Standard and SolidWaste baseline fixtures and reject unsupported schemas without writes.
- [x] 5.2 Compose legacy and host configuration in the documented order; test endpoint/connection preservation, host identity enforcement, and absence of secrets in logs.
- [x] 5.3 Distinguish fresh install from upgrade in both installers and runtime; reject missing database files, corrupt schemas and mismatched/missing product identity before creating settings or applying migrations.
- [x] 5.4 Enforce preflight-before-write startup ordering across ABP initialization, migration, registry synchronization, background workers and device startup; verify rejection leaves database/configuration/license/entry points unchanged.
- [x] 5.5 Add normalized database-path exclusion and legacy-process shutdown checks; verify duplicate and cross-host startup rejection.
- [x] 5.6 Use product-owned auto-start keys in runtime and installers; transfer only matching legacy SolidWaste entries/shortcuts, preserve enabled state and test idempotency and unrelated-install protection.
- [x] 5.7 Reject Standard installer overwrite of an existing SolidWaste deployment before replacing binaries; verify uninstall ownership and data retention.
- [x] 5.8 Implement and verify consistent pre-upgrade backups, recovery manifests and failure recovery; preserve post-upgrade writes rather than silently restoring a stale snapshot.
- [ ] 5.9 Run the fresh-install and baseline-upgrade matrix for both products on Windows, including legacy configuration, authorization, attachments, historical reads and new writes.
- [ ] 5.10 Exercise interruption/retry, unsupported or missing database, wrong product, process occupation and entry-point handoff failures; verify full recovery using the matching old package.
- [x] 5.11 Run host composition/migration checks and affected Urban/Recycle regressions; record commands, environments, fixtures and evidence, leaving unavailable device/field checks explicitly unverified.
