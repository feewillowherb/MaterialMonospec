## REMOVED Requirements

### Requirement: Dual access-code validation
**Reason**: `GovProject.FdBuildLicenseNo` is removed (entity semantic initiative P1). Legacy endpoint remains WIP (501) per P0; Modern and future Legacy paths resolve projects by `BuildLicenseNo` only.
**Migration**: Clients and integrators MUST use `buildLicenseNo` matching `GovProject.BuildLicenseNo`. Inbound `fdBuildLicenseNo` in JSON MAY be present for wire compatibility but SHALL be ignored.

## MODIFIED Requirements

### Requirement: Legacy API endpoint accepts old GovClient POST requests
The system SHALL provide an endpoint at `POST /Api/Post` that accepts JSON payloads from the unmodified legacy GovClient. The endpoint SHALL use `[Route("Api/[action]")]` routing and accept `[FromBody] JsonElement` or a strongly-typed `GovRequestWeightDto` with `[JsonPropertyName]` attributes matching the old camelCase field names (`carNo`, `carColor`, `carNoColor`, `buildLicenseNo`, `fdBuildLicenseNo`, `inOutType`, `equipmentNumber`, `equipmentType`, `grossWeight`, `tareWeight`, `snapTime`, `snapImages`, `carType`, `deviceID`, `siteType`, `goodsWeight`). While the endpoint is marked WIP and returns HTTP 501 without persistence, parsers MAY still accept `fdBuildLicenseNo` for wire compatibility.

#### Scenario: Missing access code
- **WHEN** a POST request is sent to `/Api/Post` with `buildLicenseNo` empty or null
- **THEN** the WIP handler SHALL respond without persisting data (HTTP 501 or equivalent WIP response per active legacy-api-compat WIP requirement)

#### Scenario: Access code not found
- **WHEN** a POST request would have been rejected for unknown access code under the former dual-code validator
- **THEN** the WIP handler SHALL respond without persisting data and MUST NOT query a removed `GovProject.FdBuildLicenseNo` column
