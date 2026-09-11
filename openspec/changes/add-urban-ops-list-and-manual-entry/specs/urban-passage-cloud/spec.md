## MODIFIED Requirements

### Requirement: Checkpoint page and finished-product page

UrbanManagement SHALL provide a checkpoint list page and a finished-product list page, not mixed into weighing approval. Each page MUST filter the passage entity by that `PassageSource`. Columns MUST include, **in order starting with** 施工单位 and 项目, then plate (store「无」shown as「未识别」), plate color, vehicle type, in/out, site type, captured time, sync status badge, sync time, large-photo view action, and other operations such as reset sync when enabled. Pages MUST NOT show weight or weighing approval actions. UI MUST call ApplicationService only, never Repository or DbContext.

#### Scenario: Checkpoint page filter

- **WHEN** an operator opens the checkpoint page
- **THEN** the list MUST contain only checkpoint passage rows
- **AND** MUST NOT list finished-product or weighing rows

#### Scenario: First columns are 施工单位 and 项目

- **WHEN** an operator opens the checkpoint or finished-product page
- **THEN** the first column MUST be 施工单位 and the second MUST be 项目
- **AND** 施工单位 MUST come from the related project's `ShigongUnitName` when available
- **AND** 项目 MUST come from the passage `ProName` when available
