# Implementation Tasks: Device Management Page

## Implementation Prerequisites

**Required Skills/Domain Knowledge:**

- **guess-governance** - Spec-driven change governance domain knowledge. This skill provides reasoning habits and behavioral guardrails for handling incomplete requirements and ambiguous specifications during implementation.

When implementing this change, apply the guess-governance principles to:
- Handle scenarios where requirements may be incomplete or ambiguous
- Make reasonable assumptions when specifications are unclear
- Document assumptions made during implementation
- Follow spec-driven development workflows

---

## 1. Backend Infrastructure - DTOs and Models

- [ ] 1.1 Create `DeviceStatusListRequestDto.cs` in `UrbanManagement.Core/Models`
  - Add properties: ClientId (string?), DeviceType (string?), Status (string?), SkipCount (int), MaxResultCount (int)
  - Follow ABP DTO naming conventions

- [ ] 1.2 Create `DeviceStatusQueryDto.cs` in `UrbanManagement.Core/Models`
  - Add properties: ClientId, DeviceType, Status, LastUpdateTime, AdditionalData
  - Implement static method `FromMessage(DeviceStatusMessage message)` for mapping
  - Follow ABP DTO naming conventions

- [ ] 1.3 Create `PagedResultDto<DeviceStatusQueryDto>` (if not already exists)
  - Add properties: Items (List), TotalCount (long)
  - Follow ABP PagedResultDto pattern

## 2. Backend Services - Device Status Query

- [ ] 2.1 Create `IDeviceStatusQueryService.cs` interface in `UrbanManagement.Core/Services`
  - Inherit from `IApplicationService`
  - Add method signature: `Task<PagedResultDto<DeviceStatusQueryDto>> GetDeviceStatusListAsync(DeviceStatusListRequestDto input)`

- [ ] 2.2 Create `DeviceStatusQueryService.cs` implementation in `UrbanManagement.Core/Services`
  - Inherit from `ApplicationService` and implement `IDeviceStatusQueryService`
  - Apply `[AutoConstructor]` attribute and `partial class` modifier
  - Inject `IDistributedCache` and `ILogger<DeviceStatusQueryService>` as private readonly fields
  - Implement `GetDeviceStatusListAsync` method:
    - Read device status messages from distributed cache
    - Apply filter conditions (ClientId, DeviceType, Status)
    - Aggregate latest status for each ClientId + DeviceType combination
    - Apply pagination (SkipCount, MaxResultCount)
    - Return paged result

- [ ] 2.3 Implement cache reading logic in `DeviceStatusQueryService`
  - Implement `GetAllDeviceStatusFromCacheAsync` private method
  - Iterate through all cache keys matching pattern `device_status_cache:*`
  - Deserialize cached JSON to `List<DeviceStatusMessage>`
  - Handle deserialization failures gracefully (log warning and skip)

- [ ] 2.4 Add device type validation constants
  - Add static readonly HashSet with valid device types: "Scale", "Camera", "LPR", "Sound", "Printer"
  - Use in filter validation and error messages

- [ ] 2.5 Register service in ABP module
  - Ensure `DeviceStatusQueryService` is registered as transient dependency via `[AutoConstructor]`
  - Verify no manual registration required in Module (ABP implicit registration)

## 3. Backend Controllers

- [ ] 3.1 Create `DeviceManagementController.cs` in `UrbanManagement.App/Controllers`
  - Inherit from `AbpController` (not `Controller`)
  - Add route attribute: `[Route("DeviceManagement")]`
  - Add `Index()` action returning ViewResult for main page
  - Add constructor (if needed for dependency injection)

- [ ] 3.2 Add navigation menu item
  - Edit `Views/Shared/_Layout.cshtml`
  - Add new menu item: `<a class="nav-link text-dark" asp-area="" asp-controller="DeviceManagement" asp-action="Index">Device Management</a>`
  - Position after "Project" menu item

## 4. Frontend Views - Main Page

- [ ] 4.1 Create `DeviceManagement` folder in `Views`
  - Create directory: `Views/DeviceManagement/`

- [ ] 4.2 Create `Index.cshtml` main page
  - Set layout to `_Layout`
  - Set page title: "设备管理"
  - Add Bootstrap card structure
  - Add filter form with fields: Device Type (dropdown), Status (dropdown), ClientId (text input), Search button
  - Add device status table with columns: ClientId, DeviceType, Status, LastUpdateTime, AdditionalData
  - Add pagination control at bottom
  - Add real-time update indicator with SignalR connection status

- [ ] 4.3 Implement filter form UI
  - Use Bootstrap form classes (`row`, `g-3`, `col-md-*`, `form-select`, `form-control`)
  - Add device type dropdown options: All, Scale (地磅), Camera (摄像头), LPR (车牌识别), Sound (音响), Printer (打印机)
  - Add status dropdown options: All, Online (在线), Offline (离线), Busy (忙碌)
  - Add ClientId text input with placeholder
  - Add Search button with Bootstrap icon (`bi bi-search`)

