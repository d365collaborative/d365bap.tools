---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmUser

## SYNOPSIS
Get information about Finance and Operations users in a given environment.

## SYNTAX

```
Get-FscmUser [-EnvironmentId] <String> [[-User] <String>] [-IncludeMicrosoftAccounts] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves information about Finance and Operations users in a given environment.
It allows filtering by user name or ID, including or excluding Microsoft accounts, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe"
```

This command retrieves the Finance and Operations user with the user name "john.doe" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 2
```
Get-FscmUser -EnvironmentId "ContosoEnv" -User "*john*"
```

This command retrieves all Finance and Operations users with user names, user IDs or UPNs matching "*john*" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 3
```
Get-FscmUser -EnvironmentId "ContosoEnv" -User "john@contoso.com"
```

This command retrieves the Finance and Operations user with the UPN "john@contoso.com" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 4
```
Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts
```

This command retrieves all Finance and Operations users, including Microsoft accounts, from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 5
```
Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts -AsExcelOutput
```

This command retrieves all Finance and Operations users, including Microsoft accounts, from the environment "ContosoEnv".
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve users from.

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
The name or ID of the user to filter the users by.

Can be either the user name, user ID or user principal name (UPN).

Supports wildcard characters for flexible matching.

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

### -IncludeMicrosoftAccounts
Instructs the cmdlet to include Microsoft accounts in the results.
By default, Microsoft accounts are excluded.

Microsoft accounts typically have aliases (UPNs) ending with domains like @dynamics.com, @microsoft.com, @onmicrosoft.com, @devtesttie.ccsctp.net or @capintegration01.onmicrosoft.com.

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
Instructs the cmdlet to export the retrieved user information to an Excel file.

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

## RELATED LINKS
