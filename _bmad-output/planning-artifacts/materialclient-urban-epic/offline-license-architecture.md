---
stepsCompleted: [1]
inputDocuments:
  - openspec/specs/rsa-xml-license/spec.md
  - openspec/specs/static-license-test-data/spec.md
  - _bmad-output/planning-artifacts/materialclient-urban-epic/prd.md
  - _bmad-output/planning-artifacts/materialclient-urban-epic/project-context.md
workflowType: 'architecture'
project_name: 'MaterialMonospec'
user_name: '77162'
date: '2026-06-10'
---

# 架构：离线授权方案设计（替代 RSA.xml）

**主题**: 设计一套合理的离线授权方案替代现有 RSA.xml
**关联 Epic**: `materialclient-urban-epic`

---

## 1. 背景与问题陈述

### 1.1 现有方案（RSA.xml）

当前授权方案基于 RSA.xml 文件：
- XML 包含加密字段：`privateKey`、`authEndTime`、`xmlString`、`proId`
- 使用 RSA 私钥解密 + 过期时间验证
- `StaticLicenseChecker` 在启动时读取
- **问题**：
  - 需要在客户端部署 RSA 私钥（安全风险）
  - XML 格式复杂，解析和加密代码较多
  - 授权文件生成过程需要维护

### 1.2 新需求

| 需求项 | 说明 |
|--------|------|
| 授权来源 | UrbanManagement 生成授权文件 |
| 离线运行 | 客户端完全离线，不依赖网络验证 |
| 可复制性 | 允许复制到其他电脑（不限制机器绑定） |
| 防篡改 | 核心要求，不允许修改授权内容 |
| 代码量 | 尽量减少，或使用现成成熟方案 |

---

## 2. 技术方案对比

### 方案 A：JSON Web Token (JWT) - 签名验证

**原理**：
- UrbanManagement 使用私钥签名 JWT Token
- 客户端使用公钥验证签名
- Token 包含授权信息（过期时间、ProId、BuildLicenseNo 等）

**优点**：
- ✅ **标准成熟**：RFC 7519 标准，库支持广泛
- ✅ **私钥安全**：私钥仅在服务端，客户端仅需公钥
- ✅ **防篡改**：签名验证保证内容不可篡改
- ✅ **代码量少**：.NET 有 `System.IdentityModel.Tokens.Jwt` 官方库
- ✅ **自包含**：所有信息都在 Token 内，完全离线
- ✅ **可复制**：公钥可随应用分发，允许多设备使用

**缺点**：
- ⚠️ Token 较大（Base64 编码）
- ⚠️ 需要选择合适的签名算法（RS256 推荐）

**实现复杂度**：低

---

### 方案 B：HMAC 签名 JSON 文件

**原理**：
- UrbanManagement 生成 JSON 授权文件
- 使用共享密钥计算 HMAC-SHA256 签名
- 客户端验证 HMAC 签名

**优点**：
- ✅ **简单直观**：JSON 格式易读
- ✅ **代码量少**：.NET 内置 HMAC 支持
- ✅ **防篡改**：签名验证

**缺点**：
- ❌ **密钥共享**：客户端和服务端共享同一密钥（泄露风险）
- ❌ **密钥分发**：密钥需安全嵌入客户端

**实现复杂度**：低

---

### 方案 C：数字签名 XML/JSON 文件（非对称）

**原理**：
- 类似现有方案，但优化为标准数字签名
- 服务端用私钥签名，客户端用公钥验证

**优点**：
- ✅ **私钥安全**：私钥仅在服务端
- ✅ **防篡改**：数字签名保证

**缺点**：
- ❌ **代码量中等**：需要处理签名格式
- ⚠️ XML/JSON 解析 + 签名验证代码

**实现复杂度**：中

---

### 方案 D：Ed25519 现代签名方案

**原理**：
- 使用 Ed25519 签名算法（现代、安全、快速）
- 服务端签名，客户端验证

**优点**：
- ✅ **现代安全**：Ed25519 被广泛认可
- ✅ **性能好**：签名和验证速度快
- ✅ **密钥短**：相比 RSA 更短
- ✅ **库支持**：`BouncyCastle` 等库支持

