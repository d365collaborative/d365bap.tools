<!--
topic: d365bap.tools.Ude
keywords: ude, unified developer experience, developer, workstation, packageslocaldirectory, dbjit, just in time, ssms, visual studio, nuget, xref
-->

# Ude

The Ude namespace serves the Unified Developer Experience workstation: the local machine of a developer who works against a UDE (or USE) environment, and the admin who supports them.

The server-side environment object itself is the [Unified](Unified) namespace; Ude is everything on and around your own machine.

## Config and connections

- Get-UdeEnvironment / Get-UdeConnection - the environments you work with and their connection details.
- Get/Set-UdeConfig - UDE configuration values; Set-UdeConfig keeps them per environment.
- Set-UdeEnvironmentInSession - target one environment for the whole session, so the remaining commands stop asking.
- Clear-UdeOrphanedConfig - remove configuration entries whose environment no longer exists.

## Visual Studio tooling

- Confirm-UdeVs2022Installation - verify the Visual Studio 2022 install.
- Get-UdeVsPackageDeploy / Get-UdeVsPowerPlatformExtensionHistory - package deployment and the Power Platform extension history.
- Get-UdeCredentialCache / Clear-UdeCredentialCache - the cached credentials Visual Studio uses; clear it when logins go stale.

## Local assets

- Get-UdePackageLocalDirectory - the local PackagesLocalDirectory paths.
- Get-UdePackageModel / Get-UdeEnvironmentModel / Install-UdeModel / Remove-UdeEnvironmentModel - inspect, install and remove models.
- Export-UdeModelLabel - export label files from local models.
- Get-UdeNuget - the NuGet packages a UDE setup relies on.
- Get-UdeXrefDb - the cross-reference databases used for metadata search.
- Get-UdeDeveloperFile - developer files for an environment.

## Database JIT access

Temporary SQL credentials, requested from Dataverse and used without storing anything:

- Get-UdeDbJit - request access for one environment. Choose the SQL role (Reader by default, Writer for data changes), the firewall whitelist (loopback discovers your public IP), and an audit reason. Credentials are returned in memory - nothing is written to CredentialManager or the SSMS cache.
- Invoke-UdeDbQuery - query the database directly. It bundles its own SQL client, so no SSMS or SQL module is needed. Pass a Get-UdeDbJit result via -JitCredential to reuse one request across queries.
- Set-UdeDbJitCache / Get-UdeDbJitCache / Clear-UdeDbJitCache - keep one request's credentials for the session; cached credentials complete from tab.
- Start-UdeDbSsms - open SSMS with the cached credentials.

```pwsh
Invoke-UdeDbQuery -EnvironmentId "es-ude-motz-01" -Query "SELECT DB_NAME() AS DatabaseName"
```

## Environment maintenance

- Add-UdeWindowsDefenderRules - add the Defender exclusions a UDE workstation needs.
- Start-UdeDatabaseRefresh - start a database refresh between two environments; the long-running part follows the [Operations](Operations) pattern.