- [ ] 4.4 Implement table UI
  - Use Bootstrap table classes (`table`, `table-hover`, `table-responsive`)
  - Add table header with column names
  - Add table body with `id="deviceStatusTableBody"`
  - Add loading row: `<td colspan="5">加载中...</td>`
  - Add pagination nav with `id="pagination"`

- [ ] 4.5 Add SignalR connection status indicator
  - Add badge element for connection status (green ● for connected, red ● for disconnected)
  - Add "Last Heartbeat" timestamp display
  - Position in card title area

## 5. Frontend JavaScript - Query Logic

- [ ] 5.1 Add jQuery document ready handler
  - Wrap all JavaScript code in `$(document).ready()` function
  - Initialize global variables: currentPage, pageSize, totalCount

- [ ] 5.2 Implement `loadDeviceStatusList()` function
  - Build request object with current filters and pagination
  - Call `GET /api/app/device-status/get-list` with `$.ajax()`
  - Handle success: call `renderTable()` and `renderPagination()`
  - Handle error: show error alert with message from response
  - Show/hide loading overlay

- [ ] 5.3 Implement `renderTable(items)` function
  - Clear existing table body (`$('#deviceStatusTableBody').empty()`)
  - Handle empty items case: show "暂无数据" row
  - Loop through items and append rows to table
  - Use `getStatusBadge(status)` to get status HTML
  - Use `getDeviceTypeLabel(deviceType)` to get device type label
  - Use `formatDateTime(timestamp)` to format time

- [ ] 5.4 Implement `renderPagination()` function
  - Calculate total pages from totalCount and pageSize
  - Add "Previous" button (disabled if on first page)
  - Add page number buttons (highlight current page)
  - Add "Next" button (disabled if on last page)
  - Add total count info text

- [ ] 5.5 Implement `getStatusBadge(status)` helper function
  - Return green badge (`bg-success`) for "Online"
  - Return red badge (`bg-danger`) for "Offline"
  - Return yellow badge (`bg-warning`) for "Busy"
  - Include emoji: 🟢、🔴、🟡

- [ ] 5.6 Implement `getDeviceTypeLabel(deviceType)` helper function
  - Return localized labels: "地磅 (Scale)" for "Scale", etc.

- [ ] 5.7 Implement `formatDateTime(timestamp)` helper function
  - Parse timestamp to Date object
  - Return "刚刚" if within 1 minute
  - Return "X分钟前" if within 1 hour
  - Return full datetime string otherwise

- [ ] 5.8 Implement filter form submit handler
  - Bind `$('#filterForm').on('submit', function(e) { ... })`
  - Prevent default form submission
  - Update current filter values from form inputs
  - Reset currentPage to 1
  - Call `loadDeviceStatusList()`

- [ ] 5.9 Implement pagination click handlers
  - Bind click event to page links
  - Update currentPage from clicked page number
  - Call `loadDeviceStatusList()`

## 6. Frontend SignalR Integration

- [ ] 6.1 Add SignalR JavaScript library reference
  - Add CDN script: `https://cdn.jsdelivr.net/npm/@microsoft/signalr@latest/dist/browser/signalr.min.js`
  - Place in `@section Scripts` block

- [ ] 6.2 Initialize SignalR connection
  - Create connection: `new signalR.HubConnectionBuilder().withUrl("/hubs/devicestatus").withAutomaticReconnect().build()`
  - Add logging: `.configureLogging(signalR.LogLevel.Information)`

- [ ] 6.3 Subscribe to device type updates
  - Define device types array: `["Scale", "Camera", "LPR", "Sound", "Printer"]`
  - Loop through device types and call `connection.invoke("SubscribeDeviceUpdates", deviceType)`
  - Handle subscription errors with console error logging

- [ ] 6.4 Handle "DeviceStatusUpdate" event
  - Register handler: `connection.on("DeviceStatusUpdate", (message) => { ... })`
  - Call `updateDeviceStatusRow(message)` to update table
  - Call `updateLastHeartbeat(message.timestamp)` to update heartbeat display

- [ ] 6.5 Implement `updateDeviceStatusRow(message)` function
  - Generate row ID: `device-${message.clientId}-${message.deviceType}`
  - Check if row exists in table
  - If exists: update row data using `updateRowData(row, message)`
  - If not exists: create new row using `createDeviceStatusRow(message)` and append to table

- [ ] 6.6 Implement `createDeviceStatusRow(message)` function
  - Build table row HTML with message data
  - Use helper functions for status badge, device type label, time formatting
  - Return jQuery object for the row

