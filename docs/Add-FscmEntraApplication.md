---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-FscmEntraApplication

## SYNOPSIS
Add a registered Entra (AAD) application to a Finance and Operations environment.

## SYNTAX

```
Add-FscmEntraApplication [-EnvironmentId] <String> [-ClientId] <String> [[-Name] <String>]
 [-MappedUser] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Registers an Entra (Azure AD) application in the Finance and Operations environment by creating a record in the SysAADClients OData entity.

Before creating the record, the cmdlet validates that:
- The MappedUser exists as a user in the Finance and Operations environment.
- The ClientId is not already registered in the environment.

## EXAMPLES

### EXAMPLE 1
```
Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -MappedUser "svc-integration"
```

This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001", mapped to the user "svc-integration", in the environment "ContosoEnv".

### EXAMPLE 2
```
Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -MappedUser "svc-integration@contoso.com"
```

This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001", mapped to the user with UPN "svc-integration@contoso.com", in the environment "ContosoEnv".

### EXAMPLE 3
```
Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -Name "Contoso Integration App" -MappedUser "svc-integration"
```

This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001" and display name "Contoso Integration App", mapped to the user "svc-integration", in the environment "ContosoEnv".

## PARAMETERS

### -EnvironmentId
The ID of the environment to register the Entra application in.

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

### -ClientId
The AAD Client ID (application ID GUID) of the Entra application to register.

Must not already be registered in the environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
The display name to assign to the registered Entra application.

If empty, the Name will be the same as the ClientId.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MappedUser
The Finance and Operations user to map the Entra application to.

Can be either the user name, user ID or user principal name (UPN).

Must exist as a user in the Finance and Operations environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 4
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
