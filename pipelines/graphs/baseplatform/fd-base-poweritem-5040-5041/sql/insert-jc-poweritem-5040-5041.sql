-- Target: 129 / FD_Base / dbo.JC_PowerItem (+ update JC_Role.PowerCode)
-- Shape from 135 (ProductType=2 New web login menus):
--   5040: root「萧山城管管理平台」+ child「项目管理」/projects
--   5041: root「萧山资源化利用网页端」+ child「车辆管理」/vehicles
-- PowerCode protocol (same as 135):
--   root item  = '1'  + 2047 zeros
--   child item = '01' + 2046 zeros
--   role       = '11' + 2046 zeros  (bits 1+2)
-- Does NOT insert products / authorities / user-roles.
-- Expects JC_Product 5040/5041 and JC_Role for those ProductIds already present.
-- Run manually against 129. Not executed by cook.
--
-- IMPORTANT: Select and execute the ENTIRE script through COMMIT.

SET NOCOUNT ON;
SET XACT_ABORT ON;

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    SUSER_SNAME() AS LoginName;

IF DB_NAME() <> N'FD_Base'
BEGIN
    THROW 50000, N'Wrong database. Connect to FD_Base on 129 before running this script.', 1;
END;

BEGIN TRAN;

DECLARE @PowerLen int = 2048;
DECLARE @RootPower nvarchar(3000) = N'1' + REPLICATE(N'0', @PowerLen - 1);
DECLARE @ChildPower nvarchar(3000) = N'01' + REPLICATE(N'0', @PowerLen - 2);
DECLARE @RolePower nvarchar(3000) = N'11' + REPLICATE(N'0', @PowerLen - 2);

DECLARE @Root5040 int;
DECLARE @Child5040 int;
DECLARE @Root5041 int;
DECLARE @Child5041 int;

IF NOT EXISTS (SELECT 1 FROM dbo.JC_Product WHERE ProductCode = N'5040' AND ISNULL(DeleteStatus, 0) = 0)
    THROW 50001, N'Missing JC_Product 5040. Insert product first.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.JC_Product WHERE ProductCode = N'5041' AND ISNULL(DeleteStatus, 0) = 0)
    THROW 50002, N'Missing JC_Product 5041. Insert product first.', 1;

IF EXISTS (SELECT 1 FROM dbo.JC_PowerItem WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0)
    THROW 50003, N'Active JC_PowerItem already exists for 5040/5041. Abort to avoid duplicates.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.JC_PowerItem
    WHERE ItemCode IN (N'xiaoshanUrbanRoot', N'xiaoshanUrbanProjects', N'xiaoshanResourceRoot', N'xiaoshanResourceVehicles')
)
    THROW 50004, N'ItemCode clash (xiaoshanUrban*/xiaoshanResource*). Abort.', 1;

-- ========== 5040 root ==========
INSERT INTO dbo.JC_PowerItem (
    ParentId, ItemName, ItemCode, ItemPath, ItemType, InheritType, ItemValue,
    ProductId, ItemUrlLike, PowerCode, OrderId, ItemIcon1, ItemIcon2,
    IsSuper, OpenType, Remark, CreateUserId, LastEditUserId, LastEditor, Creator,
    DeleteStatus, AddTime, UpdateTime
)
VALUES (
    0, N'萧山城管管理平台', N'xiaoshanUrbanRoot', NULL, 1, NULL, N'',
    5040, N'', @RootPower, 1, NULL, NULL,
    NULL, NULL, N'from 135 shape 2026-11-24', 35, NULL, NULL, N'朱文锦',
    0, NULL, NULL
);
SET @Root5040 = SCOPE_IDENTITY();

UPDATE dbo.JC_PowerItem
SET ItemPath = N'0,' + CAST(@Root5040 AS nvarchar(20))
WHERE ItemId = @Root5040;

-- ========== 5040 child ==========
INSERT INTO dbo.JC_PowerItem (
    ParentId, ItemName, ItemCode, ItemPath, ItemType, InheritType, ItemValue,
    ProductId, ItemUrlLike, PowerCode, OrderId, ItemIcon1, ItemIcon2,
    IsSuper, OpenType, Remark, CreateUserId, LastEditUserId, LastEditor, Creator,
    DeleteStatus, AddTime, UpdateTime
)
VALUES (
    @Root5040, N'项目管理', N'xiaoshanUrbanProjects', NULL, 1, NULL, N'projects',
    5040, N'/projects', @ChildPower, 2, NULL, NULL,
    NULL, NULL, N'from 135 shape 2026-11-24', 35, NULL, NULL, N'朱文锦',
    0, NULL, NULL
);
SET @Child5040 = SCOPE_IDENTITY();

UPDATE dbo.JC_PowerItem
SET ItemPath = N'0,' + CAST(@Root5040 AS nvarchar(20)) + N',' + CAST(@Child5040 AS nvarchar(20))
WHERE ItemId = @Child5040;

