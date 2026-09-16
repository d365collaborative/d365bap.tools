---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacUser

## SYNOPSIS
Add a user to a Power Platform environment.

## SYNTAX

```
Add-PpacUser [-EnvironmentId] <String> [-User] <String> [[-Role] <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates the Dataverse systemuser for a Microsoft Entra ID user when it does not exist yet, enables the user when Dataverse created it disabled, and optionally assigns one or more security roles.

Add-PpacSecurityRoleMember requires the systemuser to already exist and be enabled, and Entra users without a mail value need the UPN as e-mail fallback.

Only depends on exported cmdlets (Get-BapEnvironment, Get-PpacUser, Add-PpacSecurityRoleMember) and the internal Get-GraphUser helper.
Business Unit lookup is done inline via REST so this file can also be tested standalone.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System Administrator"
```

Creates (or enables) the systemuser for megan.bowen@contoso.com and assigns the System Administrator role.

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
The user that you want to add to the Power Platform environment.

Can be either the User Principal Name (UPN), mail address, display name or Entra object id.

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
One or more security roles to assign to the user after creation.

The name of the security role, as accepted by Add-PpacSecurityRoleMember.
When omitted no role is assigned.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: RoleName

Required: False
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
