## MODIFIED Requirements

### Requirement: Product logic stays outside the common weighing kernel

SolidWaste four-field persistence and export implementation SHALL belong to the SolidWaste product module. Common weighing orchestration SHALL use only product-neutral lifecycle contracts for required product writes. UI-facing product contracts MAY live in a separate implementation-free contract library. Presentation persistence SHALL go through Services. Standard historical SolidWaste reads SHALL remain available through a read-only adapter without initializing the SolidWaste runtime.

#### Scenario: Standard reads historical SolidWaste rows

- **WHEN** Standard queries existing mixed-mode history with available SolidWaste extensions
- **THEN** existing history and its product-field display SHALL remain readable
- **AND** no SolidWaste migration or product write SHALL occur

#### Scenario: SolidWaste export reads authoritative fields

- **WHEN** a SolidWaste waybill is exported or printed
- **THEN** four product fields SHALL come from the extension data, with the site party display default applied to print and preview when Shipper is blank
- **AND** the net-display flag SHALL come from the canonical ExtraProperties accessor

#### Scenario: Ticket shows the site party when Shipper is blank

- **WHEN** a SolidWaste waybill has a missing, empty, or whitespace-only Shipper and is previewed or printed
- **THEN** the ticket SHALL display 东部资源化处置点 as the receiving unit for receipt and as the shipping unit for dispatch
- **AND** the other party SHALL retain the supplier name

#### Scenario: Ticket preserves a stored site party

- **WHEN** a SolidWaste waybill with a nonblank Shipper is previewed or printed
- **THEN** the site party SHALL show that stored value
