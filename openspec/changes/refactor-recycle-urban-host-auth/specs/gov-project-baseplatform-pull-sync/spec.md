## MODIFIED Requirements

### Requirement: Sync validates product code at boundary without persisting

UrbanManagement SHALL accept remote catalog `productCode` values **5001** (`ProductCode.Urban`) and **5020** (`ProductCode.Recycle`) at the pull-sync boundary. Accepted items SHALL be persisted such that Admin can distinguish Urban vs Recycle authorizations（含持久化产品码或等价区分字段）。其它 `productCode` SHALL 被跳过。

#### Scenario: Urban product code accepted

- **WHEN** pull sync receives a catalog item with `productCode = 5001`
- **THEN** the sync SHALL proceed with insert or full catalog-field update processing for that item
- **AND** the local record SHALL be distinguishable as Urban（5001）

#### Scenario: Recycle product code accepted

- **WHEN** pull sync receives a catalog item with `productCode = 5020`
- **THEN** the sync SHALL proceed with insert or update for that Recycle authorization
- **AND** SHALL NOT replace or delete a coexisting Urban（5001） authorization for the same project identity when both exist

#### Scenario: Unsupported product code is skipped

- **WHEN** pull sync receives a catalog item with `productCode` not equal to `5001` or `5020`
- **THEN** the sync SHALL NOT insert or update a project authorization for that item
- **AND** SHALL log a warning including `proId` and the unexpected `productCode`
