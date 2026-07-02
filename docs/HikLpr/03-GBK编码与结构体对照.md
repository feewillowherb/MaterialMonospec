# GBK 编码与海康结构体字段对照

## 1. 车牌在 SDK 中的存储方式

海康 `NET_DVR_PLATE_INFO`（[官方文档](https://open.hikvision.com/hardware/structures/NET_DVR_PLATE_INFO.html)）中：

```c
char sLicense[MAX_LICENSE_LEN];  // 车牌号码，GBK 编码 C 字符串
BYTE byBelieve[MAX_LICENSE_LEN]; // 各字符置信度
```

- 中文车牌示例：`浙A12345` → 字节序列以 GBK 编码存储，以 `\0` 结尾。
- 纯 ASCII 车牌（外籍/特殊）同样走 `sLicense`，用 GBK GetString 仍可读 ASCII 部分。
- **必须先定位到正确的 `sLicense` 内存偏移**，再谈编码；偏移错误时，GBK/UTF-8 都会产出乱码。

---

## 2. 两端 GBK 用法对比

| 项目 | 解码代码 | GBK 可用性 |
|------|----------|------------|
| GovClient | `Encoding.GetEncoding("GBK").GetString(struITSPlateResult.struPlateInfo.sLicense).TrimEnd('\0')` | .NET Framework 内置 |
| MaterialClient | `HikvisionEncodingHelper.GetString(plateInfo.sLicense, _logger)` → 内部 `Encoding.GetEncoding("GBK")` | 需 `CodePagesEncodingInitializer.Register()` |

MaterialClient 辅助类逻辑（正确）：

```139:167:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Utils\HikvisionEncodingHelper.cs
    public static string GetString(byte[] bytes, ILogger? logger = null)
    {
        // 找 \0 终止符
        var encoding = GetGbkEncoding(logger);
        return encoding.GetString(bytes, 0, length).TrimEnd('\0');
    }
```

```7:25:D:\Github\MaterialMonospec\repos\MaterialClient\src\MaterialClient.Common\Utils\CodePagesEncodingInitializer.cs
/// .NET 10 需调用 Register() 注册 CodePagesEncodingProvider
public static void Register()
{
    Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
}
```

**结论**：编码层实现无本质差异；GovClient 赢在 **读对了 `struPlateInfo.sLicense` 字节数组**。

---

## 3. 正确字段路径（必须遵守）

### COMM_ITS_PLATE_RESULT (0x3050)

```csharp
var its = Marshal.PtrToStructure<NET_ITS_PLATE_RESULT>(pAlarmInfo);
string plate = Encoding.GetEncoding("GBK")
    .GetString(its.struPlateInfo.sLicense)
    .TrimEnd('\0');
```

- `struPlateInfo`：**单个** `NET_DVR_PLATE_INFO`，不是数组。
- 图片：`its.struPicInfo[i]`，`i < its.dwPicNum`。
- 时间：`its.struSnapFirstPicTime`（GovClient 格式化为 `yyyyMMddHHmmssfff` 字符串）。

### COMM_UPLOAD_PLATE_RESULT (0x2800)

```csharp
var plateResult = Marshal.PtrToStructure<NET_DVR_PLATE_RESULT>(pAlarmInfo);
string plate = Encoding.GetEncoding("GBK")
    .GetString(plateResult.struPlateInfo.sLicense)
    .TrimEnd('\0');
```

- 全景图：`plateResult.pBuffer1`（`dwPicLen`）或 `pBuffer5`（`dwFarCarPicLen`）。

---

## 4. log4 乱码字段与官方结构映射

结合 log4.log 342–364 行推断错位读取：

| 日志中的「车牌」 | 可能对应官方字段 | 说明 |
|----------------|-----------------|------|
| `20260701165548354` | `struSnapFirstPicTime` | 17 位：年月日时分秒毫秒 |
| `00000000000000000` | 保留字节 / `byMonitoringSiteID` 片段 | 全零区域被当字符串 |
| `b7d6e814babc66f47c28f505f` | `dwMatchNo` 或 GUID 相关 | 32 位十六进制形态 |
| `3D` | 单字节字段误读 | `byVehicleType` 等 |
| 设备名 + IP 混合 | `sDeviceName` + `sDeviceIP` 错位 | `NET_DVR_ALARMER` 布局错误 |

一次抓拍 ~11 条事件 ≈ `for (i < dwResultNum && i < 16)` 在错误布局上把结构体内存切成 16 段，每段 48 字节假 `sLicense` 解码一次。

---

## 5. NET_DVR_PLATE_INFO 在 C# 中的注意点

官方结构含 **指针字段** `char *pXmlBuf` 和嵌套 `NET_VCA_RECT`，定长 marshalling 时必须：

- 使用 `[StructLayout(LayoutKind.Sequential)]`
- `sLicense` 使用 `[MarshalAs(UnmanagedType.ByValArray, SizeConst = MAX_LICENSE_LEN)]`（具体长度以所用 SDK 头文件为准，常见 16 或更大版本为 32）
- 指针字段用 `IntPtr`
- 考虑 `Pack` 与 32/64 位对齐（与海康 DLL 一致，通常 x64 为 8 字节对齐）

**推荐**：从 GovClient 使用的 AlarmCSharpDemo `CHCNetSDK.cs` 或 SDK 包内 `HCNetSDK.h` **整段移植**结构体，而非手写简化版。

---

## 6. 编码相关检查清单

- [ ] 应用入口最早调用 `CodePagesEncodingInitializer.Register()`
- [ ] `HikvisionEncodingHelper` 在 GBK 失败时打 **Warning**（已有）
- [ ] 车牌来源 **`struPlateInfo.sLicense`**，非顶层字段
- [ ] `TrimEnd('\0')` 处理 C 字符串
- [ ] 可选：过滤 `stringPlateLicense.Contains("车牌")` 占位符（GovClient 做法）
- [ ] 结构体布局与 HCNetSDK V6.1.9.48+ 头文件一致（**当前缺失**）
