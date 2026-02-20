---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacApplicationUser

## SYNOPSIS
Get application users in Power Platform environment.

## SYNTAX

```
Get-PpacApplicationUser [-EnvironmentId] <String> [[-User] <String>] [-IncludePpacApplications]
 [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to get application users in the environment.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacApplicationUser -EnvironmentId "env-123"
```

This will retrieve all application users in the Power Platform environment.

### EXAMPLE 2
```
Get-PpacApplicationUser -EnvironmentId "env-123" -User "00000000-0000-0000-0000-000000000000"
```

This will retrieve the application user with the specified systemuserid in the Power Platform environment.

### EXAMPLE 3
```
Get-PpacApplicationUser -EnvironmentId "env-123" -User "My App*"
```

This will retrieve all application users with a fullname starting with "My App" in the Power Platform environment.

### EXAMPLE 4
```
Get-PpacApplicationUser -EnvironmentId "env-123" -IncludePpacApplications
```

This will retrieve all application users in the Power Platform environment.
It will include PPAC applications.

### EXAMPLE 5
```
Get-PpacApplicationUser -EnvironmentId "env-123" -AsExcelOutput
```

This will retrieve all application users in the Power Platform environment.
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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

### -User
The user to filter the results on.

Wildcards are supported.

You can filter on the systemuserid, fullname or applicationid properties of the users.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Upn

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludePpacApplications
Instructs the cmdlet to also include PPAC applications in the output.
By default, these are filtered out as they are not relevant for most use cases.

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

### -AsExcelOutput
Instructs the cmdlet to export the retrieved security role information to an Excel file.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
