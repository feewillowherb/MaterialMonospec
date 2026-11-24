## Why

Weighing record 16452 has a SolidWaste extension, but opening and reloading its detail fails because a deferred repository query uses a disposed SolidWasteDbContext.

## What Changes

- Keep the work unit alive through the lookup and snapshot creation for SolidWaste weighing details.

## Capabilities

### Modified Capabilities
- `standard-solidwaste-code-boundaries`: Materialize the extension lookup in a service work unit.

## Impact

- MaterialClient SolidWaste extension reads.
- MaterialMonospec requirements and verification.
