---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-UnifiedEnvironmentV2

## SYNOPSIS
Deploy a new Unified environment through the Power Platform SDK.

## SYNTAX

```
New-UnifiedEnvironmentV2 [-Type] <String> [-Name] <String> [[-CustomDomainName] <String>] [-Location] <String>
 [[-Template] <String>] [-NoDemoDb] [[-Version] <Version>] [[-SecurityGroup] <String>]
 [[-EnvironmentGroup] <String>] [[-PostProvisionDelaySeconds] <Int32>] [[-ReadyStateTimeoutMinutes] <Int32>]
 [-WaitForCompletion] [-EarlyRelease] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Deploys a new Unified environment in Power Platform Admin Center (PPAC).

This is the second generation of New-UnifiedEnvironment.
The shell
environment is provisioned through the bundled Power Platform SDK
(POST /environmentmanagement/provisioning/environments) instead of
the legacy Business App Platform endpoint.

Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).

Location and template values are validated against the provisioning
discovery cache before anything is sent to the API, so an unknown
location, an unavailable template, or a license-gated SKU combination
fails immediately with the valid values instead of a late timeout.

## EXAMPLES

### EXAMPLE 1
```
New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe"
```

This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "europe" location.
It will include a demo database by default.
It will get a default/unique domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 2
```
New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -CustomDomainName "myudeenv"
```

This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "europe" location.
It will include a demo database by default.
It will get the custom domain name "myudeenv".
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 3
```
New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -Version "10.0.44" -WhatIf
```

This will show the resolved provisioning payload without creating anything.
It will install version 10.0.44 of Finance and Operations when run without -WhatIf.

## PARAMETERS

### -Type
Instructs the cmdlet to create either a Unified Sandbox Environment (USE) or a Unified Developer Environment (UDE).

Valid values are:
- "USE": Deploys a Unified Sandbox Environment (USE) which is a sandbox environment without developer tools.
- "UDE": Deploys a Unified Developer Environment (UDE) which is a sandbox environment with developer tools.

The type constrains the template: "UDE" only works with
"D365_DeveloperEdition", while "USE" requires a Finance and
Operations template ("D365_FinOps*") and can never use the developer
edition.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Name of the new environment as it will be displayed in Power Platform Admin Center (PPAC).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CustomDomainName
The custom domain name to be associated with the new environment.

E.g.
"demo-time" will create the environment URLs:
- "https://demo-time.crmX.dynamics.com".
- "https://demo-time.operations.eu.dynamics.com"

Use lowercase.
When omitted, Power Platform assigns a domain name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Location
The deployment location for the new environment.

Use the location name (e.g.
"europe").
Display names such as
"Europe" are accepted and normalized.
Tab completion lists the
available locations.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Template
The provisioning template to apply (e.g.
"D365_DeveloperEdition").

Only Finance and Operations templates ("D365_FinOps*") and the
developer edition ("D365_DeveloperEdition") are supported.

The environment type constrains the choice: "UDE" requires
"D365_DeveloperEdition", while "USE" requires a "D365_FinOps*"
template (its default must be overridden explicitly).

Tab completion lists the supported templates available for the
selected location and type.
The template is validated for the
Sandbox SKU before anything is provisioned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: D365_DeveloperEdition
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoDemoDb
Instructs the cmdlet to create the environment without a demo database.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
The version of the Finance and Operations application to be installed in the new environment.

```yaml
Type: Version
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecurityGroup
Entra Groups security group to restrict access to the new environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: EntraGroup

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnvironmentGroup
The ID or display name of the environment group in which to create the shell environment.

Note that this will make the environment a managed environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: EnvironmentGroupId, EnvironmentGroupName

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PostProvisionDelaySeconds
Additional delay (in seconds) after the shell environment reports as ready.

This pause helps ensure the platform application package endpoint is fully ready before install is attempted.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReadyStateTimeoutMinutes
Maximum number of minutes to wait for the environment to reach state 'Ready'.

Prevents endless waiting when an environment is stuck in a non-ready state.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -WaitForCompletion
Instructs the cmdlet to wait until the final provisioning app installation is completed.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -EarlyRelease
Instructs the cmdlet to create the environment in the early release cycle.

Note that not all locations support early release environments.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
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

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
