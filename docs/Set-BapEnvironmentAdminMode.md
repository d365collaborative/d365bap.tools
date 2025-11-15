---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapEnvironmentAdminMode

## SYNOPSIS
Set environment admin mode

## SYNTAX

```
Set-BapEnvironmentAdminMode [-EnvironmentId] <String> [[-Mode] <String>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to set the Power Platform environment into Admin Mode or User Mode.

Admin Mode allows only users with the System Administrator role to access the environment, needed for specific maintenance tasks.

User Mode allows all users with appropriate permissions to access the environment.

## EXAMPLES

### EXAMPLE 1
```
Set-BapEnvironmentAdminMode -EnvironmentId *uat* -Mode AdminMode
```

This will set the environment with id containing "uat" into Admin Mode.

### EXAMPLE 2
```
Set-BapEnvironmentAdminMode -EnvironmentId *prod* -Mode UserMode
```

This will set the environment with id containing "prod" into User Mode.

## PARAMETERS

### -EnvironmentId
Id of the environment that you want to work against.

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

### -Mode
Specifies the mode to set for the environment.

Valid values are "UserMode" and "AdminMode".

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
