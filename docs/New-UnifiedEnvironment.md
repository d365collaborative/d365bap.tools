---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-UnifiedEnvironment

## SYNOPSIS
Deploy a new Unified Environment in Power Platform Admin Center (PPAC).

## SYNTAX

```
New-UnifiedEnvironment [-Type] <String> [-Name] <String> [[-CustomDomainName] <String>] [-Location] <String>
 [[-Region] <String>] [-NoDemoDb] [[-Version] <Version>] [[-SecurityGroup] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Deploys a new Unified Environment in Power Platform Admin Center (PPAC).

Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).

## EXAMPLES

### EXAMPLE 1
```
New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe"
```

This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
It will include a demo database by default.
It will get a default/unique domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

It will deploy into the North Europe region, as it's the default region for the Europe location.

### EXAMPLE 2
```
New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -Region "West Europe"
```

This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
It will deploy into the "West Europe" region.
It will include a demo database.
It will get a default/unique domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 3
```
New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe" -CustomDomainName "myudeenv"
```

This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
It will include a demo database by default.
It will get the custom domain name "myudeenv".
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 4
```
New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -NoDemoDb
```

This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
It will not include a demo database.
It will get a default/unique domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 5
```
New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe" -Version "10.0.44"
```

This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
It will include a demo database by default.
It will get a default/unique domain name assigned by Power Platform.
It will install version 10.0.44 of Finance and Operations.
It will not restrict access to the environment.

### EXAMPLE 6
```
New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -SecurityGroup "MySecurityGroup"
```

This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
It will include a demo database by default.
It will get a default/unique domain name assigned by Power Platform.
It will take the latest available version of Finance and Operations.
It will restrict access to the environment to members of the specified Entra Groups security group "MySecurityGroup".

## PARAMETERS

### -Type
Instructs the cmdlet to create either a Unified Sandbox Environment (USE) or a Unified Developer Environment (UDE).

Valid values are:
- "USE": Deploys a Unified Sandbox Environment (USE) which is a sandbox environment without developer tools.
- "UDE": Deploys a Unified Developer Environment (UDE) which is a sandbox environment with developer tools.

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

This translates to the Power Platform location where the environment will be created.

Data residency and compliance requirements should be considered when selecting the location.

Get-PpacDeployLocation can be used to find available locations.

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

### -Region
The Azure region for the new environment.

It specifies the physical location of the data center where the environment will be hosted.

Get-PpacDeployLocation | Format-List can be used to find possible regions.

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