**缺点**：
- ⚠️ 需要第三方库（BouncyCastle）
- ⚠️ 相对 JWT 不那么"开箱即用"

**实现复杂度**：低-中

---

## 3. 推荐方案：JWT (RS256)

### 3.1 选择理由

1. **成熟度**：JWT 是行业标准，库支持完善
2. **安全性**：非对称加密，私钥不离开服务端
3. **简洁性**：代码量最少，.NET 官方库支持
4. **可维护性**：标准化方案，团队熟悉度高
5. **灵活性**：支持自定义声明（Claims）

### 3.2 架构设计

```mermaid
flowchart TB
    subgraph UrbanManagement["UrbanManagement 服务端"]
        Gen[生成授权 JWT]
        Sign[RS256 私钥签名]
        File[导出 .urban 文件]
    end

    subgraph Client["MaterialClient.Urban 客户端"]
        Read[读取授权文件]
        Verify[RS256 公钥验证签名]
        Parse[解析 Claims]
        Check[检查过期时间]
        Result[返回 LicenseCheckResult]
    end

    subgraph Security["安全边界"]
        PrivKey[(私钥<br/>仅服务端)]
        PubKey[(公钥<br/>嵌入客户端)]
    end

    Gen --> Sign --> File --> Read
    Read --> Verify --> Parse --> Check --> Result
    Sign -.使用.-> PrivKey
    Verify -.使用.-> PubKey
```

### 3.3 授权文件格式 (.urban)

**文件内容**：
```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJwcm9JZCI6IjEyMzQ1Njc4LTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsInByb05hbWUiOiLmtYvor5Xnu7znur8iLCJidWlsZExpY2Vuc2VObyI6IjEyMzQ1Njc4OTAiLCJleHAiOjE3Mzg3NjYyMDAsImp0aSI6ImF1dGgtMjAyNi0wNi0xMCJ9.完整的签名部分
```

**JWT Claims 结构**：
```json
{
  "proId": "12345678-0000-0000-0000-000000000000",
  "proName": "测试项目",
  "buildLicenseNo": "1234567890",
  "exp": 1738766200,        // Unix 时间戳，过期时间
  "jti": "auth-2026-06-10", // JWT ID
  "iss": "UrbanManagement",  // 签发者
  "aud": "MaterialClient.Urban" // 受众
}
```

### 3.4 密钥管理

| 密钥类型 | 存储位置 | 用途 |
|---------|---------|------|
| RSA 私钥 | UrbanManagement 配置 / 密钥库 | 签发 JWT |
| RSA 公钥 | MaterialClient.Urban 配置 / 硬编码 | 验证 JWT |

**公钥分发方式**（按优先级）：
1. **嵌入配置**：`appsettings.json` 中的 `Urban:JwtPublicKey`（推荐）
2. **嵌入代码**：编译时常量（不推荐，难以更新）
3. **独立文件**：与程序同目录的 `.pubkey` 文件

---

## 4. 具体实现建议

### 4.1 服务端（UrbanManagement）

```csharp
// 生成授权的服务
public interface IUrbanLicenseGenerator
{
    string GenerateLicenseToken(UrbanLicenseRequest request);
}

// 实现示例
public class UrbanLicenseGenerator : IUrbanLicenseGenerator
{
    private readonly RSA _rsaPrivateKey;

    public UrbanLicenseGenerator(IConfiguration config)
    {
        // 从配置加载 RSA 私钥
        var privateKeyPem = config["Urban:JwtPrivateKey"];
        _rsaPrivateKey = RSA.Create();
        _rsaPrivateKey.ImportFromPem(privateKeyPem);
    }

    public string GenerateLicenseToken(UrbanLicenseRequest request)
    {
        var credentials = new SigningCredentials(
            new RsaSecurityKey(_rsaPrivateKey),
            SecurityAlgorithms.RsaSha256);

        var claims = new[]
        {
            new Claim("proId", request.ProId.ToString()),
            new Claim("proName", request.ProName ?? ""),
            new Claim("buildLicenseNo", request.BuildLicenseNo ?? ""),
            new Claim(JwtRegisteredClaimNames.Exp,
                new DateTimeOffset(request.ExpiresAt).ToUnixTimeSeconds().ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(JwtRegisteredClaimNames.Iss, "UrbanManagement"),
            new Claim(JwtRegisteredClaimNames.Aud, "MaterialClient.Urban")
        };

        var token = new JwtSecurityToken(
            claims: claims,
            signingCredentials: credentials,
            expires: request.ExpiresAt);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
```

