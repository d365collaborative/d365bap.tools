---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacRbacContext

## SYNOPSIS
Authenticate for PPAC RBAC operations by obtaining an access token using user credentials.

## SYNTAX

```
Set-PpacRbacContext [[-Username] <String>] [[-Password] <String>] [[-ImpersonateAppId] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Authenticates for PPAC RBAC operations by obtaining an access token using user credentials.
This command is used to set the authentication context for subsequent PPAC RBAC operations in Power Platform.

The command uses the OAuth 2.0 Resource Owner Password Credentials (ROPC) flow to obtain an access token for the Microsoft Graph API, which is then used for authentication in PPAC RBAC operations.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacRbacContext -Username "alice@contoso.com" -Password "P@ssw0rd!" -ImpersonateAppId "00000000-0000-0000-0000-000000000000"
```

This command authenticates the user "alice@contoso.com" and sets the authentication context for subsequent PPAC RBAC operations using the specified app for impersonation.

## PARAMETERS

### -Username
The username of the user to authenticate with.

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

### -Password
The password of the user to authenticate with.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpersonateAppId
The application (client) id of the app to impersonate when authenticating.

The app needs to be registered in Azure AD and have the necessary API permissions to perform PPAC RBAC operations.

Consent to the permissions for the app needs to be granted by a tenant administrator before running this command.

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
