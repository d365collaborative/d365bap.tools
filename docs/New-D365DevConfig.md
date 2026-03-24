---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-D365DevConfig

## SYNOPSIS
Creates a new xppconfig.json from an existing downloaded D365 F&O platform version.

## SYNTAX

```
New-D365DevConfig [-EnvironmentURL <String>] [-PlatformVersion <String>] [-CustomMetadataFolder <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Scans %LOCALAPPDATA%\Microsoft\Dynamics365\ for downloaded platform versions (folders matching the 10.*.*.* pattern), prompts you to pick one and provide an Environment URL, then auto-populates all other settings, creates the cross-reference database on LocalDB, and writes the config to the standard location (%LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\).

The cross-reference database is restored from the most recently modified existing configuration on the same platform version.
The cmdlet will fail if no source configuration exists for the selected platform version, as it is designed to duplicate an existing configuration rather than create one from scratch.

The resulting xppconfig.json is written to the standard Visual Studio location and the Windows registry is updated so the configuration is immediately visible in Visual Studio under **Dynamics 365 > Configure Metadata**.

## EXAMPLES

### EXAMPLE 1
```
New-D365DevConfig
```

Runs the cmdlet interactively.
The user is presented with a numbered list of all downloaded platform versions and prompted to select one, followed by a prompt for the Environment URL.
The custom metadata folder defaults to C:\Customizations.

### EXAMPLE 2
```
New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/"
```

Creates a new configuration targeting the environment at https://myenv.operations.dynamics.com/.
The user is still prompted to select a platform version from the available list.
The custom metadata folder defaults to C:\Customizations.

### EXAMPLE 3
```
New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/" -PlatformVersion "10.0.44.12345"
```

Creates a new configuration targeting https://myenv.operations.dynamics.com/ for platform version 10.0.44.12345.
Skips the interactive selection menu entirely.
The custom metadata folder defaults to C:\Customizations.

### EXAMPLE 4
```
New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/" -CustomMetadataFolder "C:\MyModels"
```

Creates a new configuration targeting https://myenv.operations.dynamics.com/ and sets C:\MyModels as both the ModelStoreFolder and DebugSourceFolder in the generated configuration file.

## PARAMETERS

### -EnvironmentURL
The full URL of the target D365 Finance & Operations environment (e.g. https://yourtenant.operations.dynamics.com/).

Used to derive the environment name (the first subdomain), which determines the configuration file name, cross-reference database name, and the CloudInstanceURL field written to the config.

If omitted, the cmdlet will prompt for the value at runtime.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None (prompted)
Accept pipeline input: False
Accept wildcard characters: False
```

### -PlatformVersion
The platform version to target (e.g. 10.0.44.12345).

Must match the 10.*.*.* pattern and correspond to a folder that has already been downloaded under %LOCALAPPDATA%\Microsoft\Dynamics365\.

If omitted, the cmdlet will present a numbered menu of all available downloaded versions for the user to select from.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CustomMetadataFolder
The path to the folder containing custom X++ packages and models for this environment.

This value is written to both the ModelStoreFolder and DebugSourceFolder fields of the generated configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: C:\Customizations
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

None. This cmdlet does not accept pipeline input.

## OUTPUTS

None. The cmdlet writes the following artifacts to disk and registry:

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
