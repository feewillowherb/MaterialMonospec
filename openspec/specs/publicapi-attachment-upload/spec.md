# publicapi-attachment-upload Specification

## Purpose
TBD - created by archiving change refactor-client-oss-upload-to-publicapi. Update Purpose after archive.
## Requirements
### Requirement: JWT-authenticated multipart attachment upload endpoint

`FdSoft.Material.PublicApi` SHALL expose `POST /api/File/UploadAttachment` accepting `multipart/form-data` with fields `File` (`IFormFile`), `BizId` (`string`), `BizType` (`int`), `FileName` (`string`), and optional `AddDate` / `UpdateDate`. The endpoint SHALL require valid JWT Bearer authentication (`[Authorize]`) without introducing any additional API key, and SHALL NOT allow anonymous access.

#### Scenario: Authenticated upload succeeds
- **WHEN** a client sends a valid `multipart/form-data` request to `POST /api/File/UploadAttachment` with a valid JWT Bearer token, non-empty `File`, `BizId`, supported `BizType` (`1`, `2`, or `3`), and `FileName`
- **THEN** the server SHALL accept the request, upload the stream to Aliyun OSS using server-side `ALIYUN_OSS` configuration, persist or update the `MaterialAttaches` record, and return HTTP 200 with `success = true` and `data` containing `FileId`, `Bucket`, and `BucketKey`

#### Scenario: Unauthenticated request is rejected
- **WHEN** a client calls `POST /api/File/UploadAttachment` without a valid JWT Bearer token
- **THEN** the server SHALL reject the request with HTTP 401 Unauthorized
- **AND** SHALL NOT upload to OSS or modify `MaterialAttaches`

#### Scenario: Invalid parameters or oversized file rejected
- **WHEN** a request omits `File`, `BizId`, or `FileName`, supplies an unsupported `BizType`, or exceeds the configured `AttachmentUpload:MaxFileSizeBytes` limit (default 5MB)
- **THEN** the server SHALL reject the request with an error response and SHALL NOT upload to OSS or modify `MaterialAttaches`

### Requirement: Server-managed OSS storage without local disk persistence

`FdSoft.Material.PublicApi` SHALL stream uploaded attachment content directly in memory to Aliyun OSS using server-side `ALIYUN_OSS` configuration (`bucketName`, `REGIONID`, `KEY`, `SECRET`) and SHALL NOT persist uploaded image files to local server disk. The server SHALL skip global `context.Request.EnableBuffering()` for `/api/File/UploadAttachment` and SHALL generate `Bucket` and `BucketKey` on the server side rather than trusting client-supplied OSS coordinates.

#### Scenario: No local image file created on server
- **WHEN** `POST /api/File/UploadAttachment` processes an uploaded image
- **THEN** the server SHALL NOT write any business image file or temporary image copy to application local directories
- **AND** the middleware pipeline SHALL skip `EnableBuffering()` for that route

#### Scenario: Server determines Bucket and BucketKey
- **WHEN** the client uploads a file with `BizId`, `BizType = 3` (`TicketPhoto`), and `FileName` without supplying `Bucket` or `BucketKey`
- **THEN** the server SHALL use the configured `ALIYUN_OSS:bucketName` and generate a `BucketKey` under `PhotoPiaoJu/{yyyy}/{MM}/{dd}/` (or `PhotoJianKong/{yyyy}/{MM}/{dd}/` for `BizType = 1` or `2`)

### Requirement: Overwrite semantics on duplicate attachment key

When `POST /api/File/UploadAttachment` receives an upload whose `(BizId, BizType, FileName)` already exists in `MaterialAttaches`, the server SHALL overwrite the OSS object (reusing the existing non-empty `BucketKey` when present) and update the existing `MaterialAttaches` record's metadata (`FileSize`, `UpdateDate`, `UpdateTime`, `DeleteStatus = 0`) instead of creating duplicate rows.

#### Scenario: Re-uploading an existing attachment overwrites OSS and updates row
- **WHEN** a client uploads a new image with the same `(BizId, BizType, FileName)` as an existing `MaterialAttaches` record
- **THEN** the server SHALL overwrite the OSS object at the existing `BucketKey`
- **AND** SHALL update the existing `MaterialAttaches` row without inserting a duplicate row or `Compression_` companion row

### Requirement: Concurrency throttling to protect daytime core APIs

`FdSoft.Material.PublicApi` SHALL enforce a configurable concurrency limit (`AttachmentUpload:MaxConcurrentUploads`, default 12) on `POST /api/File/UploadAttachment` using non-blocking slot acquisition. When the concurrency limit is reached, the server SHALL immediately return HTTP `429 Too Many Requests` without queuing or blocking core business endpoints.

#### Scenario: Excess concurrent uploads receive HTTP 429
- **WHEN** the number of in-flight `POST /api/File/UploadAttachment` requests reaches `MaxConcurrentUploads` and another upload request arrives
- **THEN** the server SHALL immediately respond with HTTP 429 Too Many Requests
- **AND** SHALL NOT queue the request or degrade latency of non-upload endpoints

### Requirement: Legacy attachment metadata endpoints retained for backward compatibility

`FdSoft.Material.PublicApi` SHALL retain `POST /api/File/UpdateAttaches` and `POST /api/File/AddAttaches` with their existing anonymous-compatible behavior while older `MaterialClient` versions remain deployed. `[AllowAnonymous]` SHALL be scoped to legacy actions rather than the `FileController` class so it does not override `[Authorize]` on `UploadAttachment`.

#### Scenario: Legacy client still updates attachment metadata
- **WHEN** an older `MaterialClient` calls `POST /api/File/UpdateAttaches`
- **THEN** the server SHALL continue processing the request with unchanged behavior

