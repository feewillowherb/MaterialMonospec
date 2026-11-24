## ADDED Requirements

### Requirement: Receiving panel selects the vehicle plate

The receiving panel SHALL show the plate of the transport row. For a row that is not received, the panel SHALL let the user replace the plate only by searching and selecting a vehicle of the current project. The panel SHALL NOT accept a typed plate that does not match a listed vehicle. For a received row, the panel SHALL show the plate as read-only.

#### Scenario: Panel shows the current plate

- **WHEN** the user opens the receiving panel of a transport row
- **THEN** the panel shows the row's plate

#### Scenario: User searches vehicles

- **WHEN** the user starts a plate change and types part of a plate
- **THEN** the options are the enabled vehicles of the current project whose plate contains the text
- **AND** the panel shows no other options

#### Scenario: Received row keeps its plate

- **WHEN** the user opens the receiving panel of a received row
- **THEN** the plate is shown as read-only and there is no plate change action

### Requirement: Saving a new plate applies the selected vehicle

`PUT /api/transports/{id}` SHALL accept an optional plate. When the plate differs from the stored one, the service SHALL require an enabled vehicle with that plate in the same project, store the new plate, and refresh the tare, net, owner and transporter snapshots from that vehicle. The net weight SHALL be recomputed from the stored gross weight. When the plate is missing from the request or unchanged, the service SHALL leave the plate and its snapshots unchanged.

#### Scenario: Vehicle exists

- **WHEN** the user saves the receiving panel with a plate that belongs to an enabled vehicle of the project
- **THEN** the transport row shows the new plate
- **AND** tare, net and transporter come from that vehicle

#### Scenario: Vehicle is unknown

- **WHEN** the request carries a plate that no enabled vehicle of the project has
- **THEN** the service rejects the save with `RECYCLE:VEHICLE`
- **AND** the transport row keeps its previous plate and snapshots

#### Scenario: Plate unchanged

- **WHEN** the user saves the receiving panel without changing the plate
- **THEN** the plate and its snapshots are unchanged

#### Scenario: Row already received

- **WHEN** a request carries a different plate for a row that already has `ReceivingTime`
- **THEN** the service rejects the save with `RECYCLE:TRANSPORT_RECEIVED`

### Requirement: Vehicle search can exclude disabled vehicles

`GET /api/vehicles` SHALL accept an `enabledOnly` flag. When it is true, the result SHALL contain only enabled vehicles of the current project. Without the flag, the result SHALL be unchanged.

#### Scenario: Enabled vehicles only

- **WHEN** `GET /api/vehicles` is called with `enabledOnly=true`
- **THEN** every returned vehicle is enabled

#### Scenario: Vehicle page is unchanged

- **WHEN** `GET /api/vehicles` is called without `enabledOnly`
- **THEN** enabled and disabled vehicles are returned as before
