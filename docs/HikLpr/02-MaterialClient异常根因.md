# MaterialClient 海康 LPR 异常根因分析

## 1. 现象复述（log4.log）

设备型号：`iDS-TCM204-E`（海康智能交通抓拍机），IP `192.168.1.100`。

一次抓拍（16:54:29）在约 11ms 内产生 **11 条** LPR 事件，车牌内容均无意义：

| 时间 | Plate 片段 | 实际可能来源（错位字段） |
|------|-----------|-------------------------|
| .128 | 乱码 + 控制字符 | 结构体头部 / `byGroupNum` 等区域 |
| .130 | `20260701165548354` | `struSnapFirstPicTime`（`yyyyMMddHHmmssfff`） |
| .131 | `00000000000000000` | 零初始化保留字段 |
| .131 | `...b7d6e814babc66f47c28f505f` | `dwMatchNo` / 会话 ID 类字段 |
| .132 | 多次空、`3D` | 遍历数组时的无效槽位 |

设备名：

```text
Unknown (iDS-TCM204-E 20250224AIFW6816131 ... IP CAPTURE CAMERA ... &192.168.1.100)
```

- `Unknown`：`_deviceConfigs.TryGetValue(deviceIp, ...)` 失败（IP 解析错误）。
- 括号内文本：`sDeviceName` + 错位读到的 `sDeviceIP` 尾部。

---

## 2. 代码路径

### 2.1 ITS 处理（当前主路径）

```391:438:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Services\Hikvision\HikvisionLprService.cs
    private void HandleItsPlateResult(IntPtr pAlarmer, IntPtr pAlarmInfo, uint dwBufLen)
    {
        var alarmer = Marshal.PtrToStructure<HikvisionSdk.NET_DVR_ALARMER>(pAlarmer);
        var deviceIp = Encoding.ASCII.GetString(alarmer.sDeviceIP).TrimEnd('\0');
        var itsResult = Marshal.PtrToStructure<HikvisionSdk.NET_ITS_PLATE_RESULT>(pAlarmInfo);

        for (var i = 0; i < itsResult.dwResultNum && i < itsResult.struPlateInfo.Length; i++)
        {
            var plateInfo = itsResult.struPlateInfo[i];
            var plateNumber = HikvisionEncodingHelper.GetString(plateInfo.sLicense, _logger);
            // 发布事件...
        }
    }
```

问题：

1. **`NET_ITS_PLATE_RESULT` 结构体定义错误**（见 §3）。
2. **`struPlateInfo` 被定义为 `NET_ITS_PLATE_INFO[16]` 数组**——官方 SDK 中是 **单个** `NET_DVR_PLATE_INFO struPlateInfo`。
3. **`dwResultNum` 字段在官方结构中不存在**——读到的值是其他字段的字节，常为非零，导致循环多次。
4. 从 **`plateInfo.sLicense`**（自定义子结构顶层）取车牌，而非 **`struPlateInfo.sLicense`**。

### 2.2 旧版 COMM_UPLOAD_PLATE_RESULT

```350:353:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Services\Hikvision\HikvisionLprService.cs
            var plateResult = Marshal.PtrToStructure<HikvisionSdk.NET_DVR_PLATE_RESULT>(pAlarmInfo);
            var plateNumber = HikvisionEncodingHelper.GetString(plateResult.sLicense, _logger);
```

官方 `NET_DVR_PLATE_RESULT` **没有顶层 `sLicense`**，车牌在 `struPlateInfo.sLicense`。当前读的是 `dwSize`/`byResultType` 附近的内存。

---

## 3. 结构体布局对比

### 3.1 NET_ITS_PLATE_RESULT

