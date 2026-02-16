---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacTeamOnSecurityGroup

## SYNOPSIS
Add a team based on a Microsoft Entra Security Group to a Power Platform environment.

## SYNTAX

```
Add-PpacTeamOnSecurityGroup [-EnvironmentId] <String> [-Name] <String> [-SecurityGroup] <String>
 [[-MembershipType] <String>] [-Role] <String> [[-AdminUpn] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to add a team based on a Microsoft Entra Security Group to a Power Platform environment, and assign a security role to it.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales SG" -SecurityGroup "Contoso Sales SG" -MembershipType "Members" -Role "System Customizer"
```

This will create a team named "Contoso Sales Team" in the Power Platform environment with the id "env-123".
It will link the team to the Microsoft Entra Security Group named "Contoso Sales SG".
It will set the membership type to "Members".
It will assign the "System Customizer" security role to the team.
It will use the UPN of the user running the function as the administrator for the team.

### EXAMPLE 2
```
Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales SG" -SecurityGroup "Contoso Sales SG" -MembershipType "Members and Guests" -Role "System Customizer" -AdminUpn "admin@contoso.com"
```

This will create a team named "Contoso Sales Team" in the Power Platform environment with the id "env-123".
It will link the team to the Microsoft Entra Security Group named "Contoso Sales SG".
It will set the membership type to "Members and Guests".
It will assign the "System Customizer" security role to the team.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

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
The name of the team you want to create in the Power Platform environment.

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

### -SecurityGroup
The name or id of the Microsoft Entra Security Group that you want to link the team to.

You can use either the name or the id of the Security Group, and the function will try to find a match in Microsoft Graph.

```yaml
Type: String
Parameter Sets: (All)
Aliases: EntraGroup

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MembershipType
The membership type of the team in relation to the Microsoft Entra Security Group.

Possible values are:
- Members and Guests
- Members
- Guests
- Owners

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Members
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The name of the security role that you want to assign to the team.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AdminUpn
The User Principal Name (UPN) of the administrator who will be associated with the team.

If not supplied, the function will try to determine the UPN of the user running the function, and use that as the administrator.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
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
