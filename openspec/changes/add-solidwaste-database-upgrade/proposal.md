## Why

The SolidWaste desktop startup rejects deployed databases that still store product fields in ExtraProperties. The current path skips migrations and can still enter the desktop, leaving queries and saves dependent on missing tables.

## What Changes

- Add a standalone SolidWaste database upgrade command that inspects a source and produces a verified SQLite copy at an explicit destination.
- Migrate historical SolidWaste values into product extensions and preserve original records, data and identifiers.
- Require current database schema for existing SolidWaste deployments before entering the desktop or starting devices.

## Capabilities

### New Capabilities
- `solidwaste-database-upgrade`: Offline inspection, upgrade and verification of supported SolidWaste SQLite files.

### Modified Capabilities
- `standard-solidwaste-app-isolation`: Existing SolidWaste schema readiness is checked before desktop startup.
- `standard-solidwaste-schema-isolation`: Historical fields can be copied through the offline upgrade.

## Impact

- MaterialClient adds an independently publishable executable and reuses the kernel and SolidWaste EF schema definitions.
- MaterialMonospec owns the change and requirements.
- Initial support covers the recognized kernel isolation baseline and known SolidWaste migration history. Production cutover is an explicit operator action.