**官方 SDK**（[文档](https://open.hikvision.com/hardware/structures/NET_ITS_PLATE_RESULT.html)）核心字段顺序：

```c
struct {
  DWORD dwSize;
  DWORD dwMatchNo;
  BYTE  byGroupNum;
  // ... 多个 BYTE/WORD 字段 ...
  NET_DVR_PLATE_INFO   struPlateInfo;      // 单个，内含 sLicense
  NET_DVR_VEHICLE_INFO struVehicleInfo;
  BYTE  byMonitoringSiteID[48];
  BYTE  byDeviceID[48];
  // ...
  NET_DVR_TIME_V30     struSnapFirstPicTime;
  DWORD dwPicNum;
  NET_ITS_PICTURE_INFO struPicInfo[6];     // 图片在末尾
} NET_ITS_PLATE_RESULT;
```

**MaterialClient 当前定义**（`HikvisionSdk.cs`）：

```288:299:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Services\Hikvision\HikvisionSdk.cs
    public struct NET_ITS_PLATE_RESULT
    {
        public int dwResultNum;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
        public NET_ITS_PLATE_INFO[] struPlateInfo;
        public int dwRelativeTime;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public byte[] byRes;
    }
```

差异：**整块内存布局与 SDK 完全不同**，`Marshal.PtrToStructure` 后所有字段均为错位解读。

### 3.2 NET_DVR_PLATE_RESULT

**官方**：`dwSize` → `byResultType` → … → `struPlateInfo` → `struVehicleInfo` → `pBuffer1`/`pBuffer2`（指针在末尾）。

**MaterialClient**：虚构了顶层 `sLicense[48]`、`pBuffer` 在靠前位置，与官方头文件不符。

### 3.3 NET_DVR_ALARMER

**官方**：8 个 `BYTE` 有效标志 + `LONG lUserID` + `sSerialNumber` + `dwDeviceVersion` + `sDeviceName[NAME_LEN]` + … + `sDeviceIP[128]`。

**MaterialClient**：

```202:222:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Services\Hikvision\HikvisionSdk.cs
    public struct NET_DVR_ALARMER
    {
        public int dwAlarmType;
        public int byAlarmOutputNumber;
        // ...
        public byte[] sDeviceIP;  // SizeConst = 129，偏移错误
    }
```

`Encoding.ASCII.GetString(alarmer.sDeviceIP)` 实际读到的是 **`sDeviceName` 附近内存**，解释了日志中设备名与 IP 拼接的现象。

---

## 4. GBK 次要问题（早期日志）

log4.log 更早时段（16:35、16:40）有：

```text
[ERR] 从字节数组读取 GBK 字符串失败
System.ArgumentException: 'GBK' is not a supported encoding name.
```

原因：.NET Core / .NET 10 默认不包含 GBK，需先调用 `Encoding.RegisterProvider(CodePagesEncodingProvider.Instance)`。

MaterialClient 已通过 `CodePagesEncodingInitializer` 在 `Program.cs` 注册；**16:54 时段 GBK 已可用**（无 GBK 异常，但仍乱码），证明 **16:54 的乱码不能归因于 GBK**，而是结构体错位。

`HikvisionEncodingHelper` 在 GBK 不可用时会回退 UTF-8 并打警告——即使回退，正确偏移的 ASCII 车牌（如 `浙A12345` 中的 ASCII 部分）也不应变成时间戳和 UUID。

---

## 5. 根因优先级

```
P0  NET_ITS_PLATE_RESULT / NET_DVR_PLATE_RESULT / NET_DVR_PLATE_INFO 布局错误
P0  HandleItsPlateResult 错误遍历 struPlateInfo 数组
P0  车牌字段路径错误（未使用 struPlateInfo.sLicense）
P1  NET_DVR_ALARMER 布局错误 → 设备 IP/名称错乱
P2  应用启动前未注册 CodePages（早期已导致整段 ITS 处理失败）
```

---

## 6. 与 OpenSpec 任务声明的偏差

`openspec/changes/archive/2026-01-29-hikvision-lpr-implementation/tasks.md` 任务 1.1 验收项写着「Structure fields match HCNetSDK.h header file」，但当前 `HikvisionSdk.cs` 中三个核心结构与官方文档明显不一致，属于 **实现与规范/参考实现脱节**。
