<!--
topic: d365bap.tools.Fscm
keywords: fscm, finance and operations, odata, rest, dmf, entities, actions, token, installed models
-->

# Fscm

The Fscm namespace works directly against the finance and operations ERP, through the OData and REST endpoints the platform exposes.

Every command takes an environment id that accepts an environment name, a PPAC environment GUID or a legacy LCS id.

## Tokens first

```pwsh
Get-FscmOdataToken -EnvironmentId "es-ude-motz-01" -AsBearerToken
```

Tokens are minted from your current [authentication](Auth) and returned in memory - as raw text, as a bearer header value with -AsBearerToken, or as a typed object with -AsObject.

## Discover metadata before you call it

- Get-FscmOdataEntity - the OData entities an environment exposes.
- Get-FscmOdataAction - the OData actions.
- Get-FscmRestService - the custom REST services.
- Get-FscmDmfEntity - the data management (DMF) entities.

## Query and invoke

- Get-FscmOdata - query data from an OData entity.
- Invoke-FscmOdataAction - call an OData action.
- Invoke-FscmRestService - call a REST service operation.
- Invoke-FscmDmfEntityMetadataRefresh - refresh all DMF entity metadata, useful after model changes.

## Environment contents

- Get-FscmEnvironmentVersion - the version numbers an environment runs.
- Get-FscmInstalledModel - the models installed in an environment.

## Users and applications

The ERP has its own user and role store, separate from Dataverse security - see [Security](Security) for the difference:

- Add-FscmUser - create a user and assign a security role.
- Add-FscmUserFromSecurityGroup - create users from an Entra security group.
- Get-FscmUser / Remove-FscmUser / Set-FscmUserAccess - inspect, remove, enable or disable.
- Add-FscmEntraApplication / Get-FscmEntraApplication - register Entra applications with the ERP.

Reading ERP data through the maker-side OData instead? That is the Ppe namespace, see [Ppe](Ppe).
