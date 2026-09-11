## MODIFIED Requirements

### Requirement: Photo display limited to Lrp and UrbanPhoto

The Web photo view SHALL only display images classified as `AttachType.Lrp` (5) and `AttachType.UrbanPhoto` (6). Other attach types MUST NOT appear in the photo dialog. Within those types, **all** available images SHALL be shown (multi-image), subject to `urban-multi-image-lightbox`.

#### Scenario: Only Lrp and UrbanPhoto types rendered

- **WHEN** the photo dialog renders
- **THEN** only attachments of types Lrp and UrbanPhoto SHALL be eligible for display
- **AND** attachments of other types linked to the record SHALL be ignored for display

#### Scenario: Multiple images per type are shown

- **WHEN** a record has multiple attachments of the same eligible `AttachType`
- **THEN** the dialog SHALL display each of those images in the multi-image UI
- **AND** SHALL NOT hide extras beyond the first image of that type

#### Scenario: Left-click enlarge

- **WHEN** the operator left-clicks a displayed photo in the weighing photo dialog
- **THEN** large-image viewing SHALL follow `urban-multi-image-lightbox`
