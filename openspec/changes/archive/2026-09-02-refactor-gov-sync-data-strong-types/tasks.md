## 1. Branch & entity

- [x] 1.1 UrbanManagement 切到 Mode B：自 `dev-urban-entity-semantic` 建 change 同名分支
- [x] 1.2 `GovSyncData`：`SnapTime` → `DateTime?`；`GoodsWeight` → `decimal?`
- [x] 1.3 `UrbanManagementDbContext`：移除这两列的 `HasMaxLength` 字符串配置

## 2. EF migration

- [x] 2.1 新增 migration：best-effort SQL/parse（常见时间格式、decimal）→ 无法解析置 NULL → AlterColumn 到目标类型
- [x] 2.2 本地 apply；抽检：可解析行有值，脏数据为 NULL；列名未改

## 3. DTO & consumers

- [x] 3.1 `GovSyncDataDto` 类型与 `FromEntity` 同步
- [x] 3.2 搜索 Blazor / 样例 / 测试中对这两字段的 string 假设并修正
- [x] 3.3 确认 `GovSyncWeightPayload` / `GovRequestWeightDto` 等 outbound/inbound wire **未改**

## 4. Tests & verify

- [x] 4.1 单测：`FromEntity` 映射；可选 parse helper 若抽到类型归属方法则测之
- [x] 4.2 编译并跑相关测试通过
- [x] 4.3 squash → `dev-urban-entity-semantic`（用户确认后）
- [x] 4.4 Archive（用户确认后；默认 sync delta → `openspec/specs/`）
