## 1. UrbanManagement — 协议档位与 DTO

- [x] 1.1 `XiaoshanUploadConfigWriteDto` 增加 `ClientProtocolVersion`（缺省 1）；文档化 v1/v2/v3 常量
- [x] 1.2 Write 入口按档位分流：v1 merge / v2+ 乐观并发 / v3 envelope 校验

## 2. UrbanManagement — Legacy merge 实现

- [x] 2.1 实现 merge helper：白名单 DisplayName/Remark；空 `{}` modes/settings 保留服务端 structured JSON
- [x] 2.2 v1 merge 成功仍 `configVersion++`；change log Summary 标注 `legacy-merge`
- [x] 2.3 单元测试：v1 `{}` 不抹 modes、v2 冲突、v1 merge 递增 version

## 3. MaterialClient.Urban

- [x] 3.1 Write DTO/Refit 增加 `clientProtocolVersion`；当前客户端固定发送 **3**
- [x] 3.2 确认 v3 路径仍带 `expectedConfigVersion` 与 structured JSON

## 4. 收尾

- [ ] 4.1 联调或集成测试：模拟 v1 payload 不破坏已配置三模式；v3 正常保存
- [x] 4.2 确认范围不含 GovSync / 双 Write 响应形态；变更留在 `epic/xiaoshan-platform-upload`
