## ADDED Requirements

### Requirement: Approval API is Web-only

`IUrbanWeighingRecordAppService.ApproveAsync` and the conventional route `POST /api/app/urban-weighing-record/approve` SHALL be used only by UrbanManagement Web administrators (`WeighingApproval.razor` / `/weighing-approval`). MaterialClient.Urban MUST NOT call this API or any client-specific variant (e.g. `ApproveWeighingRecordAsync` with `ClientRecordId`).

#### Scenario: Web administrator approves via ApproveAsync

- **WHEN** an authenticated administrator submits approval from the Web UI with server record `id`, `plateNumber`, `totalWeight`, and optional `LrpReplacementBase64`
- **THEN** the system SHALL invoke `ApproveAsync` and update the server record in place

#### Scenario: MaterialClient does not call Approve API

- **WHEN** the operator completes client-side approval in MaterialClient.Urban
- **THEN** the client MUST NOT send HTTP requests to the Approve endpoint
- **AND** MUST sync corrected fields and attachments via `ReceiveWeighingRecordAsync` after `SyncStatus` becomes `Pending`

#### Scenario: Client-specific Approve Refit method not used

- **WHEN** `IUrbanManagementApi` (or equivalent Refit interface) is configured for MaterialClient.Urban
- **THEN** it SHALL NOT expose `ApproveWeighingRecordAsync` or map to the Approve endpoint for client approval flows
- **AND** client weighing sync SHALL continue to use `ReceiveWeighingRecordAsync` and attachment upload APIs only
