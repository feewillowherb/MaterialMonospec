## 1. API Layer — IsAnomaly Filter

- [x] 1.1 Add `public bool? IsAnomaly { get; set; }` property to `UrbanWeighingRecordListInputDto` in `UrbanWeighingRecordDtos.cs`
- [x] 1.2 In `UrbanWeighingRecordAppService.GetListAsync`, add `if (input.IsAnomaly.HasValue) { query = query.Where(r => r.IsAnomaly == input.IsAnomaly.Value); }` after the existing time-range filters and before the count query

## 2. Navigation — Sidebar & Tabs

- [x] 2.1 Add `new("/weighing-approval", "异常审批")` to the `_navItems` list in `AdminLayout.razor`

## 3. New Approval Page

- [x] 3.1 Create `WeighingApproval.razor` at `src/UrbanManagement.App/Pages/` with `@page "/weighing-approval"`, inject `IUrbanWeighingRecordAppService`, `IGovProjectAppService`, and `NavigationManager`
- [x] 3.2 Implement the card header with plate number search input, project SearchableSelect (copied from WeighingRecord.razor), search button, and a new anomaly filter dropdown with options "仅异常" / "全部记录" / "仅正常"
- [x] 3.3 Implement the data table with columns: 车牌号, 重量(kg), 称重时间, 项目名, 对接码, 数据质量, 同步状态, 重试次数, 同步时间, 操作 (审批 button)
- [x] 3.4 Implement the anomaly/sync badge helper methods (`GetAnomalyBadgeClass`, `GetAnomalyBadgeText`, `GetSyncTypeBadgeClass`, `GetSyncTypeBadgeText`) and pagination logic (copied from WeighingRecord.razor)
- [x] 3.5 Implement `OnInitializedAsync` to set default anomaly filter to `true` and load projects + records in parallel
- [x] 3.6 Implement `LoadRecords` to pass `IsAnomaly` filter value to `UrbanWeighingRecordListInputDto`
- [x] 3.7 Implement the anomaly filter dropdown change handler that updates the filter state, resets to page 1, and reloads records
- [x] 3.8 Migrate the approval modal markup (modal backdrop, dialog with photos, plate/weight form fields, cancel/submit buttons) from WeighingRecord.razor
- [x] 3.9 Migrate all approval state fields and methods from WeighingRecord.razor: `_showApprovalDialog`, `_isLoadingAttachments`, `_approvalRecordId`, `_approvalRecordPlateNumber`, `_approvalPlateNumber`, `_approvalWeight`, `_approvalLprImage`, `_approvalUrbanPhoto`, `_approvalError`, `_fieldErrors`, `OpenApprovalDialog`, `CloseApprovalDialog`, `HandleModalKeydown`, `SubmitApproval`

## 4. Clean WeighingRecord.razor

- [x] 4.1 Remove the "操作" column header (`<th>操作</th>`) from the table `<thead>`
- [x] 4.2 Remove the approval button cell (`<td>` with "审批" button) from the table `<tbody>` foreach loop, and update the empty-state `colspan` from 10 to 9
- [x] 4.3 Remove the entire approval modal block (from `<!-- Approval Modal -->` comment through the closing `</div>` of the modal backdrop)
- [x] 4.4 Remove all approval-related state fields: `_showApprovalDialog`, `_isLoadingAttachments`, `_approvalRecordId`, `_approvalRecordPlateNumber`, `_approvalPlateNumber`, `_approvalWeight`, `_approvalLprImage`, `_approvalUrbanPhoto`, `_approvalError`, `_fieldErrors`
- [x] 4.5 Remove all approval-related methods: `OpenApprovalDialog`, `CloseApprovalDialog`, `HandleModalKeydown`, `SubmitApproval`
