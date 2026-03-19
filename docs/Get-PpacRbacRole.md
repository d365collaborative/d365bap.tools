---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacRbacRole

## SYNOPSIS
Get PPAC RBAC roles available in the tenant.

## SYNTAX

```
Get-PpacRbacRole [[-Role] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets PPAC RBAC roles available in the tenant.
This command is used to retrieve the list of available PPAC RBAC roles, which can then be used for role assignments in Power Platform.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacRbacRole -Role "Power Platform *"
```

This command retrieves all PPAC RBAC roles with names starting with "Power Platform".

### EXAMPLE 2
```
Get-PpacRbacRole -Role "*admin*" -AsExcelOutput
```

This command retrieves all PPAC RBAC roles with names or descriptions containing "admin".
The results will be exported to an Excel file instead of being displayed in the console.

## PARAMETERS

### -Role
The name, id or description of the PPAC RBAC role to retrieve.

Use wildcards (*) for partial matches.
If not specified, all roles will be returned.

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
