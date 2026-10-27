# Table format views

Create and maintain table views here. One file per type:

`<TypeName>.Table.Format.ps1xml`

Do not edit `../../d365bap.tools.Table.Format.ps1xml`. Push only the per-type
file; CI builds the consolidated format in staging for the PR import check
and again when packaging a release.

Local preview only (never commit the result):

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
