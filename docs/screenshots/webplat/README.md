# Webplat evidence

This folder holds screenshots/output captured from the real webplat
deployment (both `rg-itsolutions-webplat-dev-uks-001` and
`rg-itsolutions-webplat-prod-uks-001` exist in Azure) as evidence the
platform is actually up, not just that the Bicep compiles. Nothing here is
synthetic. Browser chrome showing unrelated bookmarks/tabs (other client
work) is redacted before committing — see the note at the bottom.

## Captured

| Filename | Evidence of |
|---|---|
| `00-resource-groups-dev-and-prod.png` | Both dev and prod resource groups, plus their AKS node resource groups, exist in the subscription |
| `01-prod-nodepool-vmss-status.png` | Prod system node pool VMSS (`aks-system-15120143-vmss`): 3/3 instances succeeded, `Standard_D2s_v4` |
| `02-dev-nodepool-vmss-status.png` | Dev system node pool VMSS (`aks-system-66771379-vmss`): 2/2 instances succeeded, `Standard_D2s_v4` |
| `03-dev-node-rg-contents.png` | Dev node resource group: 13 resources — both VMSS node pools, managed identities (agentpool/Key Vault CSI/Azure Policy/AGIC), NSG, public IP, private DNS zone |
| `04-prod-private-dns-zone.png` | Prod's AKS-managed private DNS zone (`*.privatelink.uksouth.azmk8s.io`) — confirms the private API server, tagged `dataClassification: confidential` |
| `05-prod-loadbalancer.png` | Prod's AKS-managed Standard Load Balancer with 2 backend pools and an outbound rule |
| `06-prod-nodes-ready.png` | `kubectl get nodes` via `az aks command invoke` against the prod cluster: all 5 nodes (3 system + 2 user) `Ready`, `v1.36.3` — direct kubelet-level confirmation, not just VMSS instance health |

## Still outstanding

These need cluster/CLI access to capture (portal alone doesn't show pod or
HTTP-level state) and were only ever shown inline in the original chat
session, never saved to disk. **If a teardown of dev/prod is imminent,
capture these now** — they can't be recaptured once the resource groups are
deleted.

| Filename | Evidence of | Command / where to look |
|---|---|---|
| `07-pods-running.png` | App pods scheduled and passing readiness | `az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web get pods -o wide"` |
| `08-appgw-backend-healthy.png` | AGIC wired the Application Gateway backend pool correctly (different resource from the Standard Load Balancer captured above) | Azure Portal → Application Gateway → Backend health |
| `09-curl-https-200.png` | End-to-end HTTPS ingress serving the real app | `curl -kI https://<dev-hostname>/` → `HTTP/1.1 200`, plus `curl -k https://<dev-hostname>/healthz` → `200` |
| `10-acr-pull-event.png` | Kubelet identity pulling images with zero stored credentials (no admin user) | Log Analytics query: `ContainerRegistryLoginEvents \| where Identity has "aks-itsolutions-webplat-dev"` |
| `11-portal-aks-overview.png` | Cluster provisioning state, private API server, node pool status | Azure Portal → AKS cluster → Overview |
| `12-defender-inventory.png` | Cluster showing up in Defender for Cloud inventory | Defender for Cloud → Inventory → filter by resource group |

## Adding a new screenshot

1. Save the image as one of the filenames above (or add a new row here if it's
   evidence of something not yet covered).
2. Keep images reasonably sized (crop to the relevant panel, not a full
   4K desktop capture) — this is a git repo, not a media store.
3. Screenshots may show subscription IDs, resource names, tenant/subscription
   details, or unrelated browser tabs/bookmarks (other client work). Review
   before committing and redact/crop anything that shouldn't be here.
