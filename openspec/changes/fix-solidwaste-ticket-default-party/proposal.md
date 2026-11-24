## Why

The SolidWaste ticket can leave the disposal site's party field blank when a waybill lacks a Shipper value. Restore the historical site name for this presentation case.

## What Changes

- Use the historical site name for missing or whitespace-only Shipper values in print and preview.
- Preserve stored site names and the supplier's party field.

## Capabilities

### Modified Capabilities
- `standard-solidwaste-code-boundaries`: Apply the existing ticket party mapping with the historical site fallback.

## Impact

- MaterialClient SolidWaste ticket projection and regression tests.
