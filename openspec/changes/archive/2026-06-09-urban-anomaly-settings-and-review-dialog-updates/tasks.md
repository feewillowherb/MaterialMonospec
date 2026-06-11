## 1. 系统设置：Urban 异常阈值配置

- [x] 1.1 在设置数据模型中补充 `UrbanAnomalyDetection` 三个字段（`UpperLimit`、`LowerLimit`、`DeviationPercentage`）并打通加载/保存映射
- [x] 1.2 在 `SettingsWindowViewModel` 增加 Urban 模式可见性状态与三个可绑定属性
- [x] 1.3 在设置窗口 XAML 的系统设置区域最下方新增 Urban 异常阈值编辑区块，并绑定到 ViewModel
- [ ] 1.4 增加非 Urban 模式隐藏、Urban 模式显示的验证（手测或自动化）

## 2. Urban 列表：异常原因、上传时间、审批可用性

- [x] 2.1 扩展 Urban 列表项 DTO/查询结果，新增 `AnomalyReason` 与 `UploadTime` 字段（可空）
- [x] 2.2 在 `UrbanAttendedWeighingWindow.axaml` 列表模板中新增“异常原因”“上传时间”显示
- [x] 2.3 实现上传时间格式化与空值占位展示（如 `--`）
- [x] 2.4 将审批按钮改为仅 `IsAnomaly == true` 时可点击，正常记录禁用且不触发命令

## 3. 审批流程：确认框与只读称重日期

- [x] 3.1 在 `WeighingRecordEditDialog` 增加只读“称重日期”字段并绑定显示
- [x] 3.2 扩展审批弹窗输入模型/初始化参数，确保称重日期能传入并显示
- [x] 3.3 在 `ApproveRecordCommand` 中增加“校验通过后、提交前”的确认框逻辑
- [x] 3.4 确认框取消时中止更新；确认后继续执行现有审批更新流程

## 4. 回归与验收

- [ ] 4.1 验证 Urban 模式下设置项可见且保存后重开可恢复，非 Urban 模式不可见
- [ ] 4.2 验证列表中异常原因与上传时间显示正确，正常记录审批按钮不可点击
- [ ] 4.3 验证审批弹窗显示只读称重日期，点击确定会先弹确认框且确认后才落库
