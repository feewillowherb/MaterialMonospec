## Context

`SettingsWindowViewModel.EditLprAsync` 已用 `new AddLprDialog(dialogViewModel)` 预填行数据并替换集合项。AXAML 操作列「编辑」为 `IsVisible="False"`，用户看不到。`AddLprDialog.axaml` 标题写死「添加车牌识别设备」。摄像头已共用 `AddCameraDialog` 做增加/编辑。Avalonia 用 `IsVisible` 与 `Title` 绑定，不引入第二套 Window。MaterialClient 继续 ReactiveUI，不换 CommunityToolkit。

## Goals / Non-Goals

**Goals:**

- 露出编辑按钮，走已有 `EditLprCommand`。
- **确认可以共用**：增加与编辑 MUST 共用 `AddLprDialog` + `AddLprDialogViewModel`；用模式标志或标题属性区分文案。
- 编辑预填该行（含 `DeviceType`、道闸字段）；保存替换原行。

**Non-Goals:**

- 不新建 `EditLprDialog`。
- 不改配置 JSON / SDK / 道闸运行时（海康仍不执行臻识 IO）。
- 不改摄像头对话框。
- 不把表格行内联编辑当本期方案。

## Decisions

1. **共用同一 Window，不用复制 AXAML**  
   选择：增加只差默认名与空字段；编辑差预填与替换下标。表单、厂商 Combo、海康/臻识/道闸可见性已经在 `AddLprDialogViewModel`。复制窗口会双份绑定与厂商切换逻辑。  
   备选：`EditLprDialog` 拷贝。放弃：用户已确认几乎一样。

2. **模式只影响文案，不影响控件树**  
   选择：ViewModel 暴露 `IsEditMode` / `DialogTitle`（及可选页内标题），Window `Title="{Binding DialogTitle}"`。增加路径 `IsEditMode=false`。  
   备选：code-behind 设 `Title`。放弃：与 MVVM 不一致。

3. **露出按钮即可，命令已存在**  
   去掉 `IsVisible="False"`（或改为 `True`）。`Command` / `CommandParameter` 已绑 `EditLprCommand`。  
   风险：`WhenAnyValue(DeviceType)` 在构造时会跑 `ApplyEmptyVendorDefaults`；仅填空白，预填后的非空字段应保留。编辑打开后先赋属性再显示。

## Risks / Trade-offs

- [编辑打开后厂商默认值冲掉已填端口] → 默认值只填 `IsNullOrWhiteSpace`；编辑赋值放在订阅之后或先填再订阅。验证编辑海康/臻识各一行。
- [用户以为会立刻写库] → 与增加相同：只改内存集合，点设置「保存」才持久化。

## Migration Plan

无数据迁移。回滚：再藏编辑按钮。

## Open Questions

无。共用结论：**可以且应当共用**。
