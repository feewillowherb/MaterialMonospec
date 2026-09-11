## ADDED Requirements

### Requirement: Shared multi-image preview with left-click enlarge

UrbanManagement Blazor photo viewers (weighing list/approval dialogs, passage photo dialogs, and any shared preview component introduced by this change) SHALL support displaying multiple images for a record and SHALL open an enlarged view when the operator left-clicks a thumbnail or preview image.

#### Scenario: Multiple images listed

- **WHEN** a record has more than one viewable image
- **THEN** the photo UI SHALL present all of those images (not only the first per attach type)
- **AND** the operator SHALL be able to see each image without leaving the dialog

#### Scenario: Left-click opens large image

- **WHEN** the operator left-clicks a preview/thumbnail image
- **THEN** the system SHALL open a large-image view (lightbox or equivalent modal)
- **AND** the operator SHALL be able to close it and return to the multi-image dialog

#### Scenario: Single image still works

- **WHEN** a record has exactly one viewable image
- **THEN** the same multi-image UI and left-click enlarge behavior SHALL still apply
