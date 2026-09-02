## ADDED Requirements

### Requirement: UrbanManagement BaseUrl for local reconcile

MaterialClient.Urban SHALL read UrbanManagement server address from configuration key `UrbanManagement:BaseUrl` for all Refit clients including passage receive. Pipeline reconcile scripts MUST be able to override this value via environment variable `UrbanManagement__BaseUrl` or appsettings overlay without recompiling.

#### Scenario: Local UM reconcile

- **WHEN** an operator runs `urban-passage-um-reconcile` ClientUpload against local UrbanManagement
- **THEN** the start script MUST set `UrbanManagement:BaseUrl` to the reconcile `umBaseUrl` from graph secrets
- **AND** passage upload MUST target that host

#### Scenario: Diagnostic host unchanged

- **WHEN** BaseUrl is overridden for reconcile
- **THEN** MinimalWebHost diagnostic URLs MUST remain on `MinimalWebHost:Urls` (default `http://localhost:9961`)
- **AND** probe scripts MUST continue to POST test-passage to the diagnostic host