-- ========== 5041 root ==========
INSERT INTO dbo.JC_PowerItem (
    ParentId, ItemName, ItemCode, ItemPath, ItemType, InheritType, ItemValue,
    ProductId, ItemUrlLike, PowerCode, OrderId, ItemIcon1, ItemIcon2,
    IsSuper, OpenType, Remark, CreateUserId, LastEditUserId, LastEditor, Creator,
    DeleteStatus, AddTime, UpdateTime
)
VALUES (
    0, N'萧山资源化利用网页端', N'xiaoshanResourceRoot', NULL, 1, NULL, N'',
    5041, N'', @RootPower, 1, NULL, NULL,
    NULL, NULL, N'from 135 shape 2026-11-24', 35, NULL, NULL, N'朱文锦',
    0, NULL, NULL
);
SET @Root5041 = SCOPE_IDENTITY();

UPDATE dbo.JC_PowerItem
SET ItemPath = N'0,' + CAST(@Root5041 AS nvarchar(20))
WHERE ItemId = @Root5041;

-- ========== 5041 child ==========
INSERT INTO dbo.JC_PowerItem (
    ParentId, ItemName, ItemCode, ItemPath, ItemType, InheritType, ItemValue,
    ProductId, ItemUrlLike, PowerCode, OrderId, ItemIcon1, ItemIcon2,
    IsSuper, OpenType, Remark, CreateUserId, LastEditUserId, LastEditor, Creator,
    DeleteStatus, AddTime, UpdateTime
)
VALUES (
    @Root5041, N'车辆管理', N'xiaoshanResourceVehicles', NULL, 1, NULL, N'vehicles',
    5041, N'/vehicles', @ChildPower, 2, NULL, NULL,
    NULL, NULL, N'from 135 shape 2026-11-24', 35, NULL, NULL, N'朱文锦',
    0, NULL, NULL
);
SET @Child5041 = SCOPE_IDENTITY();

UPDATE dbo.JC_PowerItem
SET ItemPath = N'0,' + CAST(@Root5041 AS nvarchar(20)) + N',' + CAST(@Child5041 AS nvarchar(20))
WHERE ItemId = @Child5041;

-- Role PowerCode must include bits 1+2 or GetToken still returns「无路由菜单权限」
UPDATE dbo.JC_Role
SET PowerCode = @RolePower,
    Remark = CASE
        WHEN Remark IS NULL OR Remark = N'' THEN N'PowerCode set from 135 shape 2026-11-24'
        ELSE Remark
    END
WHERE ProductId IN (5040, 5041)
  AND ISNULL(DeleteStatus, 0) = 0
  AND (PowerCode IS NULL OR LEN(LTRIM(RTRIM(PowerCode))) = 0 OR PowerCode NOT LIKE N'11%');

IF @@ROWCOUNT < 2
    THROW 50005, N'Expected to update PowerCode on both 5040 and 5041 roles. Check JC_Role rows.', 1;

-- Verify (expected: see expect/after-insert.md)
--   PowerItem: 5040→2, 5041→2; each RootCnt=1 Type1Cnt=2
--   Rows: xiaoshanUrbanRoot / xiaoshanUrbanProjects / xiaoshanResourceRoot / xiaoshanResourceVehicles
--   Power heads: root '1', child '01', len 2048
--   Role: each product ≥1; Power head '11', len 2048

SELECT ProductId, COUNT(*) AS Cnt,
       SUM(CASE WHEN ParentId = 0 THEN 1 ELSE 0 END) AS RootCnt,
       SUM(CASE WHEN ItemType = 1 THEN 1 ELSE 0 END) AS Type1Cnt
FROM dbo.JC_PowerItem
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
GROUP BY ProductId
ORDER BY ProductId;

SELECT ProductId, ItemId, ParentId, ItemName, ItemCode, ItemType, ItemUrlLike, ItemValue, ItemPath,
       LEFT(PowerCode, 4) AS PowerCodeHead, LEN(PowerCode) AS PowerCodeLen
FROM dbo.JC_PowerItem
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
ORDER BY ProductId, ItemId;

SELECT RoleId, ProductId, RoleName, LEFT(PowerCode, 4) AS PowerCodeHead, LEN(PowerCode) AS PowerCodeLen
FROM dbo.JC_Role
WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
ORDER BY ProductId, RoleId;

IF (
    SELECT COUNT(*) FROM dbo.JC_PowerItem
    WHERE ProductId = 5040 AND ISNULL(DeleteStatus, 0) = 0
) <> 2
    THROW 50006, N'Expect after-insert: JC_PowerItem 5040 active count <> 2.', 1;

IF (
    SELECT COUNT(*) FROM dbo.JC_PowerItem
    WHERE ProductId = 5041 AND ISNULL(DeleteStatus, 0) = 0
) <> 2
    THROW 50007, N'Expect after-insert: JC_PowerItem 5041 active count <> 2.', 1;

IF (
    SELECT COUNT(*) FROM dbo.JC_Role
    WHERE ProductId IN (5040, 5041) AND ISNULL(DeleteStatus, 0) = 0
      AND LEFT(PowerCode, 2) = N'11' AND LEN(PowerCode) = 2048
) < 2
    THROW 50008, N'Expect after-insert: both product roles need PowerCode 11… len 2048.', 1;

COMMIT;
-- ROLLBACK;
