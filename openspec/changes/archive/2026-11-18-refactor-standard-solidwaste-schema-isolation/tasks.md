## 1. 产品项目

- [x] 1.1 新增 `MaterialClient.Common.Standard` 与 `MaterialClient.Common.SolidWaste`，接入解决方案
- [x] 1.2 `SolidWasteDbContext` 只映射两张扩展表；`StandardDbContext` 本变更不映射业务表
- [x] 1.3 迁移历史表使用 `__EFMigrationsHistory_Standard` 与 `__EFMigrationsHistory_SolidWaste`，并使用 `ExistingConnection`

## 2. 扩展表与旧值

- [x] 2.1 固废字段由扩展实体自身方法写入，只用逻辑 Id，不建数据库外键
- [x] 2.2 初始迁移用 `CREATE TABLE IF NOT EXISTS` 建扩展表，不修改内核 `WeighingRecords` 与 `Waybills`
- [x] 2.3 标准宿主在产品迁移后，按 `WeighingMode.SolidWaste` 补缺失扩展行，已存在的逻辑 Id 不覆盖

## 3. 宿主边界

- [x] 3.1 标准宿主先内核、再 Standard、再 SolidWaste
- [x] 3.2 Urban 与 Recycle 宿主不引用、不迁移这两个 Context
- [x] 3.3 未加载 SolidWaste 模块时，扩展写入是空操作；标准宿主的保存会 upsert 扩展行

## 4. 验证

- [x] 4.1 内核模型不包含 SolidWaste 扩展实体；SolidWaste 模型不包含内核称重实体
- [x] 4.2 迁移后内核称重行主键仍在；补数可重复执行且不覆盖已有扩展行
