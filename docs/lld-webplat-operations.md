# Low-Level Design (LLD) — webplat Operations Runbook

| | |
|---|---|
| **Audience** | Azure administrators, platform support/on-call engineers |
| **Companion documents** | [HLD — Architecture](hld-webplat.md) (why it's built this way) · [webplat-architecture.md](webplat-architecture.md) (Bicep module reference, one-time setup, teardown) · [Kubernetes Showcase](kubernetes-showcase.md) (glossary of terms used below) |
| **Scope** | Exact resource inventory, identity/RBAC matrix, day-2 procedures, and a troubleshooting playbook built from real incidents on this platform |
| **Last updated** | 2026-09-18 |

If you're new to this platform, read the [HLD](hld-webplat.md) first for
the "why." This document assumes that context and gets straight to "how."

---

## 1. Resource inventory

### 1.1 Dev

| Resource | Name | Notes |
|---|---|---|
| Resource group | `rg-itsolutions-webplat-dev-uks-001` | UK South |
| AKS cluster | `aks-itsolutions-webplat-dev-uks-001` | Kubernetes `1.36.3`, control-plane tier `Free` |
| Node resource group | `rg-nodes-aks-itsolutions-webplat-dev-uks-001` | AKS-managed; contains the node VMSS, NSG, node-pool managed identities |
| System node pool | `aks-system-*-vmss` | 2 nodes, `Standard_D2s_v4` |
| User node pool | `aks-user-*-vmss` | autoscale 1–3, `Standard_D2s_v4` |
| Container registry | `acritsolutionswebplatdev001` | Premium SKU, `.azurecr.io` |
| Key Vault | `kvwebplatdev3r4cvt3hsiof` | RBAC-authorized |
| Application Gateway | `agw-itsolutions-webplat-dev-uks-001` | WAF_v2 |
| Public IP | `203.0.113.10` | |
| VNet | `vnet-itsolutions-webplat-dev-uks-001` | `10.30.0.0/16` |
| Ingress hostname | `dev-webplat.ict-cloud.solutions` | real DNS |

### 1.2 Prod

| Resource | Name | Notes |
|---|---|---|
| Resource group | `rg-itsolutions-webplat-prod-uks-001` | UK South |
| AKS cluster | `aks-itsolutions-webplat-prod-uks-001` | Kubernetes `1.36.3`, control-plane tier `Standard` (uptime SLA) |
| Node resource group | `rg-nodes-aks-itsolutions-webplat-prod-uks-001` | |
| System node pool | `aks-system-*-vmss` | 3 nodes, `Standard_D2s_v4` |
| User node pool | `aks-user-*-vmss` | autoscale 2–5, `Standard_D2s_v4` |
| Container registry | `acritsolutionswebplatprod001` | Premium SKU |
| Key Vault | `kvwebplatprod2su655bqyw7` | RBAC-authorized, public network access **disabled by default** |
| Application Gateway | `agw-itsolutions-webplat-prod-uks-001` | WAF_v2 |
| Public IP | `203.0.113.11` | |
| VNet | `vnet-itsolutions-webplat-prod-uks-001` | `10.31.0.0/16` |
| Ingress hostname | `www.itsolutions.example.com` | **placeholder — not a registered domain**; infra and TLS are real |

### 1.3 Shared

| Resource | Name |
|---|---|
| Log Analytics Workspace | `law-ictlabs-central-dev-uksouth` in `rg-ictlabs-connectivity-dev-uksouth` (prod also points here — no dedicated prod workspace exists yet) |
| GitHub OIDC app registration | `sp-itsolutions-webplat-github` |
| Entra ID admin group | `AKS-WebPlat-Admins` |
| Tenant ID | `fc1d277f-2fcb-4721-b141-1e117c362266` |

---

## 2. Access model

**There is no direct `kubectl` path from a laptop, by design** — the API
server has no public IP. Every operation — CI/CD and human alike — goes
through:

```bash
az aks command invoke -g <resource-group> -n <cluster-name> \
  --command "kubectl <your command>"
```

**Who can do this**: members of the **AKS-WebPlat-Admins** Entra ID group
(Azure RBAC for Kubernetes Authorization — `command invoke` runs as the
caller's real Azure identity, not a shared service account). Onboarding
or offboarding an admin is a group-membership change; no redeploy, no
credential rotation.

**Attaching a file** (e.g. applying a manifest): `command invoke` flattens
every `--file` argument into one flat directory by basename — a
base+overlay Kustomize layout collides (`kustomization.yaml` in both
`base/` and the overlay). Always render to a single file first:

```bash
kubectl kustomize k8s/overlays/<env> > /tmp/rendered.yaml
az aks command invoke -g <rg> -n <cluster> \
  --command "kubectl apply -f rendered.yaml" --file /tmp/rendered.yaml
```

**⚠️ This bypasses the CI pipeline's image substitution.** The overlay's
`kustomization.yaml` carries the literal placeholders
`REPLACE_WITH_ACR_LOGIN_SERVER` / `REPLACE_WITH_IMAGE_TAG` — only
`webplat-app-deploy.yml`'s `sed` step fills them in. A manual render like
the one above ships those placeholders verbatim unless you substitute
them yourself first (see [§7.3](#73-a-manual-apply-shipped-a-placeholder-image-reference)).

---

## 3. Identity & RBAC matrix

Four managed identities, each scoped to exactly one downstream resource —
no identity is shared between purposes.

| Identity | Created by | Role | Scope | Purpose |
|---|---|---|---|---|
| Kubelet identity (`<cluster>-agentpool`) | AKS itself | `AcrPull` (`7f951dda-4ed3-4680-a7ca-43fe172d538d`) | The environment's ACR | Nodes pull images with zero stored credential |
| Key Vault Secrets Provider (CSI) identity | AKS add-on | `Key Vault Secrets User` (`4633458b-17de-408a-b874-0445c86b69e6`) + `Key Vault Certificate User` (`db79e9a7-68ee-4b58-9aeb-b90e7c24fcba`) | The environment's Key Vault | Syncs the TLS cert into a Kubernetes Secret |
| AGIC identity | AKS add-on | `Contributor` (`b24988ac-6180-42a0-ab88-20f7382dd24c`) | The Application Gateway resource | Reconfigures listeners/backend pools |
| AGIC identity | (same) | `Reader` (`acdd72a7-3385-48ef-bd42-f606fba81ae7`) | The resource group | Discovers the Gateway's dependencies |
| AGIC identity | (same) | `Network Contributor` (`4d97b98b-1d4f-4787-a291-c67834d212e7`) | `snet-appgw` subnet only | Subnet-join permission (separate from resource Contributor) |
| Deploy identity (`sp-itsolutions-webplat-github`) | Manual, one-time | `Contributor` + `User Access Administrator` | Each resource group | Bicep deploys, including creating the role assignments above |

**Human admin access** is separate from all of the above: Entra ID group
membership (`AKS-WebPlat-Admins`) → Azure RBAC Cluster Admin role on the
AKS resource. Not a managed identity, not in this table's chain.

**Getting a specific identity's client ID** (needed for anything touching
the CSI driver's `SecretProviderClass`, since the mount uses the client
ID, not the object ID):

```bash
az aks show -g <rg> -n <cluster> \
  --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv
```

---

## 4. Day-2 operations

| Task | Procedure |
|---|---|
| **Ship a content change** | Edit `app/site/`, push to the default branch → `webplat-build-push.yml` builds/tags/pushes → `webplat-app-deploy.yml` rolls it out |
| **Scale the app manually** | Edit `replicas` / HPA bounds in `k8s/overlays/<env>/kustomization.yaml`, PR, merge — or, for an immediate change: `az aks command invoke ... --command "kubectl -n demo-web scale deployment/demo-web --replicas=N"` (the HPA will still reconcile toward its own target afterward) |
| **Rotate the TLS certificate** | `az keyvault certificate create --vault-name <kv> --name webplat-tls-cert --policy "$(az keyvault certificate get-default-policy)"` — no redeploy; the CSI driver re-syncs automatically. **Prod's vault is private by default** — see [§4.1](#41-reaching-a-private-key-vault-for-admin-operations) first |
| **Recover from a bad deploy** | `az aks command invoke ... --command "kubectl -n demo-web rollout undo deploy/demo-web"` |
| **Onboard/offboard an admin** | Add/remove the person from the `AKS-WebPlat-Admins` Entra ID group — no redeploy |
| **Bump the Kubernetes version** | Update `kubernetesVersion` in `webplat-dev.bicepparam` first, verify, then `webplat-prod.bicepparam` — recommended cadence: quarterly |
| **Check what's actually running** | `az aks command invoke ... --command "kubectl -n demo-web get deployment,replicaset,pods -o wide"` — see [§7.3](#73-a-manual-apply-shipped-a-placeholder-image-reference) if you see more than one ReplicaSet |
| **Check ACR pull activity** | KQL against the shared workspace: `ContainerRegistryLoginEvents \| where Identity has "<cluster-name>"` |
| **Confirm the Application Gateway sees healthy backends** | `az network application-gateway show-backend-health -g <rg> -n <appgw> --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address, health:health}" -o table` (note: `-o table` alone on the un-queried output renders blank — the nested structure needs flattening first) |

### 4.1 Reaching a private Key Vault for admin operations

Both environments' Key Vaults are private by default
(`publicNetworkAccess: Disabled`, RBAC-authorized). There is no VPN or
Bastion host in this environment, so a direct `az keyvault` call from an
admin's machine fails with `ForbiddenByConnection` until public access is
temporarily, deliberately opened:

```bash
# 1. Confirm you have RBAC on the vault first (separate from network access)
#    — you need "Key Vault Certificates Officer" scoped to this vault.
#    If not: az role assignment create --role "Key Vault Certificates Officer" \
#      --assignee <your-object-id> --scope <vault-resource-id>

# 2. Temporarily open public access
az keyvault update --name <kv-name> --public-network-access Enabled

# 3. Allow your current IP (force IPv4 — ifconfig.me can silently return
#    IPv6, which breaks a /32 rule with no error)
MYIP=$(curl -4 -s ifconfig.me)
az keyvault network-rule add --name <kv-name> --ip-address "$MYIP"
sleep 60   # propagation

# 4. Do the operation (certificate create/show/etc.)

# 5. Revert — this is a temporary exception, not the vault's steady state
az keyvault network-rule remove --name <kv-name> --ip-address "$MYIP"
az keyvault update --name <kv-name> --public-network-access Disabled
```

---

## 5. Monitoring and alerting

All AKS, ACR, and Key Vault diagnostics flow into the shared Log Analytics
Workspace (`law-ictlabs-central-dev-uksouth`) — the same one the
organization's Sentinel/SOC dashboards already query.

| Signal | Query / where to look |
|---|---|
| ACR pull events | `ContainerRegistryLoginEvents \| where Identity has "<cluster-name>" \| where TimeGenerated > ago(7d)` — use a 7-day (not 24h) window; a pod's pull event predates its current age and a short window returns nothing even when pulls are working fine |
| Cluster provisioning/health | `az aks show -g <rg> -n <cluster> --query "{provisioningState:provisioningState, powerState:powerState.code}"` |
| Defender for Cloud coverage | Defender for Cloud → Inventory → filter by resource group (no reliable CLI equivalent — Resource Graph confirms the resource exists but not its compliance/recommendation state) |
| Pod-level health | `kubectl -n demo-web get pods -o wide` via `command invoke` — READY column and RESTARTS are the first things to check |
| Application Gateway backend health | `show-backend-health` (see §4 above) — empty output with zero rows (not "Unhealthy") means AGIC has no backend registered at all, which is a stronger signal than an unhealthy probe |

**A helper script exists** for capturing a full evidence/health snapshot
of either environment in one pass:
[`scripts/capture-webplat-evidence.sh`](../scripts/capture-webplat-evidence.sh)
`{dev|prod}`.

---

## 6. Disaster recovery

The application is stateless — no PersistentVolumes, no database. DR is
"redeploy from Git + redeploy the last-known-good image tag from ACR."
RPO is effectively zero (no persistent data to lose); RTO is the time to
re-run the Bicep deploy plus `kubectl apply` — well under an hour for
either environment.

Full teardown procedure (resource groups, and what's intentionally left
outside them) is in
[webplat-architecture.md → Tearing down an environment](webplat-architecture.md#tearing-down-an-environment).

---

## 7. Troubleshooting playbook

Built from real incidents on this platform, not hypotheticals — every
entry below was hit live and root-caused on either dev or prod.

### 7.1 `502 Bad Gateway` with healthy pods and a correct listener/TLS config

**Symptom**: `kubectl get pods` shows `Running`, TLS handshake succeeds,
but the Application Gateway returns 502.
**Root cause**: Azure CNI **Overlay** mode — pod IPs aren't routable
outside the cluster, and AGIC's backend pool needs to reach pods
directly. This is a hard incompatibility, not a config issue.
**Fix**: switch to standard/flat Azure CNI (`modules/aks.bicep` —
`networkProfile` with no `networkPluginMode`). **CNI mode is immutable
after cluster creation** — this requires deleting and recreating the
cluster, not a config change on the running one.

### 7.2 The overlay-parity problem

**Symptom**: one environment works; an otherwise-identical environment
fails with an error referencing a literal placeholder string (e.g.
`Invalid vault name: "REPLACE_WITH_KEY_VAULT_NAME"`).
**Root cause**: `k8s/overlays/{dev,prod}/kustomization.yaml` are
hand-maintained, independent files. A patch added to one (e.g. the
`SecretProviderClass` patch with real Key Vault values) is not
automatically present in the other. Kustomize has no built-in mechanism
to enforce parity between sibling overlays.
**Fix**: compare the failing overlay against a working one for the
missing patch block; add it with that environment's real values (see
`git log` on `k8s/overlays/*/kustomization.yaml` for the exact patch
shape). **Prevention**: when adding a patch to one overlay, always check
whether every other overlay needs the same one.

### 7.3 A manual apply shipped a placeholder image reference

**Symptom**: `kubectl get pods` shows a new pod in `InvalidImageName` or
`ImagePullBackOff`, alongside older pods still `Running` normally, on two
different ReplicaSet hashes.
**Root cause**: `k8s/overlays/<env>/kustomization.yaml`'s image block
carries literal placeholders (`REPLACE_WITH_ACR_LOGIN_SERVER`,
`REPLACE_WITH_IMAGE_TAG`) that only `webplat-app-deploy.yml`'s `sed` step
substitutes. A manually rendered-and-applied `kubectl kustomize | kubectl
apply` (e.g. while debugging something else) ships those placeholders
verbatim, which changes the Deployment's pod template and creates a
*new*, broken ReplicaSet alongside the old, working one.
**Fix**:
```bash
# Find a known-good image reference from a Running pod
az aks command invoke -g <rg> -n <cluster> \
  --command "kubectl -n demo-web get pod <a-running-pod> -o jsonpath='{.spec.containers[0].image}'"
# Patch the Deployment back to it directly
az aks command invoke -g <rg> -n <cluster> \
  --command "kubectl -n demo-web set image deployment/demo-web demo-web=<that-image>"
```
The broken ReplicaSet scales itself to zero automatically once the
Deployment's pod template no longer matches it — no manual cleanup
needed.

### 7.4 TLS secret mount fails — `Invalid vault name`

**Symptom**: `kubectl describe pod` shows `FailedMount` for volume
`webplat-tls-secrets`, error text containing `REPLACE_WITH_KEY_VAULT_NAME`.
**Root cause**: see §7.2 — this specific manifestation of it.
**Fix**: see §7.2.

### 7.5 TLS secret mount fails — `SecretNotFound` (404)

**Symptom**: same `FailedMount` symptom as §7.4, but the error is a clean
404 naming the real vault, not a placeholder.
**Root cause**: the `SecretProviderClass` now points at the right vault
and identity, but the certificate object itself was never created in
*that* vault. (Each environment has its own Key Vault — a cert existing
in dev's says nothing about prod's.)
**Fix**: create the certificate (see §4.1) in the specific vault the
failing pod is pointed at.

### 7.6 `ForbiddenByRbac` on a Key Vault operation

**Symptom**: `az keyvault certificate ...` fails with `Code: Forbidden`,
`ForbiddenByRbac`.
**Root cause**: your own identity, not the AKS add-on identity, lacks a
Key Vault RBAC role on that specific vault. These are two entirely
separate principals — granting the AKS add-on's identity access (which
`bicep/webplat.bicep` does automatically) does not grant *your* access.
**Fix**: `az role assignment create --role "Key Vault Certificates
Officer" --assignee <your-object-id> --scope <vault-resource-id>`. Allow
~60 seconds for RBAC propagation before retrying.

### 7.7 `ForbiddenByConnection` on a Key Vault operation

**Symptom**: `Code: Forbidden`, `ForbiddenByConnection`, `Public network
access is disabled`.
**Root cause**: the vault's network ACL is doing exactly what it's
designed to do — you're not RBAC-forbidden, you're network-forbidden.
**Fix**: see [§4.1](#41-reaching-a-private-key-vault-for-admin-operations)
in full — this is expected, not a bug, and the exception must be
temporary.

### 7.8 App Gateway backend pool shows zero registered servers (not "Unhealthy" — *empty*)

**Symptom**: `show-backend-health` returns no rows at all; `curl` to the
public IP times out on port 443 (a connection timeout, not a TLS or HTTP
error — nothing is listening/routing at all).
**Root cause**: AGIC has never successfully reconciled a backend pool for
this environment, almost always because no pod has ever reached `Ready`
(a chicken-and-egg symptom of one of §7.1/§7.4/§7.5 above, not a new root
cause of its own).
**Fix**: diagnose why pods aren't `Ready` first (`kubectl describe pod`,
Events section) — the Gateway will self-heal once a healthy backend
exists; there is no separate Gateway-side action needed.

### 7.9 AGIC pod `CrashLoopBackOff` / `403 ApplicationGatewayForbidden`

**Symptom**: the AGIC add-on pod itself (in `kube-system`) is unhealthy,
logs show a 403 against the Application Gateway management API.
**Root cause**: bring-your-own-gateway AGIC mode does not auto-grant the
add-on's identity RBAC the way some `az aks` CLI flows do for a
Gateway AKS creates itself.
**Fix**: confirm the three AGIC role assignments in
[§3](#3-identity--rbac-matrix) all exist — Contributor on the Gateway,
Reader on the resource group, *and* Network Contributor on `snet-appgw`
specifically (Contributor on the Gateway does not include subnet-join
permission — that's a separate grant, commonly the one that's missing).

### 7.10 ACR pull events query returns zero rows

**Symptom**: the KQL query in [§5](#5-monitoring-and-alerting) comes back
empty even though images are clearly pulling fine (pods are `Running`).
**Root cause**: not a bug — a pod's image pull happens once, at creation.
If the pod is older than your query's lookback window, the original pull
event is simply outside the window. This is not evidence of a problem.
**Fix**: widen the window (7 days catches almost everything); or trigger
a fresh pull (rolling restart) if you need a pull event inside a specific
short window for verification purposes.

---

## 8. Command reference cheat sheet

```bash
# Cluster access (only path in — no direct kubectl)
az aks command invoke -g <rg> -n <cluster> --command "kubectl <cmd>"

# Pod / deployment status
az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web get pods -o wide"
az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web describe pod -l app=demo-web"
az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web get deployment,replicaset"

# Force a rollout retry
az aks command invoke -g <rg> -n <cluster> --command "kubectl -n demo-web delete pod -l app=demo-web"

# Cluster overview
az aks show -g <rg> -n <cluster> --query "{provisioningState:provisioningState, kubernetesVersion:currentKubernetesVersion, privateFqdn:privateFqdn}"

# App Gateway backend health (flattened)
az network application-gateway show-backend-health -g <rg> -n <appgw> \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address, health:health}" -o table

# End-to-end HTTPS check (no real DNS needed — resolves the hostname to the Gateway's IP locally)
PUBLIC_IP=$(az network public-ip list -g <rg> --query "[0].ipAddress" -o tsv)
curl -kI --resolve <hostname>:443:$PUBLIC_IP https://<hostname>/
```
