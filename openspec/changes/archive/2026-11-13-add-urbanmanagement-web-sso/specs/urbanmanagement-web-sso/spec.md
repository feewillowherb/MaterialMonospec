## ADDED Requirements

### Requirement: Admin login calls SSO GetToken

UrbanManagement Admin SHALL collect the account and password on a login page and SHALL submit them only to the Admin server. The Admin server SHALL send `POST /GetToken` to the configured SSO base address with `switchType` 0, `productType` 2, and `toProductIds` containing only the configured Web product code. The login page SHALL NOT accept a project switch, a product switch, or a caller-supplied identity.

#### Scenario: Password is submitted to Admin

- **WHEN** a user submits an account and password on the Admin login page
- **THEN** the browser sends those values only to Admin
- **AND** Admin calls the configured SSO `POST /GetToken` with `switchType` 0, `productType` 2, and the configured Web product code

#### Scenario: Product code comes from configuration

- **WHEN** Admin starts with an SSO base address and Web product code in its configuration
- **THEN** the login request uses that configured product code
- **AND** Admin does not derive the code from client product 5001

### Requirement: Local session requires the configured product

Admin SHALL create its own cookie session only when the SSO response has business code 200 and the returned product code equals the configured Web product code. Admin SHALL NOT create a session when the password is rejected, the SSO call fails, the product is missing, or the product code differs. A JWT presented by the browser SHALL NOT by itself establish the session. Admin SHALL NOT write the SSO token to logs or to the UrbanManagement database.

#### Scenario: Matching product login

- **WHEN** SSO returns business code 200 and product code equal to the configured Web product code
- **THEN** Admin creates a local cookie session containing the SSO user identifier, user name, and accepted product code
- **AND** the response available to the page does not expose the SSO token

#### Scenario: Wrong password

- **WHEN** SSO rejects the password
- **THEN** Admin creates no session
- **AND** the login page shows a failure

#### Scenario: SSO unavailable

- **WHEN** the SSO base address does not return a usable login response
- **THEN** Admin creates no session
- **AND** the login page shows a failure

#### Scenario: Product mismatch

- **WHEN** SSO returns business code 200 for a product code other than the configured Web product code
- **THEN** Admin creates no session

### Requirement: Admin surfaces require the local session

Admin SHALL require a valid local session for Blazor pages, the Blazor Hub, and the management APIs exposed by the Admin process. An anonymous request for a management deep link SHALL reach the login page and SHALL NOT perform the requested management operation. `/health/live` and `/health/ready` SHALL remain anonymous.

#### Scenario: Anonymous management page

- **WHEN** a browser opens a management page without a valid Admin session
- **THEN** Admin shows the login page
- **AND** the requested management operation is not performed

#### Scenario: Anonymous Blazor hub

- **WHEN** a client connects to the Admin Blazor Hub without a valid Admin session
- **THEN** Admin rejects the connection

#### Scenario: Health remains open

- **WHEN** a client calls `/health/live` or `/health/ready` without a session
- **THEN** the health endpoint keeps its existing anonymous behavior

### Requirement: Client and legacy entries stay unchanged

Adding Admin login SHALL NOT place a login redirect on client upload, weighing reception, realtime channels, or the legacy API. Those entries SHALL keep the authentication behavior they had before this change.

#### Scenario: Legacy ingest stays open

- **WHEN** a client calls the existing legacy weighing ingest endpoint without an Admin session
- **THEN** the endpoint keeps its existing anonymous behavior

#### Scenario: Client routes avoid the login page

- **WHEN** a client calls an existing upload, weighing reception, or realtime route
- **THEN** the gateway still forwards that route to its existing service
- **AND** the response is not the Admin login page

### Requirement: Logout clears only the Admin session

Admin SHALL remove the local cookie session on logout and SHALL return the browser to the login page. Logout SHALL NOT depend on SSO `logout` or on deletion of the SSO Redis session. An existing Blazor circuit SHALL NOT continue to submit management operations after the local session is cleared.

#### Scenario: User logs out

- **WHEN** a signed-in user logs out
- **THEN** the Admin cookie session is removed
- **AND** a subsequent management page request shows the login page

#### Scenario: Expired local session

- **WHEN** the Admin cookie session has expired
- **THEN** management pages and management APIs reject the request until the user logs in again

### Requirement: Missing SSO configuration fails startup

Admin SHALL fail to start when the SSO base address or the Web product code is missing. Admin SHALL NOT run its management pages anonymously because that configuration is absent.

#### Scenario: Product code is missing

- **WHEN** Admin starts without a configured Web product code
- **THEN** the Admin process fails to start
