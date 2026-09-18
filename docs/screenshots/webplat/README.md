# Webplat evidence

This folder holds screenshots/output captured from the real webplat
deployment (both `rg-itsolutions-webplat-dev-uks-001` and
`rg-itsolutions-webplat-prod-uks-001` exist in Azure, both fully verified
end-to-end) as evidence the platform is actually up, not just that the
Bicep compiles. Nothing here is synthetic. Browser chrome showing unrelated
bookmarks/tabs (other client work) is redacted from screenshots before
committing — see the note at the bottom.

Prod needed a live fix to get here — see
[Incident: prod SecretProviderClass never patched](../webplat-architecture.md#incident-prod-secretproviderclass-never-patched)
for the full root cause and fix.

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
| `07-pods-running-dev.txt` / `-prod.txt` | `demo-web` pods `Running` and passing readiness in both environments |
| `08-appgw-backend-healthy-dev.txt` / `-prod.txt` | AGIC-wired Application Gateway backend pool `Healthy` for every pod IP, both environments |
| `09-curl-https-200-dev.txt` / `-prod.txt` | End-to-end HTTPS ingress: `curl` returns `HTTP/1.1 200 OK` with the real app body, `/healthz` returns `ok`, both environments |
| `11-portal-aks-overview-dev.txt` / `-prod.txt` | Cluster `provisioningState: Succeeded`, private FQDN only, `Running` power state, both environments |
| `12-defender-inventory-dev.txt` / `-prod.txt` | Cluster confirmed in the subscription's Resource Graph, both environments |

Captured with [`../../scripts/capture-webplat-evidence.sh`](../../scripts/capture-webplat-evidence.sh)
(`dev` and `prod`) — re-run it any time to refresh these `.txt` files; they
need no redaction (plain terminal text, no browser chrome).

## Known gap

`10-acr-pull-event-{dev,prod}.txt` comes back empty on both environments
even at a 7-day lookback. ACR's diagnostic setting doesn't backfill history,
and both environments' pods were already older than that window by the
time diagnostics were confirmed wired up — the original pull genuinely
predates what's been exported to Log Analytics. Not a live problem (images
are clearly pulling fine — pods are `Running`), just unproven by this
specific piece of evidence. Re-run the script after any future rolling
restart/redeploy and it should populate.

## Adding a new screenshot

1. Save the image as one of the filenames above (or add a new row here if it's
   evidence of something not yet covered).
2. Keep images reasonably sized (crop to the relevant panel, not a full
   4K desktop capture) — this is a git repo, not a media store.
3. Screenshots may show subscription IDs, resource names, tenant/subscription
   details, or unrelated browser tabs/bookmarks (other client work). Review
   before committing and redact/crop anything that shouldn't be here.