- [ ] 6.7 Implement `updateRowData(row, message)` function
  - Find cells by index or class
  - Update status cell with new status badge
  - Update time cell with formatted timestamp
  - Update additional data cell

- [ ] 6.8 Implement `updateLastHeartbeat(timestamp)` function
  - Format timestamp to relative time ("刚刚", "X秒前")
  - Update `#lastHeartbeat` element text
  - Store last heartbeat time for connection status indicator

- [ ] 6.9 Handle SignalR lifecycle events
  - Handle `connection.start()` success: log "SignalR 连接成功", call `loadDeviceStatusList()`
  - Handle `connection.start()` failure: log error, show connection status as disconnected
  - Handle reconnection events: log reconnecting, update connection status indicator

- [ ] 6.10 Update connection status indicator
  - Create function to update status badge based on connection state
  - Green badge (`bg-success`) for connected
  - Red badge (`bg-danger`) for disconnected
  - Yellow badge (`bg-warning`) for reconnecting
  - Update badge text: "● 实时更新", "● 连接断开", "● 重连中"

## 7. Error Handling and Edge Cases

- [ ] 7.1 Handle query API errors
  - Add error handler in `loadDeviceStatusList()` AJAX call
  - Display error message using `alert()` or Bootstrap alert
  - Hide loading overlay on error

- [ ] 7.2 Handle SignalR connection errors
  - Add catch block for `connection.start()`
  - Log error to console
  - Update connection status indicator to "disconnected"
  - Implement fallback polling (optional): `setInterval` to query every 30 seconds

- [ ] 7.3 Handle empty query results
  - In `renderTable()`, check if items array is empty
  - Show "暂无数据" row with colspan=5
  - Hide pagination control

- [ ] 7.4 Handle invalid filter inputs
  - Add client-side validation for filter inputs (optional)
  - Server-side validation in `DeviceStatusQueryService`
  - Return 400 Bad Request for invalid device types or status values

## 8. Testing

- [ ] 8.1 Test backend query service
  - Create unit test for `DeviceStatusQueryService.GetDeviceStatusListAsync`
  - Test with no filters (return all devices)
  - Test with ClientId filter
  - Test with DeviceType filter
  - Test with Status filter
  - Test with pagination (SkipCount, MaxResultCount)
  - Test with empty cache (return empty list)

- [ ] 8.2 Test SignalR integration
  - Start MaterialClient and simulate device status upload
  - Open device management page in browser
  - Verify SignalR connection establishes
  - Verify device status appears in table
  - Change device status in MaterialClient
  - Verify table updates in real-time
  - Disconnect network and verify reconnection behavior

- [ ] 8.3 Test UI interactions
  - Test filter form submit (all combinations of filters)
  - Test pagination navigation
  - Test connection status indicator (connect, disconnect, reconnect)
  - Test browser compatibility (Chrome, Firefox, Edge)

- [ ] 8.4 Performance testing
  - Load 100+ device statuses and measure query response time
  - Verify query < 500ms for 100 devices
  - Test real-time update latency (< 1 second)

## 9. Assumption Validation (Guess Governance)

根据 proposal.md 中的假设验证计划，以下任务用于验证关键假设：

### 9.1 Priority P0 Assumptions (Must Validate)

- [ ] 9.1.1 Validate A-06: SignalR Push Performance
  - **Assumption**: 实时更新使用 SignalR Push 模式（非轮询）
  - **Validation Method**: 性能测试
  - **Success Criteria**: 
    - 模拟 100 设备同时上报状态
    - P95 推送延迟 < 1s
    - 无消息丢失
  - **Document Result**: 在 proposal.md 的 A-06 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

- [ ] 9.1.2 Validate A-07: Cache Data Reliability
  - **Assumption**: 设备状态查询基于分布式缓存，不启用数据库持久化
  - **Validation Method**: 数据可靠性评估
  - **Success Criteria**:
    - MaterialClient 重启/重连后状态可恢复
    - 缓存服务重启后数据可重新同步
  - **Document Result**: 在 proposal.md 的 A-07 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

### 9.2 Priority P1 Assumptions (Should Validate)

- [ ] 9.2.1 Validate A-01: Device Type Coverage
  - **Assumption**: 设备类型固定为 5 种：Scale, Camera, LPR, Sound, Printer
  - **Validation Method**: 用户反馈收集
  - **Success Criteria**:
    - 收集实际使用的设备类型
    - 确认是否需要新增设备类型
  - **Document Result**: 在 proposal.md 的 A-01 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

- [ ] 9.2.2 Validate A-02: Pagination Size
  - **Assumption**: 单页默认显示 50 条设备状态记录
  - **Validation Method**: 用户使用反馈
  - **Success Criteria**:
    - 用户对分页大小无抱怨
    - 可通过配置调整
  - **Document Result**: 在 proposal.md 的 A-02 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

