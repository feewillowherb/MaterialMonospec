## ADDED Requirements

### Requirement: SolidWaste detail reads materialize extension data in the service
The SolidWaste weighing detail service SHALL finish reading the extension inside an active unit of work and return the materialized fields to its caller.

#### Scenario: Open and reload a saved weighing record
- **WHEN** the caller opens a weighing record detail with existing product fields or reloads it after editing
- **THEN** the service SHALL return the persisted extension fields without requiring an ambient unit of work from the caller
