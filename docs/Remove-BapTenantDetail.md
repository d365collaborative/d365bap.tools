---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-BapTenantDetail

## SYNOPSIS
Removes tenant details for a specified BAP tenant from the local configuration.

## SYNTAX

```
Remove-BapTenantDetail [-Id] <String> [-Force] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to remove tenant details for a specified BAP tenant from the local PSFramework configuration.
If the -Force switch is not used, it will return the tenant details for the specified tenant id, allowing you to review them before deciding to remove them.

## EXAMPLES

### EXAMPLE 1
```
Remove-BapTenantDetail -Id "Contoso"
```

This will show the tenant details for the BAP tenant with the id "Contoso".
It will NOT remove the tenant details yet, allowing you to review them before deciding to remove them.

### EXAMPLE 2
```
Remove-BapTenantDetail -Id "Contoso" -Force
```

This will remove the tenant details for the BAP tenant with the id "Contoso" without prompting for confirmation.

## PARAMETERS

### -Id
The ID of the BAP tenant whose details are to be removed.

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

### -Force
Instructs the function to remove the tenant details without prompting for confirmation.

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

## RELATED LINKS
