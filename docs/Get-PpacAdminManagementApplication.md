---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacAdminManagementApplication

## SYNOPSIS
Retrieves information about the Power Platform Admin Management Application(s)

## SYNTAX

```
Get-PpacAdminManagementApplication [-SkipGraphLookup] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves information about the Power Platform Admin Management Application(s) from the Power Platform Admin API and Microsoft Graph API.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacAdminManagementApplication
```

This will retrieve all Power Platform Admin Management Applications in the tenant.
It will perform a lookup in Microsoft Graph API for the applications to retrieve the Service Principal Name.

### EXAMPLE 2
```
Get-PpacAdminManagementApplication -SkipGraphLookup
```

This will retrieve all Power Platform Admin Management Applications in the tenant.
It will skip the lookup in Microsoft Graph API.

## PARAMETERS

### -SkipGraphLookup
Instructs the function to skip the lookup of the Service Principal in Microsoft Graph API.
This will result in faster execution, but will not include details from Microsoft Graph API such as Service Principal Name.

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

### -AsExcelOutput
Instructs the function to export the results to an Excel file.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)
Based on:
https://learn.microsoft.com/en-us/power-platform/admin/powerplatform-api-create-service-principal

## RELATED LINKS
