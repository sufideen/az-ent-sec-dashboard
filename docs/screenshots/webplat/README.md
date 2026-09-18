# Webplat evidence

This folder holds screenshots/output captured from the real webplat
deployment (both `rg-itsolutions-webplat-dev-uks-001` and
`rg-itsolutions-webplat-prod-uks-001` exist in Azure) as evidence the
platform is actually up and serving traffic, not just that the Bicep
compiles. Nothing here is synthetic. Captured so far:

| Filename | Evidence of | Captured |
|---|---|---|
| `00-resource-groups-dev-and-prod.png` | Both dev and prod resource groups (plus their AKS node resource groups) exist in the subscription | 2026-09-18, Azure Portal → Resource Manager → Resource groups |

The rest of the checklist below is still a placeholder — these were shown
inline during the original deployment/troubleshooting session (see
[`../webplat-architecture.md`](../webplat-architecture.md) for the full
incident log) but the image files weren't saved to disk at the time. Add
the actual file using these names next time each is captured. **If a
teardown of dev/prod is imminent, capture these now** — they can't be
recaptured once the resource groups are deleted.

| Filename | Evidence of | Command / where to look |
|---|---|---|
| `01-nodes-ready.png` | AKS nodes healthy | `az aks command invoke -g <rg> -n <cluster> --command "kubectl get nodes -o wide"` |
| `02-pods-running.png` | App pods scheduled and passing readiness | `az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web get pods -o wide"` |
| `03-appgw-backend-healthy.png` | AGIC wired the App Gateway backend pool correctly | Azure Portal → Application Gateway → Backend health |
| `04-curl-https-200.png` | End-to-end HTTPS ingress serving the real app | `curl -kI https://<dev-hostname>/` → `HTTP/1.1 200`, plus `curl -k https://<dev-hostname>/healthz` → `200` |
| `05-acr-pull-event.png` | Kubelet identity pulling images with zero stored credentials (no admin user) | Log Analytics query: `ContainerRegistryLoginEvents \| where Identity has "aks-itsolutions-webplat-dev"` |
| `06-portal-aks-overview.png` | Cluster provisioning state, private API server, node pool status | Azure Portal → AKS cluster → Overview |
| `07-node-rg-contents.png` | Node resource group holding real compute (VMSS node pools, managed identities, NSG, private DNS zone, public IP) | Azure Portal → `rg-nodes-aks-itsolutions-webplat-<env>-uks-001` → Resources |
| `08-defender-inventory.png` | Cluster showing up in Defender for Cloud inventory | Defender for Cloud → Inventory → filter by resource group |

## Adding a new screenshot

1. Save the image as one of the filenames above (or add a new row here if it's
   evidence of something not yet covered).
2. Keep images reasonably sized (crop to the relevant panel, not a full
   4K desktop capture) — this is a git repo, not a media store.
3. Screenshots may show subscription IDs, resource names, or internal IPs.
   Review before committing; redact anything that shouldn't be public if this
   repo is ever made public.
