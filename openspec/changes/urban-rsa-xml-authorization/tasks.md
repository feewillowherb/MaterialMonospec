## 1. RSA 解密工具类

- [ ] 1.1 创建 `src/MaterialClient.Common/Services/RsaLicenseDecryptor.cs`：实现 `RsaLicenseDecryptResult` record 和 `RsaLicenseDecryptor` 静态工具类
- [ ] 1.2 实现 `Decrypt(string privateKeyXml, string encryptedBase64)` 方法：RSA.Create() + FromXmlString + PKCS1 解密
- [ ] 1.3 实现 `ReadAndDecrypt(string xmlFilePath)` 方法：XmlDocument 加载 XML、提取四个节点（privateKey、authEndTime、xmlString、proId）、调用 Decrypt 解密全部加密字段、计算 IsExpired 和 DaysRemaining

## 2. StaticLicenseChecker 重写

- [ ] 2.1 重写 `src/MaterialClient.Common/Services/StaticLicenseChecker.cs`：移除所有硬编码测试数据，改为调用 `RsaLicenseDecryptor.ReadAndDecrypt()`
- [ ] 2.2 实现文件缺失场景：返回 `LicenseCheckResult.Fail("授权文件不存在")`，记录 warning 日志
- [ ] 2.3 实现授权过期场景：返回 `LicenseCheckResult.Fail("授权已过期")`，包含过期天数信息
- [ ] 2.4 实现授权有效场景：返回 `LicenseCheckResult.Success()`，AuthEndTime、BuildLicenseNo、ProId 从解密结果获取，ProName/FdBuildLicenseNo 为默认值（null）
- [ ] 2.5 实现异常兜底：catch 所有 Exception，返回 `LicenseCheckResult.Fail()`，记录 error 日志

## 3. 配置变更

- [ ] 3.1 修改 `src/MaterialClient.Common/Configuration/SystemSettings.cs`：`LicenseFilePath` 默认值从 `"license.lic"` 改为 `"RSA.xml"`
