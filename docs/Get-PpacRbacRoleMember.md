---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacRbacRoleMember

## SYNOPSIS
Get members of PPAC RBAC roles in the tenant.

## SYNTAX

```
Get-PpacRbacRoleMember [[-ServicePrincipalId] <String>] [[-Role] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets members of PPAC RBAC roles in the tenant.
This command is used to retrieve the list of service principals that are assigned to PPAC RBAC roles in Power Platform.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacRbacRoleMember -Role "*admin*"
```

This command retrieves all members of PPAC RBAC roles with names or descriptions containing "admin".

### EXAMPLE 2
```
Get-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -AsExcelOutput
```

This command retrieves all PPAC RBAC role assignments for the service principal with object id "00000000-0000-0000-0000-000000000000".
The results will be exported to an Excel file instead of being displayed in the console.

## PARAMETERS

### -ServicePrincipalId
The object id of the service principal to filter by.

You can use wildcards (*) for partial matches.
If not specified, members of all service principals will be returned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The name, id or description of the PPAC RBAC role to filter by.

You can use wildcards (*) for partial matches.
If not specified, members of all roles will be returned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the command to output the results to an Excel file instead of the console.

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
Author: Mötz Jensen (@Splaxi)

Based on:
https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential

## RELATED LINKS
