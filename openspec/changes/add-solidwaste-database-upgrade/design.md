## Decisions

- Use the SQLite Backup API to stage an internally consistent copy beside a new output path. Validate the staged source before applying schema migrations. Publish using a same-directory move without replacement only after checks succeed.
- Keep shared schema definitions and immutable published migrations. Add a SolidWaste migration for the four legacy fields and use its EF history entry to distinguish a completed upgrade. Run migrations from SolidWaste desktop only when initializing a fresh or empty installation.
- Associate extensions by logical integer IDs with their existing unique indexes. Copy only nonempty string values. Keep existing values and fail on contradictory values before publication. Keep the source JSON and the net flag unchanged.
- Before publication check identity, migration IDs, required tables, SQLite integrity, and exact kernel weighing record and waybill ID sets. A failed staging migration may be retried from the source at the same destination.
- Run a checkout-local verification with the deployed recovery backup, with a staged destination outside installation directories.

## Deployment

Use `MaterialClient.DatabaseUpgrade.exe inspect <source.db>` for a read-only readiness check. With the old client stopped, run `MaterialClient.DatabaseUpgrade.exe upgrade <source.db> <new-destination.db>`. Keep the existing attachment data root and select the verified database with `ConnectionStrings:Default`.
