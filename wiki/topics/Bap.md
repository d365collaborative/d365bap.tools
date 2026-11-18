<!--
topic: d365bap.tools.Bap
keywords: bap, business application platform, environments, d365 apps, virtual entities, enterprise policy, azcopy, azcli
-->

# Bap

The Bap namespace is the Business Application Platform itself: tenants, environments, the D365 apps installed on them, and the platform-level configuration around them.

It is the oldest namespace, so it also hosts a few general commands, including the auth provider and tenant registry described in [Auth](Auth) and [Tenants](Tenants).

## Environments

- Get-BapEnvironment - the environments of the current tenant; this also feeds the background refresh task behind environment-name tab completion.
- Get-BapEnvironmentOperation - environment life cycle operations, like moves and copy operations.
- Get-BapEnvironmentPowerApp - the PowerApps in an environment.

## D365 apps

The installed finance and operations apps, compared and installed:

- Get-BapEnvironmentD365App - what is installed in one environment.
- Compare-BapEnvironmentD365App - what two environments differ in.
- Invoke-BapEnvironmentInstallD365App - install an app into an environment, an async operation, see [Operations](Operations).
- Confirm-BapEnvironmentIntegration - test the integration status of an environment.

## Virtual entities

Dataverse virtual entities that surface F&O data:

- Get-BapEnvironmentVirtualEntity / Set-BapEnvironmentVirtualEntity - read and configure.
- Compare-BapEnvironmentVirtualEntity - what two environments differ in.
- Update-BapEnvironmentVirtualEntityMetadata - refresh entity metadata after the ERP changed.

## Enterprise policies

- Get-BapEnvironmentLinkEnterprisePolicy / Set-BapEnvironmentLinkEnterprisePolicy - link an environment to an enterprise policy, for example a SQL or networking policy the environment depends on.

## Users across environments

- Compare-BapEnvironmentUser - what two environments differ in, useful before or after a refresh or migration.

## Local helper tooling

- Invoke-BapInstallAzCli / Invoke-BapInstallAzCopy - download and install the two CLI tools from their official sources.
- Set-BapAzCopyPath - where AzCopy lives, used by commands that move packages or files.

Tenant commands live here too: Get-BapTenant, Get/Set/Remove-BapTenantDetail and Switch-BapTenant are covered in [Tenants](Tenants).
