---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacAdminMode

## SYNOPSIS
Set the admin mode for a Power Platform environment.

## SYNTAX

```
Set-PpacAdminMode [-EnvironmentId] <String> [[-Mode] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This cmdlet sets the admin mode for a Power Platform environment.
It allows switching between User Mode and Admin Mode, which can be useful for troubleshooting and support scenarios.

Is the same as the administrative mode in LCS.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacAdminMode -EnvironmentId "ContosoEnv" -Mode "AdminMode"
```

This command sets the admin mode for the Power Platform environment "ContosoEnv" to "AdminMode".
Now the environment is an admin-only mode.

### EXAMPLE 2
```
Set-PpacAdminMode -EnvironmentId "ContosoEnv" -Mode "UserMode"
```

This command sets the admin mode for the Power Platform environment "ContosoEnv" to "UserMode".
Now the environment is in normal user mode and accessible for all users with permissions.

## PARAMETERS

### -EnvironmentId
The ID of the environment to set the admin mode for.

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

### -Mode
The mode to set for the environment.

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
