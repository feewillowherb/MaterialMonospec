## ADDED Requirements

### Requirement: Stored attachment paths are separator-neutral

`AttachmentFile.LocalPath` values produced by `StoragePathResolver.GetRelativeStoredPath` SHALL use `/` as the separator. `StoragePathResolver.ResolveStoredPath` SHALL accept relative paths using either `\` or `/` and resolve them under the storage root using the operating system's separator, so that records written on Windows remain readable on Linux. Rooted stored paths SHALL keep their existing behavior.

#### Scenario: Legacy backslash path resolves on Linux

- **WHEN** the stored `LocalPath` is `GDXS001\abc.jpg` and the service runs on Linux with storage root `/app/Uploads`
- **THEN** `ResolveStoredPath` SHALL return `/app/Uploads/GDXS001/abc.jpg`

#### Scenario: New relative path uses forward slash

- **WHEN** a file is saved at `{storageRoot}{sep}GDXS001{sep}abc.jpg` on any operating system
- **THEN** `GetRelativeStoredPath` SHALL return `GDXS001/abc.jpg`

#### Scenario: Windows behavior unchanged

- **WHEN** the service runs on Windows and the stored `LocalPath` is `GDXS001/abc.jpg` or `GDXS001\abc.jpg`
- **THEN** `ResolveStoredPath` SHALL return the same absolute file path under the storage root
