Welcome to the d365bap.tools wiki!

Here we will write small guides on how to accomplish different tasks by providing a guided example with all the different commands needed to get the job done.

## Concept topics

Conceptual documentation lives in `wiki/topics/` and ships inside the module as `about_*` help topics: run `Get-Help about_d365bap.tools` for the index, or `Get-Help about_d365bap.tools.<Topic>` for one concept.

- [Overview](Overview) · [Namespaces](NamespacesConcept)
- [Authentication](Auth) · [Tenants](Tenants) · [Operations](Operations)
- [Security](Security) · [Policies](Policies)
- [Bap](Bap) · [Fscm](Fscm) · [Ppe](Ppe) · [Ude](Ude) · [Unified](Unified)

Edit the pages in `wiki/topics/`; CI regenerates the `about_*.help.txt` files. Never edit those directly.

## Guides

- [AOS capacity math](AOS-Capacity-Math) - how the tenant AOS tier is derived from Power Platform Requests.
