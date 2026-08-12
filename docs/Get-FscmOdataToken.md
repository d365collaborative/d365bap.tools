---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmOdataToken

## SYNOPSIS
Get an OData access token for a Finance and Operations environment.

## SYNTAX

### Default (Default)
```
Get-FscmOdataToken -EnvironmentId <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Object
```
Get-FscmOdataToken -EnvironmentId <String> [-AsObject] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### BearerToken
```
Get-FscmOdataToken -EnvironmentId <String> [-AsBearerToken] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Acquires an Azure access token scoped to the Finance and Operations (FnO) OData resource of the specified environment, using the cached credentials in the local Azure PowerShell context.

The token is returned in plain text.
Handle the output accordingly.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmOdataToken -EnvironmentId "ContosoEnv"
```

This command acquires an OData access token for the environment "ContosoEnv" and returns the raw token string.

### EXAMPLE 2
```
Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsBearerToken
```

This command acquires an OData access token for the environment "ContosoEnv" and returns it as a bearer token string, ready to use directly in an Authorization header.

### EXAMPLE 3
```
$token = Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsObject
PS C:\> Invoke-RestMethod -Uri $uri -Headers @{ Authorization = $token.BearerToken }
```

This command acquires an OData access token for the environment "ContosoEnv" and returns a typed object with both Token and BearerToken properties.

## PARAMETERS

### -EnvironmentId
The ID of the environment to acquire the token for.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsBearerToken
Output the token as a "Bearer" prefix string, ready to use in an Authorization header.

```yaml
Type: SwitchParameter
Parameter Sets: BearerToken
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsObject
Output a typed PSCustomObject with Token and BearerToken properties.

```yaml
Type: SwitchParameter
Parameter Sets: Object
Aliases:

Required: True
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
