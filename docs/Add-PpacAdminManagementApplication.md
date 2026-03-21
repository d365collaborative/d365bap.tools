---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacAdminManagementApplication

## SYNOPSIS
Add application to the list of admin management applications in Power Platform Admin Center (PPAC).

## SYNTAX

```
Add-PpacAdminManagementApplication [[-ServicePrincipalId] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Adds an application to the list of admin management applications in Power Platform Admin Center (PPAC).
This is required for the application to be able to perform certain administrative actions in PPAC, such as managing environments or other applications.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacAdminManagementApplication -ServicePrincipalId "00000000-0000-0000-0000-000000000000"
```

This will add the application with the specified service principal ID to the list of admin management applications in PPAC.

## PARAMETERS

### -ServicePrincipalId
The ID of the service principal to be added to the list of admin management applications.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)
Based on:
https://learn.microsoft.com/en-us/power-platform/admin/powerplatform-api-create-service-principal

## RELATED LINKS
