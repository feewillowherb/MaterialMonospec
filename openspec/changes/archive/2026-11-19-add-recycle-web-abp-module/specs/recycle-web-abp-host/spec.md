## ADDED Requirements

### Requirement: The web host project is UrbanManagement.Recycle

The resource web project, assembly, root namespace, and directory SHALL be `UrbanManagement.Recycle`. Its ABP module SHALL be `UrbanManagementRecycleModule`. The session cookie SHALL be `Recycle.Session`, the authentication scheme SHALL be `Recycle`, and the data-protection application name SHALL be `UrbanManagement.Recycle`. The compose service SHALL be `um-recycle` and the image SHALL be `urbanmanagement-recycle`. The Chinese product title SHALL remain 「萧山资源化利用网页端」 and the SSO product code SHALL remain 5041.

#### Scenario: Old project name is not the running host

- **WHEN** the change is applied
- **THEN** the solution hosts `UrbanManagement.Recycle`
- **AND** `UrbanManagement.XiaoShanResource` is not a second web project

#### Scenario: Existing browser session is not reused

- **WHEN** a browser still presents `XiaoShanResource.Session` after the host is upgraded
- **THEN** that cookie does not authenticate the Recycle host
- **AND** the user can sign in again through the 5041 login page

### Requirement: Recycle host resolves application services

`UrbanManagement.Recycle` SHALL start through `UrbanManagementRecycleModule`, which depends on the shared UrbanManagement host module. The process SHALL be able to resolve the existing Recycle material, company, vehicle, contract, daily-production, transport, and attachment application services. The module SHALL NOT register a second Recycle persistence model.

#### Scenario: Services resolve after startup

- **WHEN** the Recycle web host has finished ABP initialization
- **THEN** the Recycle vehicle application service can be resolved from the host
- **AND** it uses the Recycle persistence model already defined for UrbanManagement

### Requirement: Login remains SSO product 5041

The host SHALL keep its login page and `POST /GetToken` product code 5041. `Recycle.Session` SHALL carry only the user identifier, user name, and accepted product code. A business API call without that session SHALL be rejected and SHALL NOT create a Recycle row.

#### Scenario: Anonymous business call

- **WHEN** a request to a Recycle business API has no `Recycle.Session`
- **THEN** the host rejects the request
- **AND** no Recycle vehicle, contract, production, or transport row is created

### Requirement: Project binding is server configuration

The host SHALL determine the Recycle project only from `RecyclePersistence:BoundSourceProId`, checked against a product-5020 `GovProject.SourceProId`. A project identifier in the request body, query, or session SHALL NOT select the project. A missing value, a value that is not a 5020 SourceProId, or a value equal to the derived Recycle `GovProject.Id` SHALL fail closed with the existing unbound or mixed-id failure.

#### Scenario: Request body names another project

- **WHEN** an authenticated request includes a project identifier different from `RecyclePersistence:BoundSourceProId`
- **THEN** the written row belongs to the configured SourceProId
- **AND** the request identifier is not stored as the row project

#### Scenario: Binding is absent

- **WHEN** `RecyclePersistence:BoundSourceProId` is missing or does not match a 5020 SourceProId
- **THEN** list and write operations fail closed
- **AND** no row is written for an Urban project or a derived GovProject id

### Requirement: Urban management APIs stay off this host

`UrbanManagementRecycleModule` SHALL NOT expose Urban weighing, passage, authorization, client-log, or Recycle device-status conventional APIs. Its business surface SHALL remain the site routes used by the Recycle web pages.

#### Scenario: Urban receive route is not served here

- **WHEN** a client requests the Urban weighing receive route on the Recycle web host
- **THEN** the host does not invoke the Urban weighing receive service
