<!--
topic: d365bap.tools.Unified
keywords: unified, unified environment, ude, use, deploy, provisioning, sdk, maintenance, modules, packages, servicing
-->

# Unified

The Unified namespace manages the unified environment object itself: the sandbox or production environment a finance and operations installation runs on.

Administering that object is PPAC work; the workstation side is the [Ude](Ude) namespace.

## Reading environments

Get-UnifiedEnvironment lists the unified environments of the tenant, accepting an environment name, a PPAC environment GUID or a legacy LCS id. Most other commands in the module accept the same identifiers.

```pwsh
Get-UnifiedEnvironment
```

## Deploying

- New-UnifiedEnvironment - the original deploy command, through the legacy Business App Platform endpoint.
- New-UnifiedEnvironmentV2 - deploy through the bundled Power Platform SDK instead. Input is validated against a local provisioning cache before anything is sent.

V2 distinguishes two environment types: UDE, a sandbox with developer tools (template D365_DeveloperEdition), and USE, a sandbox without them (a D365_FinOps* template). Both can wait for the environment to reach the Ready state and for the first app installation to complete, and both can join an environment group, which makes the environment managed - see [Policies](Policies).

```pwsh
New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -WaitForCompletion
```

## Contents: modules and packages

- Get-UnifiedEnvironmentModule / Remove-UnifiedEnvironmentModule - the F&O modules in an environment.
- Get-UnifiedEnvironmentPackage / Remove-UnifiedEnvironmentPackage - the deployed packages.

## Maintenance windows

- Get/Set-UnifiedEnvironmentMaintenance - read and set the finance and operations maintenance window through the bundled SDK.

## Servicing

Applying versions and platform updates is an async operation - start it with Invoke-PpacD365VersionUpdate or Invoke-PpacD365PlatformUpdate (Ppac namespace), then wait for the correlation id as described in [Operations](Operations). Pick a target version with Get-PpacFinOpsVersion, Get-PpacFinOpsBuild, Get-PpacFinOpsPlatform and Get-PpacFinOpsAsset; the list completes from tab and is preloaded in the background.

## Removing

- Remove-UnifiedEnvironment - remove the environment from the tenant. There is no -WhatIf safety net at the platform side, so name the environment precisely.
