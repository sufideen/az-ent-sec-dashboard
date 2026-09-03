# Cost Estimates

> **Estimates only.** Figures use approximate Azure pay-as-you-go retail pricing (East US, USD) as commonly published at time of writing and are **not a quote**. Actual costs depend on region, negotiated/EA pricing, commitment tiers, and real log volume. Always validate with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) against your tenant's actual ingestion before budgeting. This platform's own resources (workbooks, the alerting Logic App, Key Vault, RBAC) add negligible cost on top of the existing Sentinel/Defender/Monitor spend — the estimates below size the **whole security operations stack** this dashboard reports on, since that is what a budget conversation actually needs.

## Assumptions

- "Users" = licensed Entra ID identities generating sign-in/audit telemetry.
- Ingestion estimate: ~10-15 MB/user/day of combined SigninLogs, AuditLogs, and Defender-forwarded security events (typical for a standard M365 + Azure estate; heavier if verbose diagnostic logging or many custom data connectors are enabled).
- Defender for Cloud costs assume the **Defender for Servers Plan 2** and **Defender CSPM** plans; Defender for Storage/Key Vault/Containers priced per-resource where applicable.
- Sentinel pricing: pay-as-you-go analyzed-GB rate (~$2.46/GB, East US, PAYG tier); commitment tiers (100GB/day+) reduce effective rate materially at Large scale — noted below.
- Log Analytics: first 90 days retention included with Sentinel; long-term retention beyond that is billed per GB/month. Retention is a Log Analytics Workspace-level setting, configured on the workspace itself (outside this repo's scope, since it references the workspace as `existing`) — the 365-day figure below models a typical production retention policy, not something this platform's own Bicep sets.

## Small — 100 users

| Component | Assumption | Est. Monthly Cost (USD) |
|---|---|---|
| Log Analytics ingestion (Sentinel PAYG) | ~1.2 GB/day (~36 GB/mo) @ $2.46/GB | ~$89 |
| Log Analytics long-term retention (275 days beyond 90, prod only) | ~36 GB retained @ ~$0.10/GB/mo | ~$4 |
| Defender for Cloud (Servers P2, ~10 VMs) | $15/server/mo x 10 | ~$150 |
| Defender CSPM (foundational = free; standard, ~25 billable resources) | $5/resource/mo x 25 | ~$125 |
| Azure Monitor (Action Group notifications, alert rule evaluations) | Well under free tier thresholds | ~$5 |
| Logic App (Consumption, ~500 alert-driven runs/mo) | ~$0.000025/action x ~2,500 actions | <$1 |
| Key Vault (secret reads, ~1,000 ops/mo) | $0.03/10k ops | <$1 |
| Workbooks | No direct charge (billed only via underlying query cost, included above) | $0 |
| **Total** | | **~$375/month** |

## Medium — 1,000 users

| Component | Assumption | Est. Monthly Cost (USD) |
|---|---|---|
| Log Analytics ingestion (Sentinel PAYG) | ~12 GB/day (~360 GB/mo) @ $2.46/GB | ~$886 |
| Log Analytics long-term retention | ~360 GB @ ~$0.10/GB/mo | ~$36 |
| Defender for Cloud (Servers P2, ~75 VMs) | $15/server/mo x 75 | ~$1,125 |
| Defender CSPM (standard, ~200 billable resources) | $5/resource/mo x 200 | ~$1,000 |
| Defender for Storage (~20 storage accounts) | ~$10/account/mo (per-transaction sub-plan varies) | ~$200 |
| Azure Monitor | Alert volume still modest relative to free thresholds | ~$25 |
| Logic App (Consumption, ~5,000 runs/mo) | ~$0.000025/action x ~25,000 actions | ~$1 |
| Key Vault | ~10,000 ops/mo | ~$1 |
| Workbooks | $0 | $0 |
| **Total** | | **~$3,275/month** |

> At this scale, consider a **Sentinel 200 GB/day commitment tier** if actual ingestion approaches ~15-20 GB/day sustained — commitment tiers typically discount 30-40% vs. PAYG.

## Large — 5,000 users

| Component | Assumption | Est. Monthly Cost (USD) |
|---|---|---|
| Log Analytics ingestion (Sentinel **commitment tier**, ~60 GB/day, 500GB/day tier blended rate ~$1.50/GB) | ~1,800 GB/mo @ ~$1.50/GB | ~$2,700 |
| Log Analytics long-term retention | ~1,800 GB @ ~$0.10/GB/mo | ~$180 |
| Defender for Cloud (Servers P2, ~350 VMs) | $15/server/mo x 350 | ~$5,250 |
| Defender CSPM (standard, ~1,000 billable resources) | $5/resource/mo x 1,000 | ~$5,000 |
| Defender for Storage/Key Vault/Containers (mixed estate) | Blended estimate | ~$1,500 |
| Azure Monitor (higher alert volume, custom metrics) | | ~$150 |
| Logic App (Consumption, ~25,000 runs/mo) | ~$0.000025/action x ~125,000 actions | ~$3 |
| Key Vault | ~50,000 ops/mo | ~$2 |
| Workbooks | $0 | $0 |
| **Total** | | **~$14,785/month** |

## Cost levers

| Lever | Effect |
|---|---|
| Sentinel commitment tiers (100/200/500 GB/day) | 15-40% ingestion discount vs. PAYG once sustained volume justifies it |
| Data connector tuning (disable verbose/duplicate connectors, e.g. redundant firewall logs) | Directly reduces billed GB — often the single biggest lever |
| Log Analytics table-level retention overrides (Basic Logs / Auxiliary Logs for high-volume, low-value tables) | Cuts long-term retention cost for tables like `CommonSecurityLog` that don't need 365-day retention |
| Defender for Cloud plan selection per resource type | Disable plans (e.g. Defender for Containers) on subscriptions with no matching resources |
| Scheduled Analytics Rule frequency | This platform's 5 rules run hourly (`PT1H`), not continuously — minimizes query compute cost without materially harming detection latency for their use cases |
