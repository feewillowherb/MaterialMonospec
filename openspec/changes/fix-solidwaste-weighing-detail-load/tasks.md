## 1. MaterialClient

- [x] 1.1 Materialize the weighing extension within the service work unit.
- [x] 1.2 Verify repeated reads after saving through the SolidWaste service with SQLite and ABP interception.

## 2. MaterialMonospec

- [x] 2.1 Strictly validate the change.

## Verification

The SQLite integration test reproduced the reported ObjectDisposedException on the first detail read before the fix. With the fix, the test reads all saved values, changes the street, reads the change through a new service work unit, and checks a missing extension. All eight focused tests passed.
