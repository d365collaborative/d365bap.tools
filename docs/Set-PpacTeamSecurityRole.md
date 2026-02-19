---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacTeamSecurityRole

## SYNOPSIS
Set Security Role for a team in a Power Platform environment.

## SYNTAX

```
Set-PpacTeamSecurityRole [-EnvironmentId] <String> [-Team] <String> [-Role] <String[]>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet allows you to set a Security Role for a team in a Power Platform environment.
It can be used to configure a Security Role to a team.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacTeamSecurityRole -EnvironmentId "ContosoEnv" -Team "ContosoTeam" -Role "ContosoRole"
```

This command sets the Security Role "ContosoRole" for the team "ContosoTeam" in the Power Platform environment "ContosoEnv".

### EXAMPLE 2
```
Set-PpacTeamSecurityRole -EnvironmentId "ContosoEnv" -Team "ContosoTeam" -Role "ContosoRole1","ContosoRole2"
```

This command sets the Security Roles "ContosoRole1" and "ContosoRole2" for the team "ContosoTeam" in the Power Platform environment "ContosoEnv".

## PARAMETERS

### -EnvironmentId
The ID of the environment to set the Security Role for.

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

### -Team
The name or ID of the team to set the Security Role for.

Can be either the team name or the team ID.

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

### -Role
The name or ID of the Security Role to assign to the team.

Can be either the role name or the role ID.

Multiple roles / array of roles are supported.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 3
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
