## ADDED Requirements

### Requirement: Existing SolidWaste database must be ready before desktop startup
The SolidWaste host SHALL verify existing database readiness before desktop initialization. An existing populated database requiring schema or legacy field migration SHALL be upgraded through the standalone tool. Fresh installations MAY initialize their schemas at startup.

#### Scenario: Existing database requires upgrade
- **WHEN** the SolidWaste desktop is pointed at an existing database missing the required migration history or schema
- **THEN** the host SHALL stop before desktop initialization and report the database path and upgrade command
