# 插入后预期结果（129 / FD_Base）

人工执行 `sql/insert-jc-poweritem-5040-5041.sql` 并 `COMMIT` 后，下列断言应全部成立。  
`ItemId` / `RoleId` 为自增或既有值，**不锁定具体数字**；核对逻辑键与形状。

## 1. `JC_PowerItem`（未删）

| ProductId | 条数 | 根 (ParentId=0) | 子 | ItemType | PowerCode 头 | PowerCodeLen |
|-----------|------|-----------------|----|----------|--------------|--------------|
| 5040 | **2** | 1 | 1 | 均为 **1** | 根 `1…` / 子 `01…` | **2048** |
| 5041 | **2** | 1 | 1 | 均为 **1** | 根 `1…` / 子 `01…` | **2048** |

行级形状：

| ProductId | ItemName | ItemCode | Parent | ItemUrlLike | ItemValue | ItemPath 形 |
|-----------|----------|----------|--------|-------------|-----------|-------------|
| 5040 | 萧山城管管理平台 | `xiaoshanUrbanRoot` | 0 | `''` | `''` | `0,{rootId}` |
| 5040 | 项目管理 | `xiaoshanUrbanProjects` | = 上行之 ItemId | `/projects` | `projects` | `0,{rootId},{childId}` |
| 5041 | 萧山资源化利用网页端 | `xiaoshanResourceRoot` | 0 | `''` | `''` | `0,{rootId}` |
| 5041 | 车辆管理 | `xiaoshanResourceVehicles` | = 上行之 ItemId | `/vehicles` | `vehicles` | `0,{rootId},{childId}` |

其它：`DeleteStatus=0`；`OrderId` 根=1、子=2。

## 2. `JC_Role`（未删，ProductId ∈ {5040,5041}）

| ProductId | 未删角色数 | PowerCode 头 | PowerCodeLen |
|-----------|------------|--------------|--------------|
| 5040 | ≥1（129 既有 RoleId **106**） | `11…` | **2048** |
| 5041 | ≥1（129 既有 RoleId **107**） | `11…` | **2048** |

说明：脚本只 **UPDATE** 空/`NULL`/非 `11%` 的角色 PowerCode；不新建角色、不改 UserRole。

## 3. 验收查询（应与脚本末尾 SELECT 一致）

```sql
-- PowerItem：每产品 2 行；根/子 PowerCode 头分别为 1 / 01；Len=2048
SELECT ProductId, COUNT(*) AS Cnt,
       SUM(CASE WHEN ParentId = 0 THEN 1 ELSE 0 END) AS RootCnt,
       SUM(CASE WHEN ItemType = 1 THEN 1 ELSE 0 END) AS Type1Cnt
FROM dbo.JC_PowerItem
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
GROUP BY ProductId
ORDER BY ProductId;
-- 期望：5040 → Cnt=2 RootCnt=1 Type1Cnt=2
-- 期望：5041 → Cnt=2 RootCnt=1 Type1Cnt=2

SELECT ProductId, ItemName, ItemCode, ParentId, ItemUrlLike, ItemValue,
       LEFT(PowerCode, 2) AS PowerHead, LEN(PowerCode) AS PowerLen, ItemPath
FROM dbo.JC_PowerItem
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
ORDER BY ProductId, ParentId, OrderId, ItemId;

SELECT RoleId, ProductId, RoleName,
       LEFT(PowerCode, 2) AS PowerHead, LEN(PowerCode) AS PowerLen
FROM dbo.JC_Role
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
ORDER BY ProductId, RoleId;
-- 期望：每产品至少 1 行；PowerHead='11'；PowerLen=2048
```

## 4. 与登录探测的关系

满足上表后，`sso-findong-5040-5041-login` 在**已赋 UserRole + 产品授权**的前提下，不应再因「该用户无路由菜单权限」失败。  
本 expect **不**断言 GetToken `code=200`（属登录 Graph / P3）。
