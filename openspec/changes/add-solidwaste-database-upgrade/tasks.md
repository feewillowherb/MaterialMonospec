## 1. MaterialClient implementation

- [x] 1.1 Add an independently publishable SolidWaste upgrade CLI with inspect and upgrade commands.
- [x] 1.2 Apply and verify the SolidWaste historical field migration on a consistent SQLite copy.
- [x] 1.3 Gate existing SolidWaste desktop startup on completed schema migration. Preserve fresh initialization.

## 2. MaterialMonospec verification

- [x] 2.1 Validate this OpenSpec change and build the tool and desktop.
- [x] 2.2 Upgrade a field recovery snapshot and verify legacy field values and original kernel IDs.
- [x] 2.3 Verify refusal of destination replacement and startup refusal of an existing legacy schema.

- [x] 2.4 Rebuild the unreleased migration from the original backup and verify EF can update migrated extensions in both tables.

## Verification

- A 2026-11-24 field recovery snapshot contained 9,459 waybills and 19,671 weighing records. The upgraded copy preserved their exact IDs and ExtraProperties. The four migrated fields matched the source for 9,459 waybill extensions and 7,028 weighing extensions. SQLite integrity check passed.
- Re-upgrading the produced database preserved all extension rows. A staged conflict and an existing output both failed without replacing data. The source snapshot hash stayed unchanged.
- Built and published the standalone Windows x64 executable and built the SolidWaste desktop host. Executing desktop install preflight on the legacy snapshot returned 3 and on the verified output returned 0. The focused schema, startup, matching and export tests passed (26 total).
- Rebuilt the unreleased backfill and upgraded the original field snapshot again. All 16,487 extension IDs use the SQLite provider format. Both EF update paths save and reload edited values. The corrected upgrader rejects a previously generated copy with noncanonical IDs. The 26 focused tests passed.
