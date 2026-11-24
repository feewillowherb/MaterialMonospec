## ADDED Requirements

### Requirement: Transport rows without a plate stay visible

The transport list SHALL show 「—」 for a row whose `PlateNo` is empty, and the row SHALL keep its receive and view actions. A plate filter SHALL NOT return rows without a plate. The receiving panel SHALL show 「—」 for an empty plate until a vehicle is selected.

#### Scenario: Row without a plate is listed

- **WHEN** a transport row was received with an empty `PlateNumber`
- **THEN** the list shows 「—」 in the plate column
- **AND** the row offers 收货

#### Scenario: Plate filter skips rows without a plate

- **WHEN** the user searches the transport list by a plate
- **THEN** rows without a plate are not returned

#### Scenario: Receiving panel shows an empty plate

- **WHEN** the user opens the receiving panel of a row without a plate
- **THEN** the plate shows 「—」
