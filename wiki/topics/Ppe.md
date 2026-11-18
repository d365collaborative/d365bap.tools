<!--
topic: d365bap.tools.Ppe
keywords: ppe, power platform environment, maker, solutions, publishers, custom api, odata, publish customizations
-->

# Ppe

The Ppe namespace is the maker surface of a single Power Platform environment, the part you normally visit at [make.powerplatform.com](https://make.powerplatform.com).

Where the Ppac namespace administers environments, Ppe works inside one.

## Solutions

- Get-PpeSolution - the solutions in an environment.
- Add-PpeSolution - import a solution.
- Remove-PpeSolution - remove a solution.
- Get-PpeSolutionHistory - import and export history, useful after failed imports.
- Invoke-PpePublishAllCustomizations - start the publish-all-customizations process.

```pwsh
Add-PpeSolution -EnvironmentId "es-ude-motz-01" -Path "C:\temp\solution.zip"
Invoke-PpePublishAllCustomizations -EnvironmentId "es-ude-motz-01"
```

## Publishers

- Get-PpePublisher - the publishers an environment knows.
- Add-PpePublisher - register a publisher, usually the first step before authoring solutions programmatically.

## Custom APIs

- Get-PpeCustomApi - the custom APIs defined in an environment, including their request and response parameters.

## Dataverse OData

The same OData endpoint the maker tooling uses, for reading environment data:

- Get-PpeOdataEntity - the entities an environment exposes.
- Get-PpeOdata - query an entity.

Reading finance and operations data through the ERP endpoints instead? That is the Fscm namespace, see [Fscm](Fscm).
