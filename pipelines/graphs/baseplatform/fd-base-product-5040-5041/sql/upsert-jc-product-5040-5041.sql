-- Target: 129 / FD_Base / dbo.JC_Product
-- Graph: pipelines/graphs/baseplatform/fd-base-product-5040-5041
-- Shape taken from a prior 5020 row snapshot (not read at runtime):
--   OrganizeType=2, ProductType=2 (网页 New), Status=1, CoId=1, ExtInt=0
--   Url/CallBackUrl=https://cloud.findong.com
--   Create/Update user = 35 / 朱文锦
-- Does NOT write menus / roles / authorities.
-- Does NOT require ProductCode 5020 to exist.
-- Run manually against 129. This file is not executed by the Graph cook.
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

DECLARE @OrganizeType int = 2;
DECLARE @ProductType int = 2;
DECLARE @Status int = 1;
DECLARE @CoId int = 1;
DECLARE @ExtInt int = 0;
DECLARE @Url nvarchar(512) = N'https://cloud.findong.com';
DECLARE @CallBackUrl nvarchar(512) = N'https://cloud.findong.com';
DECLARE @Remark nvarchar(512) = N'';
DECLARE @CreateUserId int = 35;
DECLARE @CreateUser nvarchar(64) = N'朱文锦';
DECLARE @UpdateUserId int = 35;
DECLARE @UpdateUser nvarchar(64) = N'朱文锦';
DECLARE @DbConn nvarchar(max) = N'Data Source=192.168.0.135;Initial Catalog=LaborSys;Persist Security Info=True;User ID=laborusertest;Password=laborusertest_pass';
DECLARE @Affected5040 int;
DECLARE @Affected5041 int;

/* 5040 萧山城管管理平台 */
IF EXISTS (
    SELECT 1
    FROM dbo.JC_Product
    WHERE ProductCode = N'5040'
)
BEGIN
    UPDATE dbo.JC_Product
    SET
        ProductName = N'萧山城管管理平台',
        OrganizeType = @OrganizeType,
        ProductType = @ProductType,
        Sort = 5040,
        Url = @Url,
        DbConn = @DbConn,
        Status = @Status,
        CoId = @CoId,
        ExtInt = @ExtInt,
        DeleteStatus = 0,
        CallBackUrl = @CallBackUrl,
        Remark = @Remark,
        UpdateUserId = @UpdateUserId,
        UpdateTime = GETDATE(),
        UpdateUser = @UpdateUser
    WHERE ProductCode = N'5040';
    SET @Affected5040 = @@ROWCOUNT;
END
ELSE
BEGIN
    INSERT INTO dbo.JC_Product (
        ProductCode, ProductName, OrganizeType, ProductType, Sort,
        Url, DbConn, Status, CoId, ExtInt, DeleteStatus,
        LastLoginUserId, LastLoginUser, LastLoginTime,
        CallBackUrl, Remark,
        CreateUserId, CreateUser, CreateTime,
        UpdateUserId, UpdateTime, UpdateUser
    )
    VALUES (
        N'5040', N'萧山城管管理平台', @OrganizeType, @ProductType, 5040,
        @Url, @DbConn, @Status, @CoId, @ExtInt, 0,
        0, NULL, NULL,
        @CallBackUrl, @Remark,
        @CreateUserId, @CreateUser, GETDATE(),
        @UpdateUserId, GETDATE(), @UpdateUser
    );
    SET @Affected5040 = @@ROWCOUNT;
END;

/* 5041 萧山资源化利用网页端 */
IF EXISTS (
    SELECT 1
    FROM dbo.JC_Product
    WHERE ProductCode = N'5041'
)
BEGIN
    UPDATE dbo.JC_Product
    SET
        ProductName = N'萧山资源化利用网页端',
        OrganizeType = @OrganizeType,
        ProductType = @ProductType,
        Sort = 5041,
        Url = @Url,
        DbConn = @DbConn,
        Status = @Status,
        CoId = @CoId,
        ExtInt = @ExtInt,
        DeleteStatus = 0,
        CallBackUrl = @CallBackUrl,
        Remark = @Remark,
        UpdateUserId = @UpdateUserId,
        UpdateTime = GETDATE(),
        UpdateUser = @UpdateUser
    WHERE ProductCode = N'5041';
    SET @Affected5041 = @@ROWCOUNT;
END
ELSE
BEGIN
    INSERT INTO dbo.JC_Product (
        ProductCode, ProductName, OrganizeType, ProductType, Sort,
        Url, DbConn, Status, CoId, ExtInt, DeleteStatus,
        LastLoginUserId, LastLoginUser, LastLoginTime,
        CallBackUrl, Remark,
        CreateUserId, CreateUser, CreateTime,
        UpdateUserId, UpdateTime, UpdateUser
    )
    VALUES (
        N'5041', N'萧山资源化利用网页端', @OrganizeType, @ProductType, 5041,
        @Url, @DbConn, @Status, @CoId, @ExtInt, 0,
        0, NULL, NULL,
        @CallBackUrl, @Remark,
        @CreateUserId, @CreateUser, GETDATE(),
        @UpdateUserId, GETDATE(), @UpdateUser
    );
    SET @Affected5041 = @@ROWCOUNT;
END;

COMMIT TRAN;

SELECT
    @Affected5040 AS Affected5040,
    @Affected5041 AS Affected5041;

SELECT ProductId, ProductCode, ProductName, OrganizeType, ProductType, Sort, Status, CoId, ExtInt, DeleteStatus, Url, CallBackUrl
FROM dbo.JC_Product
WHERE ProductCode IN (N'5040', N'5041')
ORDER BY ProductCode;
