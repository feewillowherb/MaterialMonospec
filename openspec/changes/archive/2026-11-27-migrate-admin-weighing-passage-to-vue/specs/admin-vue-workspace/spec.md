## ADDED Requirements

### Requirement: Inline two-photo preview column and authenticated attachment image endpoint
The weighing record, weighing approval, checkpoint passage, and finished-product passage pages SHALL remove the legacy `查看照片` action button and standalone photo dialogs, and instead render up to 2 lazy-loaded photo thumbnails side by side in a single `现场照片` column (`InlinePhotoPair`) with click-to-zoom lightbox preview and missing-image placeholders. `UrbanManagement.Admin` SHALL serve attachment images via an authenticated `GET /api/admin/attachments/{id:guid}` endpoint with private caching.

#### Scenario: Operator verifies weighing and passage records inline without opening dialogs
- **WHEN** the operator loads the weighing record, weighing approval, checkpoint passage, or finished-product passage list
- **THEN** each row SHALL render up to 2 lazy-loaded thumbnails from `previewPhotos` URLs in the `现场照片` column
- **AND** clicking a thumbnail SHALL open the lightbox preview allowing switching between the row's images
- **AND** the row actions column SHALL NOT render a `查看照片` button

#### Scenario: Missing or unreadable photo renders graceful placeholder
- **WHEN** a record has fewer than 2 photos or an image returns HTTP `404`
- **THEN** the missing slot SHALL render a muted dashed `无图` placeholder without broken image icons

### Requirement: Weighing record, weighing approval, and passage list views in Vue 3
The Vue 3 Admin workspace SHALL provide `/urban/weighing`, `/urban/weighing-approval`, `/urban/checkpoint-passage`, and `/urban/finished-product-passage` using `OpsDataTable`, `ProjectRemoteSelect`, `DateRangeShortcuts`, and URL Query filter synchronization, while preserving weighing approval editing, photo replacement upload, edit history timeline, and sync reset actions.

#### Scenario: Operator filters by long project name and date shortcuts
- **WHEN** the operator selects a long project name via `ProjectRemoteSelect` or clicks a quick date shortcut (`今日`, `近3天`, `近7天`)
- **THEN** the list SHALL reload with the chosen filters and persist the filter state in the URL query string

#### Scenario: Operator approves an anomalous weighing record
- **WHEN** the operator opens the approval dialog on `/urban/weighing-approval`, edits plate/weight or selects a replacement LPR image, and submits
- **THEN** the backend approval endpoint SHALL be invoked and the table SHALL refresh to reflect the updated status
