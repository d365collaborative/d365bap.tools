---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-UseEnvironment

## SYNOPSIS
Short description

## SYNTAX

```
New-UseEnvironment [[-Name] <String>] [[-CustomDomainName] <String>] [[-Location] <String>]
 [[-Region] <String>] [[-FnoTemplate] <String>] [-NoDemoDb] [[-Version] <Version>]
 [[-SecurityGroupId] <String>] [-WaitForCompletion] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Long description

## EXAMPLES

### EXAMPLE 1
```
New-UseEnvironment -Name "MyEnv" -Location "North Europe" -Region "NEU" -FnoTemplate "D365_FinOps_Finance"
New-UseEnvironment -Name Features-TEST-10.0.44 -CustomDomainName Features-test-44 -Location Europe -FnoTemplate D365_FinOps_Finance -Version 10.0.44.10 -Region westeurope -SecurityGroupId b72e217b-7e80-436f-8792-e8364bc854a4
```

## PARAMETERS

### -Name
Parameter description

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
{{ Fill CustomDomainName Description }}

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
Parameter description

Utilize Get-BapDeployLocation to get valid location names.

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
Parameter description

Utilize Get-BapDeployLocation | Format-List to get valid region codes for a given location.

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
Parameter description

Utilize Get-BapDeployTemplate -Location Europe -FnoOnly to get valid Finance and Operations templates.

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
Parameter description

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
Parameter description

Utilize Get-BapEnvironmentFnOAppUpdate to get valid versions.

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
{{ Fill SecurityGroupId Description }}

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

### -WaitForCompletion
Parameter description

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
General notes

## RELATED LINKS
