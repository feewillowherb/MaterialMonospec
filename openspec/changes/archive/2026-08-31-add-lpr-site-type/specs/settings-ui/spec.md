## ADDED Requirements

### Requirement: Urban host can choose LPR site type; other hosts force scale

On an Urban host, add and edit LPR dialogs MUST let the user select site type among 地磅, 卡口, and 成品, and the settings LPR grid MUST show the selected type. On Standard, SolidWaste, Recycle, and any other non-Urban host, the UI MUST NOT allow changing site type; add and edit MUST result in scale (地磅), and save MUST persist scale for every LPR row in that session.

#### Scenario: Urban add or edit can select checkpoint

- **WHEN** the Urban settings host opens AddLprDialog to add or edit an LPR row
- **THEN** the dialog MUST present the three site types
- **AND** confirming with 卡口 MUST store checkpoint on that row

#### Scenario: Non-Urban add cannot leave scale

- **WHEN** a non-Urban host opens AddLprDialog to add an LPR row
- **THEN** site type MUST be scale
- **AND** the user MUST NOT be able to persist 卡口 or 成品 from that dialog

#### Scenario: Non-Urban save coerces stored rows to scale

- **WHEN** a non-Urban host saves settings that contain LPR rows whose JSON site type is not scale
- **THEN** persisted LPR rows MUST all be scale after that save
