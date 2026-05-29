# Legacy API Compatibility

## Purpose

Provides backward compatibility with the existing government client API, allowing legacy clients to continue functioning without modification while the new urban management system is deployed. (TBD: expand with migration strategy details)

## Requirements

### Requirement: Legacy API endpoint accepts old GovClient POST requests
The system SHALL provide an endpoint at `POST /Api/Post` that accepts JSON payloads from the unmodified legacy GovClient. The endpoint SHALL use `[Route("Api/[action]")]` routing and accept `[FromBody] JsonElement` or a strongly-typed `GovRequestWeightDto` with `[JsonPropertyName]` attributes matching the old camelCase field names (`carNo`, `carColor`, `carNoColor`, `buildLicenseNo`, `fdBuildLicenseNo`, `inOutType`, `equipmentNumber`, `equipmentType`, `grossWeight`, `tareWeight`, `snapTime`, `snapImages`, `carType`, `deviceID`, `siteType`, `goodsWeight`).

#### Scenario: Successful data submission from legacy GovClient
- **WHEN** a POST request is sent to `/Api/Post` with a valid `mGovRequestWeight` JSON body containing a matching access code and at least one `snapImages` Base64 entry
- **THEN** the system SHALL persist the data and respond with `{ "success": true, "msg": "成功", "code": 200, "data": null }`

#### Scenario: Missing access code
- **WHEN** a POST request is sent to `/Api/Post` with both `buildLicenseNo` and `fdBuildLicenseNo` empty or null
- **THEN** the system SHALL respond with `{ "success": false, "msg": "数据没有接入码，请检查填写是否正确", "code": -1 }`

#### Scenario: Access code not found
- **WHEN** a POST request is sent with an access code that does not match any `GovProject` record
- **THEN** the system SHALL respond with `{ "success": false, "msg": "对接码[{code}]未接入，请联系管理员", "code": -1 }`

### Requirement: Dual access-code validation
The system SHALL validate access codes using a priority-based dual strategy. If `fdBuildLicenseNo` is non-empty, the system SHALL first query `GovProject` by `FdBuildLicenseNo` and, if matched, use the stored `BuildLicenseNo` value. If only `buildLicenseNo` is provided, the system SHALL query by `BuildLicenseNo` directly. If both are provided, `fdBuildLicenseNo` takes priority.

#### Scenario: Validation via fdBuildLicenseNo
- **WHEN** the request contains a non-empty `fdBuildLicenseNo` matching a `GovProject.FdBuildLicenseNo`
- **THEN** the system SHALL resolve the project, assign the project's `BuildLicenseNo` to the record, and set `ProId` to the project's ID

#### Scenario: Validation via buildLicenseNo only
- **WHEN** the request contains only `buildLicenseNo` (fdBuildLicenseNo is empty) and it matches a `GovProject.BuildLicenseNo`
- **THEN** the system SHALL resolve the project and set `ProId` to the project's ID

#### Scenario: fdBuildLicenseNo overrides buildLicenseNo
- **WHEN** both `fdBuildLicenseNo` and `buildLicenseNo` are non-empty and `fdBuildLicenseNo` matches
- **THEN** the system SHALL use the fdBuildLicenseNo match and ignore the provided `buildLicenseNo`

### Requirement: Legacy response format compliance
The system SHALL return responses in the exact `ApiResultDto` format: `{ "success": bool, "msg": string, "code": int, "data": object|null }`. The `code` field MUST be `200` for success and `-1` for failure. The JSON property names SHALL be camelCase.

#### Scenario: Success response format
- **WHEN** a legacy API call succeeds
- **THEN** the response body SHALL contain `success: true`, `msg: "成功"`, `code: 200`, `data: null`

#### Scenario: Failure response format
- **WHEN** a legacy API call fails for any reason (validation, database error, etc.)
- **THEN** the response body SHALL contain `success: false`, a descriptive `msg` string, and `code: -1`

### Requirement: grossWeight overrides goodsWeight
When `grossWeight` is greater than 0, the system SHALL use the `grossWeight` value as the `GoodsWeight` for the `GovSyncData` record, regardless of any `goodsWeight` value provided in the request.

#### Scenario: grossWeight present and positive
- **WHEN** the request has `grossWeight: 5000` and `goodsWeight: "3000"`
- **THEN** the persisted `GovSyncData.GoodsWeight` SHALL be `"5000"`

#### Scenario: grossWeight is zero
- **WHEN** the request has `grossWeight: 0` and `goodsWeight: "3000"`
- **THEN** the persisted `GovSyncData.GoodsWeight` SHALL be `"3000"`

### Requirement: Source data preservation
The system SHALL store the original request JSON in `GovSyncData.SourceData` with the `snapImages` field cleared (empty array or null). The original `snapImages` Base64 data SHALL NOT be stored in `SourceData`.

#### Scenario: Source data excludes images
- **WHEN** a legacy request with `snapImages: ["base64data1", "base64data2"]` is processed
- **THEN** the `GovSyncData.SourceData` SHALL contain the original JSON structure but with `snapImages` set to an empty array or null
