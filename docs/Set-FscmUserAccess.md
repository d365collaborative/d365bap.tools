---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-FscmUserAccess

## SYNOPSIS
Enable or disable user access in a Dynamics 365 Finance & Operations environment

## SYNTAX

```
Set-FscmUserAccess [-EnvironmentId] <String> [-User] <String[]> [-Enabled] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Updates the Enabled flag on one or more users in the SystemUsers OData endpoint of a Dynamics 365 Finance & Operations (FSCM) environment.

Users can be identified by their FscmUserId, UPN, alias, email address, or display name.
Use -Enabled to grant access; omit it (or use -Enabled:$false) to revoke access.

## EXAMPLES

### EXAMPLE 1
```
Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com" -Enabled
```

Enables user john.doe@contoso.com in the specified environment.

### EXAMPLE 2
```
Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com"
```

Disables user john.doe@contoso.com in the specified environment.

### EXAMPLE 3
```
Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com","jane.doe@contoso.com" -Enabled
```

Enables both john.doe and jane.doe in the specified environment.

## PARAMETERS

### -EnvironmentId
The id of the environment you want to update users in.

This can be obtained from the Get-BapEnvironment cmdlet.

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
The user(s) to update.

Accepts one or more identifiers per user.
Each value is matched against: FscmUserId, UPN, alias, email address, and display name - in that order.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Enabled
Switch to enable the user account(s).

Omit this switch (default) to disable the user account(s).

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
