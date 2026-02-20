---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacTeamOnSecurityGroup

## SYNOPSIS
Enables assignment of a Microsoft Entra ID security group as a team in the Power Platform environment.

## SYNTAX

```
Add-PpacTeamOnSecurityGroup [-EnvironmentId] <String> [-Name] <String> [-SecurityGroup] <String>
 [[-MembershipType] <String>] [-Role] <String> [[-TeamAdmin] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This cmdlet assigns a Microsoft Entra ID security group as a team in the specified Power Platform environment and assigns a security role to the team.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales Team" -SecurityGroup "Contoso Sales Security Group" -MembershipType "Members and Guests" -Role "System Customizer"
```

This will add the Microsoft Entra ID security group "Contoso Sales Security Group" as a team in the Power Platform environment with the id "env-123".
The team will be named "Contoso Sales Team" and have the membership type "Members and Guests".
The "System Customizer" security role will be assigned to the team.
The administrator of the team will be the user running the cmdlet.

### EXAMPLE 2
```
Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales Team" -SecurityGroup "Contoso Sales Security Group" -MembershipType "Members and Guests" -Role "System Customizer" -TeamAdmin "admin@contoso.com"
```

This will add the Microsoft Entra ID security group "Contoso Sales Security Group" as a team in the Power Platform environment with the id "env-123".
The team will be named "Contoso Sales Team" and have the membership type "Members and Guests".
The "System Customizer" security role will be assigned to the team.
The administrator of the team will be "admin@contoso.com".

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

### -Name
The name of the team to create in the Power Platform environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Team

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecurityGroup
The Microsoft Entra ID security group that you want to assign as a team in the Power Platform environment.

Can be either the name or the id (objectId) of the Microsoft Entra ID security group.

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
The membership type of the team.

Can be either "Members and Guests", "Members", "Guests", or "Owners".

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
The security role that you want to assign to the team.

Can be either the role name or the role ID.

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

### -TeamAdmin
The User Principal Name (UPN) of the admin user in the Power Platform environment.

This user needs to have sufficient permissions to create teams and assign security roles in the Power Platform environment.

If not provided, the cmdlet will use the account used to authenticate to Azure.

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