### 4.2 客户端（MaterialClient.Urban）

```csharp
// 替代现有的 StaticLicenseChecker
public class JwtLicenseChecker : IStaticLicenseChecker
{
    private readonly RSA _rsaPublicKey;
    private readonly ILogger<JwtLicenseChecker> _logger;

    public JwtLicenseChecker(IConfiguration config, ILogger<JwtLicenseChecker> logger)
    {
        _logger = logger;

        // 从配置加载 RSA 公钥
        var publicKeyPem = config["Urban:JwtPublicKey"];
        _rsaPublicKey = RSA.Create();
        _rsaPublicKey.ImportFromPem(publicKeyPem);
    }

    public async Task<LicenseCheckResult> CheckLicenseAsync(string licenseFilePath)
    {
        try
        {
            if (!File.Exists(licenseFilePath))
            {
                _logger.LogWarning("授权文件不存在: {Path}", licenseFilePath);
                return LicenseCheckResult.Fail("授权文件未找到");
            }

            var token = await File.ReadAllTextAsync(licenseFilePath);

            // 验证和解析 JWT
            var handler = new JwtSecurityTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = "UrbanManagement",
                ValidateAudience = true,
                ValidAudience = "MaterialClient.Urban",
                ValidateLifetime = true,
                IssuerSigningKey = new RsaSecurityKey(_rsaPublicKey),
                ValidateIssuerSigningKey = true
            };

            var principal = handler.ValidateToken(token, validationParameters, out _);

            // 提取 Claims
            var proIdClaim = principal.FindFirst("proId")?.Value;
            var proNameClaim = principal.FindFirst("proName")?.Value;
            var buildLicenseNoClaim = principal.FindFirst("buildLicenseNo")?.Value;
            var expClaim = principal.FindFirst(JwtRegisteredClaimNames.Exp)?.Value;

            if (!Guid.TryParse(proIdClaim, out var proId))
            {
                return LicenseCheckResult.Fail("无效的 ProId 格式");
            }

            var authEndTime = DateTimeOffset.FromUnixTimeSeconds(long.Parse(expClaim)).DateTime;
            var isExpired = authEndTime < DateTime.Now;
            var daysRemaining = (authEndTime - DateTime.Now).Days;

            _logger.LogInformation(
                "授权检查完成: ProId={ProId}, ProName={ProName}, 已过期={IsExpired}, 剩余天数={Days}",
                proId, proNameClaim, isExpired, daysRemaining);

            return isExpired
                ? LicenseCheckResult.Fail($"授权已过期（过期时间: {authEndTime:yyyy-MM-dd}）")
                : LicenseCheckResult.Success(
                    $"授权有效（剩余 {daysRemaining} 天）",
                    new LicenseInfo
                    {
                        ProId = proId,
                        ProName = proNameClaim,
                        BuildLicenseNo = buildLicenseNoClaim
                    });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "授权验证失败");
            return LicenseCheckResult.Fail($"授权验证失败: {ex.Message}");
        }
    }
}
```

### 4.3 NuGet 包依赖

```xml
<!-- 仅需添加这一个官方包 -->
<PackageReference Include="System.IdentityModel.Tokens.Jwt" Version="7.0.0" />
```

### 4.4 配置示例

**UrbanManagement (appsettings.json)**：
```json
{
  "Urban": {
    "JwtPrivateKey": "-----BEGIN RSA PRIVATE KEY-----\n私钥内容...\n-----END RSA PRIVATE KEY-----"
  }
}
```

**MaterialClient.Urban (appsettings.json)**：
```json
{
  "Urban": {
    "ProductCode": 5030,
    "WeighingMode": 201,
    "ServerBaseUrl": "https://urban.example/",
    "LicenseFilePath": "./license.urban",
    "JwtPublicKey": "-----BEGIN PUBLIC KEY-----\n公钥内容...\n-----END PUBLIC KEY-----"
  }
}
```

