# GovClient 海康 LPR 正常解析分析

## 1. 架构与数据流

GovClient 的 `CaptureDevice` 通过 `NET_DVR_StartListen_V30` 被动接收设备推送，在 `MsgCallback` 中按 `lCommand` 分发：

```454:470:D:\CodeUp\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\BLL\CaptureDevice.cs
        public void MsgCallback(int lCommand, ref CHCNetSDK.NET_DVR_ALARMER pAlarmer, IntPtr pAlarmInfo, uint dwBufLen, IntPtr pUser)
        {
            switch (lCommand)
            {
                case CHCNetSDK.COMM_UPLOAD_PLATE_RESULT:
                    result = ProcessCommAlarm_Plate(ref pAlarmer, pAlarmInfo, dwBufLen, pUser);
                    break;
                case CHCNetSDK.COMM_ITS_PLATE_RESULT:
                    result = ProcessCommAlarm_ITSPlate(ref pAlarmer, pAlarmInfo, dwBufLen, pUser);
                    break;
                // ...
            }
        }
```

iDS-TCM204 系列抓拍机通常上报 **`COMM_ITS_PLATE_RESULT` (0x3050)**，走 `ProcessCommAlarm_ITSPlate`。

---

## 2. 车牌字段读取（关键）

### 2.1 ITS 新版（主要路径）

```542:546:D:\CodeUp\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\BLL\CaptureDevice.cs
                CHCNetSDK.NET_ITS_PLATE_RESULT struITSPlateResult = new CHCNetSDK.NET_ITS_PLATE_RESULT();
                struITSPlateResult = (CHCNetSDK.NET_ITS_PLATE_RESULT)Marshal.PtrToStructure(pAlarmInfo, typeof(CHCNetSDK.NET_ITS_PLATE_RESULT));
                string stringPlateLicense = System.Text.Encoding.GetEncoding("GBK").GetString(struITSPlateResult.struPlateInfo.sLicense).TrimEnd('\0');
```

要点：

- `NET_ITS_PLATE_RESULT` 来自 **AlarmCSharpDemo / CHCNetSDK**，字段顺序与 `HCNetSDK.h` 一致。
- 车牌在 **`struPlateInfo.sLicense`**（`NET_DVR_PLATE_INFO` 的成员），不是顶层字段。
- **只读一次**，不遍历 `struPlateInfo` 数组。
- 过滤占位符：`if (stringPlateLicense.Contains("车牌")) return null;`

### 2.2 旧版 COMM_UPLOAD_PLATE_RESULT

```484:511:D:\CodeUp\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\BLL\CaptureDevice.cs
                CHCNetSDK.NET_DVR_PLATE_RESULT struPlateResultInfo = new CHCNetSDK.NET_DVR_PLATE_RESULT();
                struPlateResultInfo = (CHCNetSDK.NET_DVR_PLATE_RESULT)Marshal.PtrToStructure(pAlarmInfo, typeof(CHCNetSDK.NET_DVR_PLATE_RESULT));
                // ...
                string stringPlateLicense = System.Text.Encoding.GetEncoding("GBK").GetString(struPlateResultInfo.struPlateInfo.sLicense).TrimEnd('\0');
```

同样使用 **`struPlateInfo.sLicense`**，而非结构体顶层的任意 `sLicense` 字段。

---

## 3. 图片保存

ITS 路径从 **`struPicInfo[]`** 按 `byType == 1` 取场景图：

```552:567:D:\CodeUp\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\BLL\CaptureDevice.cs
                int picCount = Math.Min((int)struITSPlateResult.dwPicNum, struITSPlateResult.struPicInfo.Length);
                for (int i = 0; i < picCount; i++)
                {
                    var picInfo = struITSPlateResult.struPicInfo[i];
                    if (picInfo.dwDataLen == 0 || picInfo.byType != HikItsPictureTypeScene)
                        continue;
                    // SaveCaptureImageFromBuffer(picInfo.pBuffer, ...)
```

旧版从 `pBuffer1` / `pBuffer5` 取全景图。

---

## 4. GBK 编码

GovClient 直接使用：

```csharp
Encoding.GetEncoding("GBK").GetString(struITSPlateResult.struPlateInfo.sLicense).TrimEnd('\0');
```

- 运行在 **.NET Framework**（WinForms），系统代码页/GBK **默认可用**，无需 `CodePagesEncodingProvider`。
- 海康 SDK 在 `NET_DVR_PLATE_INFO.sLicense` 中存放 GBK 字节（含中文省份简称如「浙」「京」）。
- `TrimEnd('\0')` 去掉 C 风格结尾 `\0`。

---

## 5. 设备 IP 识别

```570:570:D:\CodeUp\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\Fdsoft.Weight.GovClient\BLL\CaptureDevice.cs
                string strIP = System.Text.Encoding.UTF8.GetString(pAlarmer.sDeviceIP).TrimEnd('\0');
```

`NET_DVR_ALARMER` 在 AlarmCSharpDemo 中布局正确，`sDeviceIP` 偏移与 SDK 一致，能读到 `192.168.1.100` 这类纯 ASCII IP。

---

## 6. GovClient 正常工作的必要条件

| 条件 | GovClient 情况 |
|------|----------------|
| P/Invoke 结构体与 HCNetSDK.h 一致 | ✅ AlarmCSharpDemo 官方示例结构 |
| 从 `struPlateInfo.sLicense` 取车牌 | ✅ |
| ITS 不按数组遍历假 `struPlateInfo` | ✅ 单条处理 |
| GBK 解码 | ✅ .NET Framework 原生支持 |
| 回调委托生命周期 | ⚠️ 未用 GCHandle（已知风险，但与乱码无关） |
| 停止监听 | ⚠️ 误用 `StopRealPlay`（已知 bug，与乱码无关） |

**结论**：GovClient 的正确性核心在于 **使用了与 SDK 头文件匹配的结构体定义和正确的字段路径**，GBK 只是最后一步字节→字符串转换。
