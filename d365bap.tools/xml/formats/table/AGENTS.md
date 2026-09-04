# Table format views

Create and maintain table views here. One file per type:

`<TypeName>.Table.Format.ps1xml`

Do not edit `../../d365bap.tools.Table.Format.ps1xml`. After changing a file here, run from the repo root:

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
