# 2026-08-27-lpr-device-type-on-add

| 字段 | 值 |
|------|-----|
| status | scratch |
| created | 2026-08-27 |
| theme_guess | xiaoshan-upload（桌面侧也碰 urban-weighing；晋升时可能拆两条） |
| park_guess | park/xiaoshan-serve |
| source | 用户会话 /intake-draft |

## 碎片

- 设置里的「车牌识别设备类型」不要只在外部/全局决定。
- 希望改到**添加设备时**再选定类型（每台设备各自决定，而不是全站一份全局配置）。
- 待拆：现有全局字段如何迁移、已添加设备是否回填、与海康/其他 LPR 适配的绑定点。
- 新增车牌识别配置时，新增 **LPR 类型**：地磅、卡口、成品。
- **地磅**类型 LPR：服务于地磅生成称重记录。
- **卡口**、**成品**：类似，都不需要重量；只上传抓拍车牌号、LPR 照片。
- 卡口/成品可能需要**独立 entity**；数据不由地磅记录产生，而是 **LPR 产生**。
- 该类数据要先上传到 UrbanManagement，再由 UM 上传到对应平台接口。

## 续聊笔记

- 尚未确认：设置页是否完全去掉全局「设备类型」，还是保留默认值、添加时覆盖。
- 卡口/成品与现有称重记录、萧山三模式上报如何对齐，未拆清。

## 晋升记录

<!-- promote 时填写；随后 archive（移入 drafts/archive/）或 delete 本文件 -->
| 字段 | 值 |
|------|-----|
| promoted_to | |
| promoted_on | |
| disposition | archive \| delete |
| archived_to | （仅 archive 时：drafts/archive/YYYY-MM-DD-slug.md） |
