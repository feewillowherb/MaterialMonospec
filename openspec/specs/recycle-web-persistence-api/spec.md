# recycle-web-persistence-api Specification

## Purpose
TBD - created by archiving change add-recycle-web-abp-module. Update Purpose after archive.
## Requirements
### Requirement: Business pages use Recycle application services

The vehicle, contract, daily-production, and transport pages on `UrbanManagement.Recycle` SHALL read and write through the existing Recycle application services for the bound SourceProId. The in-memory mock store SHALL be removed. Identifiers exchanged with the page SHALL be the persistent Guid values. Restarting the site SHALL leave previously saved rows available.

#### Scenario: Vehicle survives restart

- **WHEN** an authenticated user creates a vehicle and the site process starts again
- **THEN** the vehicle list returns that same vehicle
- **AND** the list does not come from the removed memory store

#### Scenario: Contract details stay with the contract service

- **WHEN** an authenticated user saves a contract with product lines and more than one transporter
- **THEN** the contract, its details, and its transporter rows are stored by the Recycle contract service
- **AND** the page reads those rows back from that service

### Requirement: Page weights stay exact

The pages SHALL display and submit kilogram values and their exact tonne conversion from the Recycle DTOs. A weight input SHALL NOT round or fix the value to one decimal place. Changing a vehicle tare or a company name SHALL NOT rewrite the tare, owner, transporter, or company snapshot already stored on a transport or contract row.

#### Scenario: Decimal kilograms remain decimal

- **WHEN** a user enters a tare of 1234.5 kilograms
- **THEN** the saved vehicle tare is 1234.5 kilograms
- **AND** the page shows the exact tonne conversion 1.2345

#### Scenario: Later catalog edit keeps the old snapshot

- **WHEN** a transport row has already stored a vehicle tare and the vehicle tare is edited afterward
- **THEN** the transport row keeps the tare stored at receiving time

### Requirement: Transport completion uses the same project

The transport page SHALL submit contract, material, and receiving completion through the Recycle transport service. The service SHALL reject a contract or material that belongs to another project. A missing or disabled vehicle SHALL leave tare and net empty. The page SHALL NOT mark a city-platform send as succeeded.

#### Scenario: Completion cannot cross projects

- **WHEN** a transport completion names a contract or material outside the bound SourceProId
- **THEN** the transport service rejects the completion
- **AND** the transport row does not gain that contract or material snapshot

#### Scenario: No external response is not success

- **WHEN** a user triggers a batch or platform report from the page and no external platform response has been recorded
- **THEN** the row sync status is not Succeeded

