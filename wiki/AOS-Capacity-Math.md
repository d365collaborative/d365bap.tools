# AOS capacity math

How `Get-PpacTenantCapacity` derives the computed `ApiCallCountAos` row from the
tenant's Power Platform Requests (PPR) entitlement, step by step.

Sources:

- Elastic compute for finance and operations apps (concepts, PPR accrual,
  650,000 PPR per AOS, min 2 / max 80 AOS):
  https://learn.microsoft.com/en-us/power-platform/admin/unified-experience/elastic-compute
- Tenant Capacity Details API (`GET licensing/tenantCapacity`), the read endpoint:
  https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/tenant-capacity-details/get-tenant-capacity-details
- Entitlement API (`OverageStatus`: `NotSpecified | WithinCapacity | Overage |
  CoveredOverage`), whose status vocabulary the row reuses:
  https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/entitlement/get-entitlement

## Step 1 — Read the tenant PPR total

`GET https://api.powerplatform.com/licensing/tenantCapacity?api-version=2024-10-01`
returns `tenantCapacities[]`. Take the entry with `capacityType == 'ApiCallCount'`;
its `totalCapacity` is the tenant's PPR pool. PPRs accrue from the 500,000 tenant-wide
base, 5,000 per assigned user license, and 50,000 per add-on pack
([accrual table](https://learn.microsoft.com/en-us/power-platform/admin/unified-experience/elastic-compute#how-you-accrue-pprs)).

Live tenant at time of writing: `totalCapacity = 1,330,000`
(Base 500,000 + Incremental 830,000).

## Step 2 — Cost of one AOS

Each AOS instance requires 650,000 PPRs of capacity
([PPR to AOS capacity](https://learn.microsoft.com/en-us/power-platform/admin/unified-experience/elastic-compute#how-pprs-translate-to-aos-capacity)).

## Step 3 — Raw tier, clamped to [2, 80]

`raw = floor(totalPPR / 650,000)`, then `current = clamp(raw, 2, 80)`.

- Floor of 2: every sandbox and production environment gets a minimum of two AOS
  instances (one interactive, one batch), regardless of PPRs.
- Ceiling of 80: an environment supports at most 80 AOS instances total, split
  between up to 40 interactive and up to 40 batch instances.

Both limits are from the
[minimum and maximum AOS](https://learn.microsoft.com/en-us/power-platform/admin/unified-experience/elastic-compute#minimum-and-maximum-aos)
section. Worked example: `floor(1,330,000 / 650,000) = floor(2.046) = 2`,
inside `[2, 80]`, so `current = 2`.

## Step 4 — Derived headroom figures

All in PPRs, from `current` and `total`:

| Value | Formula | Live example |
|---|---|---|
| `IntoCurrentTier` | `total − current × 650,000`, floored at 0 | `1,330,000 − 2 × 650,000 = 30,000` |
| `ToNextAos` | `(current + 1) × 650,000 − total` | `3 × 650,000 − 1,330,000 = 620,000` |
| `HeadroomToMax` | `80 × 650,000 − total` | `52,000,000 − 1,330,000 = 50,700,000` |

The 52,000,000 platform maximum (650,000 × 80) is stated in the docs'
[AOS formula](https://learn.microsoft.com/en-us/power-platform/admin/unified-experience/elastic-compute#check-your-tenants-aos-capacity-by-using-powershell)
section. `ToNextAos` goes negative only past the cap, which clamping prevents.

## Step 5 — The computed row

`ApiCallCountAos` reuses the standard capacity columns so it renders, filters,
and exports like every other row:

| Column | Value | Why |
|---|---|---|
| `CapacityType` | `ApiCallCountAos` | Selectable via `Api*` (pairs with the raw PPR row) or exactly |
| `Units` | `AOS` | Own unit, so the view formats counts, not megabytes |
| `Entitled` | 80 | The AOS ceiling |
| `Consumed` | `current` (2) | Tier in use |
| `Left` | `Entitled − Consumed` (78) | Headroom to the ceiling |
| `Status` | `WithinCapacity`, `Overage` if negative | Uniform rule, same `OverageStatus` vocabulary as `Get-PpacTenantEntitlement` |
| `BaseCapacity` | 2 | The guaranteed floor |
| `IncrementalCapacity` | `current − 2` (0) | Tier earned above the floor |
| `AddOnCapacity` | 0 | PPR add-ons accrue to the pool, not to AOS directly |
| `Entitlement` / `Licenses` | 0 | Computed row, no backing licenses |
| Extras | `ApiCallTotal`, `PerAos`, `MinAos`, `MaxAos`, `CurrentAos`, `IntoCurrentTier`, `ToNextAos`, `HeadroomToMax` | Full calc payload on the row itself |
| `Raw` | The `ApiCallCount` entry | Auditable back to the granted PPR total |

The row is emitted only when `ApiCallCount` survives `-CapacityType` filtering
(exact `ApiCallCount` yields the raw row alone; `Api*` yields both). `Raw` always
carries the untouched API payload, so the display formatting never alters types.

Note: a tenant-level FinOps license summary endpoint exists
(`FinOpsLicensing/GetLicenseSummaryV2`, same API family) but returned 403 for
our caller, so AOS capacity is computed from PPRs instead of read.