---

## 5. 实施步骤

### Phase 1：服务端准备
1. 生成 RSA 密钥对（2048 位或以上）
2. 在 UrbanManagement 实现 `IUrbanLicenseGenerator`
3. 创建管理界面生成和下载授权文件
4. 配置私钥（生产环境使用密钥库）

### Phase 2：客户端实现
1. 添加 NuGet 包 `System.IdentityModel.Tokens.Jwt`
2. 实现 `JwtLicenseChecker` 替代现有 RSA.xml 方案
3. 更新 `appsettings.json` 配置
4. 保持 `IStaticLicenseChecker` 接口不变

### Phase 3：测试与验证
1. 单元测试：签名验证、过期检查、篡改检测
2. 集成测试：完整授权流程
3. 离线场景验证：断网环境启动和运行

### Phase 4：迁移与清理
1. 保留 RSA.xml 方案作为回退
2. 更新文档和部署指南
3. 可选：移除旧的 RSA.xml 相关代码

---

## 6. 安全考虑

### 6.1 密钥安全

| 关注点 | 措施 |
|-------|------|
| 私钥存储 | 使用密钥库（如 Azure Key Vault）或环境变量 |
| 私钥轮换 | 定期更换密钥，支持多版本公钥验证 |
| 公钥分发 | 随应用分发，可公开 |

### 6.2 Token 安全

| 关注点 | 措施 |
|-------|------|
| Token 泄露 | 允许复制，不绑定设备（按需求） |
| 重放攻击 | 短期 Token 可选 jti 声明用于吊销 |
| 时间攻击 | 使用 `exp` 声明强制过期 |

### 6.3 防篡改验证

| 篡改场景 | JWT 响应 |
|---------|---------|
| 修改 Claims | 签名验证失败 |
| 修改过期时间 | 签名验证失败 |
| 更换部分 Token | 格式错误或签名失败 |

---

## 7. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|-----|------|------|----------|
| 公钥配置错误 | 中 | 高 | 启动时验证公钥格式；日志记录 |
| 时间同步问题 | 低 | 中 | 允许时钟偏移（默认 5 分钟） |
| JWT 库漏洞 | 低 | 高 | 使用官方库，定期更新 |
| 密钥泄露 | 低 | 高 | 密钥轮换机制，吊销机制（可选） |

---

## 8. 备选方案：简化版

### 若 JWT 仍被认为"太重"：

**HMAC + JSON 签名方案**（共享密钥）：
```csharp
// 服务端生成
var json = JsonSerializer.Serialize(data);
var signature = HMACSHA256.HashData(sharedKey, Encoding.UTF8.GetBytes(json));
File.WriteAllText(path, $"{json}.{Convert.ToBase64String(signature)}");

// 客户端验证
var parts = File.ReadAllText(path).Split('.');
var computed = HMACSHA256.HashData(sharedKey, Encoding.UTF8.GetBytes(parts[0]));
return computed.SequenceEqual(Convert.FromBase64String(parts[1]));
```

**权衡**：
- ✅ 更简单，无需额外 NuGet 包
- ❌ 密钥共享，安全性较低
- ❌ 无标准化，需自定义实现

---

## 9. 总结与建议

### 推荐方案：JWT (RS256)

**核心优势**：
1. ✅ 成熟标准，库支持完善
2. ✅ 私钥不离开服务端，安全
3. ✅ 代码量少，易于维护
4. ✅ 满足所有需求：离线、可复制、防篡改

### 下一步行动

| 步骤 | 负责方 | 优先级 |
|-----|-------|--------|
| 确认技术方案 | 双方 | P0 |
| 生成 RSA 密钥对 | UrbanManagement | P0 |
| 实现服务端生成器 | UrbanManagement | P1 |
| 实现客户端验证器 | MaterialClient | P1 |
| 编写测试用例 | 双方 | P1 |
| 更新部署文档 | 双方 | P2 |

---

**文档状态**：已完成初步架构设计，待评审确认
