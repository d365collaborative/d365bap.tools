---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-UdeEnvironment

## SYNOPSIS
Deploy a new Unified Developer Environment (UDE) in Power Platform

## SYNTAX

```
New-UdeEnvironment [[-Name] <String>] [[-CustomDomainName] <String>] [[-Location] <String>]
 [[-Region] <String>] [[-FnoTemplate] <String>] [-NoDemoDb] [[-Version] <Version>]
 [[-SecurityGroupId] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Deploys a new Unified Developer Environment (UDE) in Power Platform using specified parameters such as name, location, template, and version.

## EXAMPLES

### EXAMPLE 1
```
New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance
```

This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
It will include a demo database by default.
It will get a default domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.

### EXAMPLE 2
```
New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -Region WestEurope -FnoTemplate D365_FinOps_Finance
```

This will create a new UDE environment named "MyUdeEnv" in the "Europe" location and "WestEurope" region using the specified Finance and Operations template.
It will include a demo database by default.
It will get a default domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.

### EXAMPLE 3
```
New-UdeEnvironment -Name "MyUdeEnv" -CustomDomainName "my-ude-env" -Location "Europe" -FnoTemplate D365_FinOps_Finance
```

This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
It will include a demo database by default.
It will get the custom domain name "my-ude-env".
It will take the latest available version of Finance and Operations.

### EXAMPLE 4
```
New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance -NoDemoDb -Version 10.0.45.7
```

This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
It will NOT include a demo database.
It will get a default domain name assigned by Power Platform.
It will install Finance and Operations application version 10.0.45.7.

### EXAMPLE 5
```
New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance -SecurityGroupId "12345678-90ab-cdef-1234-567890abcdef"
```

This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
It will include a demo database by default.
It will get a default domain name assigned by Power Platform.
It will restrict access to the environment to members of the specified Entra Groups security group.

## PARAMETERS

### -Name
Name of the new UDE environment as it will be displayed in Power Platform Admin Center.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Location
The deployment location for the new environment.

This translates to the Power Platform location where the environment will be created.

Data residency and compliance requirements should be considered when selecting the location.

Get-BapDeployLocation can be used to find available locations.

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

### -Region
The Azure region for the new environment.

It specifies the physical location of the data center where the environment will be hosted.

Get-BapDeployLocation | Format-List can be used to find possible regions.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FnoTemplate
The deployment template to use for creating the UDE.

Get-BapDeployTemplate can be used to find available templates.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
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

### -SecurityGroupId
Entra Groups security group ID to restrict access to the new environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
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
