---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacRbacRoleMember

## SYNOPSIS
Add a service principal as a member of a PPAC RBAC role in a specific scope.

## SYNTAX

```
Add-PpacRbacRoleMember [-ServicePrincipalId] <String> [-Role] <String> [-Scope] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Adds a service principal as a member of a PPAC RBAC role in a specific scope.
This command is used to grant permissions to service principals in Power Platform.

The role assignment will be created in the tenant's root scope, but the specified scope will be used for permission evaluation.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -Role "Power Platform Owner" -Scope "/tenants/{0}"
```

This command assigns the service principal with object id "00000000-0000-0000-0000-000000000000" to the "Power Platform Owner" role in the tenant scope.
The service principal will have owner permissions across all Power Platform environments in the tenant.

## PARAMETERS

### -ServicePrincipalId
The object id of the service principal to which the role will be assigned.

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

### -Role
The name of the PPAC RBAC role to which the service principal will be assigned.
Use the command \<c='em'\>Get-PpacRbacRole\</c\> to see the list of valid role names.

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

### -Scope
The scope in which the role assignment will be evaluated.

Will be auto-populated based on the role.
Anything beyond /tenants/{0} needs to be filled out by the user.

For example, if the scope is /tenants/{0}/environments/{1}, the user needs to fill out the {1} (environmentId).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

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

Based on:
https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential

## RELATED LINKS
