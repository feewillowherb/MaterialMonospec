## 1. SDK 结构体替换（MaterialClient）

- [ ] 1.1 从 `CH-HCNetSDKV6.1.9.48` 交通产品 Demo `TrafficDemo/CHCNetSDK.cs`（或 GovClient `BLL/CHCNetSDK.cs`）确认 LPR 相关类型依赖链
- [ ] 1.2 在 `HikvisionSdk.cs` 中删除自创类型：`NET_ITS_PLATE_INFO`、`NET_DVR_PLATE_INFO_EX` 及错误的 `NET_ITS_PLATE_RESULT` 布局
- [ ] 1.3 替换/新增官方对齐类型：`NET_DVR_ALARMER`、`NET_DVR_PLATE_INFO`、`NET_DVR_PLATE_RESULT`、`NET_ITS_PLATE_RESULT`、`NET_ITS_PICTURE_INFO`、`NET_DVR_VEHICLE_INFO`、`NET_DVR_TIME_V30` 及必要依赖（如 `NET_VCA_RECT`）
- [ ] 1.4 在 `HikvisionSdk.cs` 文件头注明 SDK 版本（V6.1.9.48）与结构体来源路径
- [ ] 1.5 确保项目可编译通过（`dotnet build` MaterialClient.Common）

## 2. 回调解析逻辑修正（MaterialClient）

- [ ] 2.1 修正 `HandleItsPlateResult`：从 `struPlateInfo.sLicense` 读取车牌；删除 `struPlateInfo[i]` 遍历；过滤空车牌与「车牌」占位符
- [ ] 2.2 修正 `HandlePlateResult`：从 `struPlateInfo.sLicense` 读取车牌；图片从 `pBuffer1`/`dwPicLen`（回退 `pBuffer5`）提取
- [ ] 2.3 修正 `NET_DVR_ALARMER` 解析：从 `sDeviceIP` 提取 IP，使设备配置可按 IP 匹配
- [ ] 2.4 修正 ITS 图片保存：`struPicInfo[i]`、`i < dwPicNum`、`byType == 1` 场景图路径
- [ ] 2.5 更新 `MapPlateColor` 等辅助方法以使用 `NET_DVR_PLATE_INFO`（替代已删除的 `NET_DVR_PLATE_INFO_EX`）

## 3. 防回归与测试（MaterialClient）

- [ ] 3.1 添加 `Marshal.SizeOf` 断言测试（`NET_ITS_PLATE_RESULT`、`NET_DVR_PLATE_RESULT`、`NET_DVR_ALARMER` 等与官方期望值一致）
- [ ] 3.2 确认应用启动路径已调用 `CodePagesEncodingInitializer.Register()`（GBK 可用）
- [ ] 3.3 真机验收：iDS-TCM204-E 单次抓拍仅 1 条有效 LPR 事件，车牌为真实号牌（非时间戳/UUID）
- [ ] 3.4 真机验收：设备 IP 显示为配置名称或 `192.168.1.x`，非 `Unknown (设备名...)` 拼接
- [ ] 3.5 对比 GovClient 同设备抓拍，车牌字符串一致

## 4. 文档与 OpenSpec 收尾（MaterialMonospec）

- [ ] 4.1 在 `docs/HikLpr/` 或变更说明中记录已采用的 `CHCNetSDK.cs` 来源路径
- [ ] 4.2 运行 `openspec validate fix-hikvision-sdk-struct-layout --strict` 通过
- [ ] 4.3 实现完成后将本 `tasks.md` 中已完成项标记为 `- [x]`
