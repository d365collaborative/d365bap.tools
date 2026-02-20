---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-GraphGroupMember

## SYNOPSIS
Get members of a Security Group from Azure AD / Entra ID.

## SYNTAX

```
Get-GraphGroupMember [-Group] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves members of a Security Group from Azure AD / Entra ID based on the supplied GroupId.

## EXAMPLES

### EXAMPLE 1
```
Get-GraphGroupMember -Group "12345678-90ab-cdef-1234-567890abcdef"
```

This command retrieves the members of the Security Group with the specified ObjectId.

### EXAMPLE 2
```
Get-GraphGroupMember -Group "FO-PPE-ENV-ADMINS"
```

This command retrieves the members of the Security Group with the specified display name starting with "FO-PPE-ENV-ADMINS".
If multiple groups match, it will take the first one returned by Graph API.

## PARAMETERS

### -Group
The ObjectId of the Security Group in Azure AD / Entra ID.

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