- [ ] 9.2.3 Validate A-04: Status Indicator Readability
  - **Assumption**: 状态显示使用文字+颜色标识：🟢 Online、🔴 Offline、🟡 Busy
  - **Validation Method**: 用户可读性测试
  - **Success Criteria**:
    - ≥ 90% 用户正确识别状态含义
    - 无混淆或误解
  - **Document Result**: 在 proposal.md 的 A-04 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

### 9.3 Priority P2 Assumptions (Can Validate During Use)

- [ ] 9.3.1 Validate A-03: UI Consistency
  - **Assumption**: 使用 Bootstrap 5.3.3 作为 UI 组件库
  - **Validation Method**: UI 一致性验证
  - **Success Criteria**:
    - 与 Project 页面视觉一致
    - 设计审核通过
  - **Document Result**: 在 proposal.md 的 A-03 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

- [ ] 9.3.2 Validate A-05: Cache Expiration Time
  - **Assumption**: 缓存过期时间为 24 小时
  - **Validation Method**: 运维监控
  - **Success Criteria**:
    - 无内存泄漏
    - 缓存命中率 > 80%
  - **Document Result**: 在 proposal.md 的 A-05 假设注册表中记录结果
  - **Disposition**: keep / replace / remove

### 9.4 Document Validation Results

- [ ] 9.4.1 Update proposal.md Assumption Register
  - For each validated assumption (A-01 through A-07):
    - Update "Result" column with actual validation outcome
    - Update "Disposition" column: keep / replace / remove
    - Set validation date in "Due" column

- [ ] 9.4.2 Calculate Updated Metrics
  - Update "Validation Coverage" in proposal.md
  - Recalculate "Guess Ratio" if any assumptions were removed
  - Document any lessons learned for future changes

### 9.5 Decisions Needed Follow-up

- [ ] 9.5.1 Follow up on D-01: Historical Records
  - **Decision Needed**: 是否需要设备状态历史记录查询功能？
  - If YES: Plan subsequent change to activate DeviceStatusLog entity
  - If NO: Document decision and close D-01

- [ ] 9.5.2 Follow up on D-02: Alerting/Notifications
  - **Decision Needed**: 是否需要设备离线告警通知功能？
  - If YES: Plan subsequent change to integrate ABP Notification system
  - If NO: Document decision and close D-02

- [ ] 9.5.3 Follow up on D-03: Multi-tenant Isolation
  - **Decision Needed**: 是否需要多租户设备隔离？
  - If YES: Plan subsequent change to add tenant filtering
  - If NO: Document decision and close D-03

- [ ] 9.5.4 Confirm D-04: SignalR Degradation Strategy
  - **Decision Needed**: SignalR 连接断开时的降级策略？
  - Current Design: 自动重连 + 降级为轮询（已实现）
  - Confirm this approach meets requirements
  - Document confirmation in proposal.md

- [ ] 9.5.5 Confirm D-05: Device Type Extensibility
  - **Decision Needed**: 设备类型的扩展机制？
  - Current Design: 硬编码 5 种设备类型（A-01）
  - If extensibility needed: Plan to move to configuration-driven approach
  - Document decision in proposal.md

## 10. Documentation and Polish

- [ ] 10.1 Add code comments to critical sections
  - Comment cache reading logic
  - Comment aggregation logic
  - Comment SignalR event handlers
  - Comment time formatting logic

- [ ] 10.2 Verify UI consistency with Project page
  - Compare card structure and styling
  - Compare button and form styling
  - Compare table and pagination styling
  - Ensure consistent use of Bootstrap classes

- [ ] 10.3 Update AGENTS.md (if needed)
  - No updates needed for this change (following existing patterns)

## 11. Deployment and Verification

- [ ] 11.1 Build and test locally
  - Run `dotnet build` to verify compilation
  - Run UrbanManagement application locally
  - Navigate to `/DeviceManagement/Index`
  - Verify page loads without errors
  - Test all features (filters, pagination, SignalR)

- [ ] 11.2 Prepare deployment checklist
  - Verify all new files are included in project
  - Verify no hardcoded localhost URLs
  - Verify SignalR hub URL is correct
  - Check appsettings.json for any required configuration

- [ ] 11.3 Deploy to test environment
  - Publish application: `dotnet publish -c Release`
  - Deploy to test server
  - Verify device management page is accessible
  - Test with MaterialClient sending real device status
  - Verify real-time updates work

- [ ] 11.4 Final verification
  - Confirm all tasks are complete
  - Confirm all acceptance criteria are met:
    - [ ] Page accessible at `/DeviceManagement/Index`
    - [ ] Query API returns correct device status data
    - [ ] Filters work correctly
    - [ ] SignalR real-time updates work
    - [ ] UI style matches Project page
    - [ ] Performance meets requirements (< 500ms for 100 devices)
