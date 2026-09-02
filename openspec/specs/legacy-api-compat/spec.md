# Legacy API Compatibility

## Purpose

Provides backward compatibility with the existing government client API, allowing legacy clients to continue functioning without modification while the new urban management system is deployed. (TBD: expand with migration strategy details)

## Requirements

### Requirement: Legacy API endpoint accepts old GovClient POST requests
The system SHALL provide an endpoint at `POST /Api/Post` that accepts JSON payloads from the unmodified legacy GovClient. The endpoint SHALL use `[Route("Api/[action]")]` routing and accept `[FromBody] JsonElement` or a strongly-typed `GovRequestWeightDto` with `[JsonPropertyName]` attributes matching the old camelCase field names (`carNo`, `carColor`, `carNoColor`, `buildLicenseNo`, `fdBuildLicenseNo`, `inOutType`, `equipmentNumber`, `equipmentType`, `grossWeight`, `tareWeight`, `snapTime`, `snapImages`, `carType`, `deviceID`, `siteType`, `goodsWeight`). While the endpoint is marked WIP and returns HTTP 501 without persistence, parsers MAY still accept `fdBuildLicenseNo` for wire compatibility.

#### Scenario: Missing access code
- **WHEN** a POST request is sent to `/Api/Post` with `buildLicenseNo` empty or null
- **THEN** the WIP handler SHALL respond without persisting data (HTTP 501 or equivalent WIP response per active legacy-api-compat WIP requirement)

#### Scenario: Access code not found
- **WHEN** a POST request would have been rejected for unknown access code under the former dual-code validator
- **THEN** the WIP handler SHALL respond without persisting data and MUST NOT query a removed `GovProject.FdBuildLicenseNo` column

### Requirement: Legacy response format compliance
The system SHALL return responses in the exact `ApiResultDto` format: `{ "success": bool, "msg": string, "code": int, "data": object|null }`. The `code` field MUST be `200` for success and `-1` for failure. The JSON property names SHALL be camelCase.

#### Scenario: Success response format
- **WHEN** a legacy API call succeeds
- **THEN** the response body SHALL contain `success: true`, `msg: "成功"`, `code: 200`, `data: null`

#### Scenario: Failure response format
- **WHEN** a legacy API call fails for any reason (validation, database error, etc.)
- **THEN** the response body SHALL contain `success: false`, a descriptive `msg` string, and `code: -1`
