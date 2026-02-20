---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacUser

## SYNOPSIS
Get information about users in a Power Platform environment.

## SYNTAX

```
Get-PpacUser [-EnvironmentId] <String> [[-User] <String>] [-IncludeAppIds] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves information about users in a Power Platform environment.
It allows filtering by user name or ID, including application users, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacUser -EnvironmentId "ContosoEnv"
```

This command retrieves all users from the Power Platform environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 2
```
Get-PpacUser -EnvironmentId "ContosoEnv" -User "john.doe"
```

This command retrieves the user with the name "john.doe" from the Power Platform environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 3
```
Get-PpacUser -EnvironmentId "ContosoEnv" -User "*john*"
```

This command retrieves all users with names, user IDs, UPNs or application IDs matching "*john*" from the Power Platform environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 4
```
Get-PpacUser -EnvironmentId "ContosoEnv" -IncludeAppIds
```

This command retrieves all users, including application users, from the Power Platform environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 5
```
Get-PpacUser -EnvironmentId "ContosoEnv" -IncludeAppIds -AsExcelOutput
```

This command retrieves all users, including application users, from the Power Platform environment "ContosoEnv".
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

Can be either the user name, user ID, user principal name (UPN) or application ID.

Supports wildcard characters for flexible matching.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Upn

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAppIds
Instructs the cmdlet to include application users (service principals) in the results.
By default, application users are excluded.

Application users can be identified by their application ID and typically do not have an email address or UPN.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
