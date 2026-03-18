---
external help file:
online version:
schema: 2.0.0
---

# New-D365DevConfig

## SYNOPSIS
Create a new D365 Finance & Operations developer configuration from an existing downloaded platform version.

## SYNTAX

```
New-D365DevConfig.ps1 [[-CloudInstanceURL] <String>] [[-CustomMetadataFolder] <String>]
```

## DESCRIPTION
Duplicates an existing D365 Finance & Operations developer configuration for a platform version already downloaded on the local machine.

The script scans `%LOCALAPPDATA%\Microsoft\Dynamics365\` for downloaded platform versions (folders matching the `10.*.*.*` pattern), prompts the user to select one, and derives all configuration settings automatically from the provided Cloud Instance URL.

The cross-reference database is restored from the most recently modified existing configuration on the same platform version. The script will fail if no source configuration exists for the selected platform version, as it is designed to duplicate an existing configuration rather than create one from scratch.

The resulting `xppconfig.json` is written to the standard Visual Studio location and the Windows registry is updated so the configuration is immediately visible in Visual Studio under **Dynamics 365 > Options > Configure**.

## EXAMPLES

### EXAMPLE 1
```powershell
.\New-D365DevConfig.ps1
```

Runs the script interactively. The user is presented with a numbered list of all downloaded platform versions and prompted to select one, followed by a prompt for the Cloud Instance URL. The custom metadata folder defaults to `C:\Customizations`.

### EXAMPLE 2
```powershell
.\New-D365DevConfig.ps1 -CloudInstanceURL "https://myenv.operations.dynamics.com/"
```

Creates a new configuration targeting the environment at `https://myenv.operations.dynamics.com/`. The user is still prompted to select a platform version from the available list. The custom metadata folder defaults to `C:\Customizations`.

### EXAMPLE 3
```powershell
.\New-D365DevConfig.ps1 -CloudInstanceURL "https://myenv.operations.dynamics.com/" -CustomMetadataFolder "C:\MyModels"
```

Creates a new configuration targeting `https://myenv.operations.dynamics.com/` and sets `C:\MyModels` as both the `ModelStoreFolder` and `DebugSourceFolder` in the generated configuration file.

## PARAMETERS

### -CloudInstanceURL

The full URL of the target D365 Finance & Operations environment.

Used to derive the environment name (the first subdomain), which in turn determines the configuration file name, the cross-reference database name, and the `CloudInstanceURL` field written to the config.

If omitted, the script will prompt for the value at runtime.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None (prompted)
Accept pipeline input: False
Accept wildcard characters: False
```

### -CustomMetadataFolder

The path to the folder containing custom X++ packages and models for this environment.

This value is written to both the `ModelStoreFolder` and `DebugSourceFolder` fields of the generated configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Customizations
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

None. This script does not accept pipeline input.

## OUTPUTS

None. The script writes the following artifacts to disk and registry:

- **Config file** — `%LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\<envname>___<version>.json`
- **XRef database folder** — `%LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\<envname>___<version>\`
- **Cross-reference database** — Restored on `(LocalDB)\MSSQLLocalDB` as `XRef_<envname><version-without-dots>`
- **Registry** — `HKCU\Software\Microsoft\Dynamics\AX7\Development\Configurations` updated with `CurrentMetadataConfig` and `FrameworkDirectory`

## NOTES

Author: Mike Caterino (@mikecaterino)

**Prerequisites**

| Requirement | Notes |
|---|---|
| Visual Studio 2022 with D365 F&O Developer Tools | Extension must be installed |
| At least one downloaded platform version | Folder matching `10.*.*.*` under `%LOCALAPPDATA%\Microsoft\Dynamics365\` |
| At least one existing configuration on the same platform version | Required as the source for the cross-reference database restore |
| SQL Server LocalDB (`MSSQLLocalDB` instance) | Installed with Visual Studio |
| `sqlcmd` on PATH | Included with SQL Server or installable via the SQL Server command-line tools package |
| PowerShell 5.1 or later | Built into Windows |

**Cross-reference database naming**

The cross-reference database name follows the pattern `XRef_<envname><version-without-dots>`.

For example, a URL of `https://myenv.operations.dynamics.com/` combined with platform version `10.0.2428.95` produces the database name `XRef_myenv100242895`.

**Configuration description format**

The `Description` field written to the config file follows this format:

```
Unified development environment <envname>.
FinOps application version <version>.
Configuration generated on <date>.
Cross Reference DB Server (LocalDB)\MSSQLLocalDB.
Cross Reference DB Name <crossRefDbName>.
```

## RELATED LINKS
