## 1. Form mapping Service

- [ ] 1.1 新增命名 `record`：`XiaoshanUploadSettingsFormState`、`XiaoshanUploadPreservedStatics`（禁止 tuple）
- [ ] 1.2 在 **Common** 实现 `IXiaoshanUploadSettingsFormMapper` / `XiaoshanUploadSettingsFormMapper`（`ITransientDependency`）：ApplyToForm / ToDraft；UI 工程不得引用 Urban
- [ ] 1.3 实现至少一启用模式的校验方法；单测：空 `{}` 默认、三模式全关失败、静态字段 round-trip
- [ ] 1.4 `SettingsWindowViewModel` 注入 Common mapper；删除 VM 内信封 JSON 解析/序列化与散落 `_preserved*`

## 2. Settings 分区绑定

- [ ] 2.1 按 Avalonia 绑定（`IsVisible` bool，非 WPF `Visibility`）将各分区可见性绑到 `SelectedSettingsSection`
- [ ] 2.2 `ListBox` 选中只更新 `SelectedSettingsSection`；打开默认仍为地磅设置；隐藏 Urban 项不得成为默认
- [ ] 2.3 删除 `_navigationItems` / `RegisterNav` / 扫 `SettingsSectionsHost.Children` 设 `IsVisible`；保留 LPR 列可见性等无关逻辑

## 3. 保存失败与预校验

- [ ] 3.1 去掉 `SaveAsync` 空 `catch`；失败 MessageBox（或现有提示）+ `ILogger`；失败不发 `DetailCloseRequestedMessage`
- [ ] 3.2 脏城管配置且无启用模式：不 Publish 萧山 LocalEvent，提示用户，窗口保持打开
- [ ] 3.3 保持既有推送成功/有服务端行失败覆盖/无行保留草稿语义

## 4. 字段映射对齐

- [ ] 4.1 `MaterialClient.Urban` `XiaoshanUploadFieldMappingService` Weighbridge `dataSource`：mode settings 非空优先，否则 `WEIGHBRIDGE_XIAOSHAN`
- [ ] 4.2 单测或对照 UM：自定义 dataSource 与缺省常量两条路径

## 5. 验证

- [ ] 5.1 编译 `MaterialClient.UI` / Urban / 主程序
- [ ] 5.2 冒烟：切换分区、保存失败提示、三模式全关拦截、Urban/非 Urban 导航
