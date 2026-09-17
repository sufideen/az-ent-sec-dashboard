# Secure AKS Web Platform (`webplat`)

A self-contained workload for hosting a company website: a private AKS
cluster, a private Azure Container Registry, GitHub Actions CI/CD (OIDC, no
stored secrets), and a working Nginx demo app. It is independent of the
`secops` platform deployed by `bicep/main.bicep` — it does not modify that
template — but reuses its CAF naming convention and its existing Log
Analytics Workspace, so AKS/ACR show up as two more monitored resource types
in the same Sentinel/SOC pipeline the rest of this repo already reports on.

## Architecture

```
                                Internet
                                    |
                          Application Gateway (WAF_v2)
                          public IP, TLS termination
                          snet-appgw (10.30.16.0/24)
                                    |
                    AGIC add-on reconfigures listeners/rules
                                    |
                    +---------------------------------+
                    |   AKS cluster (private API server) |
                    |   snet-aks (10.30.0.0/20)          |
                    |   - system node pool (mode=System) |
                    |   - user node pool (mode=User)     |
                    |   - namespace: demo-web            |
                    +---------------------------------+
                          |                    |
                   AcrPull (kubelet MI)   Key Vault Secrets User/
                          |               Certificate User (CSI add-on MI)
                          v                    v
                  Azure Container Registry   Key Vault
                  (Premium, private,          (RBAC-authorized,
                   no admin user)              TLS cert storage)
                  snet-pe (10.30.17.0/24) <----+

  Diagnostics (AKS, ACR, Key Vault) -> existing Log Analytics Workspace
  (same workspace the secops Sentinel/SOC dashboards already query)
```

Resource groups: `rg-itsolutions-webplat-dev-uks-001`,
`rg-itsolutions-webplat-prod-uks-001`.

### Security posture

- **No public AKS API server** — `apiServerAccessProfile.enablePrivateCluster: true`,
  AKS-managed private DNS zone.
- **No ACR admin user** — nodes pull images via the AKS kubelet's managed
  identity, granted `AcrPull` scoped to the registry only. ACR's public
  network access is enabled with a default-allow network rule set (no IP
  allowlist) because GitHub-hosted Actions runners push from outside this
  VNet and have no fixed IP range to allow-list; AKS's own pulls still use
  the private endpoint/DNS zone. The registry is public-reachable but
  identity-gated, not network-gated — push/pull is gated entirely by Entra
  ID + RBAC either
  way - a self-hosted, VNet-joined runner (see Deferred) would allow going
  fully private.
- **Entra ID + Azure RBAC for Kubernetes authorization** — cluster access is
  an Entra ID group membership (`aksAdminsGroupObjectId`), not a static
  kubeconfig or client certificate. `disableLocalAccounts: true`.
- **GitHub Actions authenticates via OIDC federated credentials** — zero
  Azure client secrets stored in GitHub.
- **Least-privilege, per-job role assignments** — the Terraform-equivalent
  Bicep deploy job needs `Contributor` + `User Access Administrator` on the
  resource group (it creates role assignments); the build job gets
  `AcrPush` scoped to the registry only; the app-deploy job gets a role
  permitting `Microsoft.ContainerService/managedClusters/runcommand/action`
  plus an Azure RBAC Kubernetes role scoped to the `demo-web` namespace.
- **Pod security**: non-root (`runAsUser: 101`), read-only root filesystem,
  all Linux capabilities dropped, `seccompProfile: RuntimeDefault`.
- **NetworkPolicy**: default-deny, explicit allow only from the AGIC
  ingress path; egress limited to DNS.
- **TLS termination at Application Gateway (WAF_v2)** — the certificate is
  stored in a dedicated, RBAC-authorized Key Vault and synced into the
  cluster as a Kubernetes TLS Secret via the AKS Key Vault Secrets Provider
  (CSI) add-on — see [Rotate the TLS certificate](#rotate-the-tls-certificate).
- **Diagnostic logging** for AKS, ACR, and Key Vault into the existing,
  governed Log Analytics Workspace; Defender for Containers and the Azure
  Policy add-on are both enabled on the cluster.
- **NSGs** restrict all subnet-to-subnet and Internet traffic to the
  Application Gateway path only (see `modules/network.bicep`).

## Repository layout

```
bicep/webplat.bicep                 # orchestrator (this workload)
bicep/params/webplat-{dev,prod}.bicepparam
modules/{network,acr,aks,appgw-ingress}.bicep   # new, webplat-specific
modules/{key-vault,diagnostic-settings}.bicep    # reused from the secops platform
app/                                 # demo Nginx static site + Dockerfile
k8s/base/                            # namespace, deployment, service, ingress,
                                      # hpa, networkpolicy, SecretProviderClass
k8s/overlays/{dev,prod}/             # per-environment image tag, replicas, hostname
.github/workflows/webplat-*.yml      # lint, what-if, infra deploy, image build, app deploy
```

## One-time setup (before first deploy)

1. **Create resource groups**: `rg-itsolutions-webplat-dev-uks-001` and
   `rg-itsolutions-webplat-prod-uks-001`.
2. **Create the `AKS-WebPlat-Admins` Entra ID group** and add its object ID
   to `aksAdminsGroupObjectId` in both `.bicepparam` files.
3. **Register the OIDC app** for GitHub Actions:
   ```bash
   az ad app create --display-name sp-itsolutions-webplat-github
   az ad sp create --id <appId>
   ```
   Add federated credentials for:
   - `repo:sufideen/az-ent-sec-dashboard:ref:refs/heads/main`
   - `repo:sufideen/az-ent-sec-dashboard:pull_request`
   - `repo:sufideen/az-ent-sec-dashboard:environment:production`

   Then assign roles scoped to each resource group (`Contributor` +
   `User Access Administrator` for the deploy identity), and — once the ACR
   and AKS resources exist — `AcrPush` scoped to the registry and a
   cluster-scoped run-command role for the app-deploy job.
4. **GitHub secrets/vars**: `AZURE_CLIENT_ID_WEBPLAT`, `AZURE_TENANT_ID`,
   `AZURE_SUBSCRIPTION_ID`; `RESOURCE_GROUP_DEV_WEBPLAT`,
   `RESOURCE_GROUP_PROD_WEBPLAT`, `ACR_NAME_DEV`, `ACR_NAME_PROD`,
   `AKS_NAME_DEV`, `AKS_NAME_PROD`.
5. **Deploy the infra** — merging to `main` (or `workflow_dispatch` on
   `webplat-deploy.yml`) runs `bicep/webplat.bicep` against dev
   automatically, then prod behind the `production` environment's approval
   gate.
6. **Create the TLS certificate** in the Key Vault the deploy created (name
   is in the deployment outputs):
   ```bash
   az keyvault certificate create --vault-name <kv-name> \
     --name webplat-tls-cert \
     --policy "$(az keyvault certificate get-default-policy)"
   ```
   (Self-signed by default — swap for a real CA cert later via the same
   command with a custom policy; no redeploy needed.)
7. **Fill in the placeholders** in `k8s/base/secretproviderclass.yaml`
   (`userAssignedIdentityID` = the `keyVaultSecretsProviderIdentityClientId`
   deployment output of `bicep/webplat.bicep` — this is the add-on's
   **client ID**, a different value from the object ID used internally for
   the Key Vault role assignment; `keyvaultName`, `tenantId`) and the
   hostnames in `k8s/overlays/{dev,prod}/kustomization.yaml`.
8. **Build and deploy the app** — pushing to `app/**` on `main` runs
   `webplat-build-push.yml`, which triggers `webplat-app-deploy.yml`.

## Administrator operations

### Access model

The API server has no public IP, so there is no direct `kubectl` path from
a laptop by design. Both CI and human administrators use the same
mechanism:

```bash
az aks command invoke -g rg-itsolutions-webplat-prod-uks-001 \
  -n aks-itsolutions-webplat-prod-uks-001 \
  --command "kubectl get pods -n demo-web"
```

Who can run this: members of the **AKS-WebPlat-Admins** Entra ID group
(the same group configured as `aksAdminsGroupObjectId`). Onboarding or
offboarding an administrator is a group-membership change — no redeploy.

### Runbook checklist

| Task | How |
|---|---|
| Ship a site content change | Edit `app/site/`, push to `main` -> build-push tags & pushes a new image -> app-deploy rolls it out via `command invoke` |
| Scale the app | Adjust `replicas` / HPA bounds in the relevant `k8s/overlays/<env>/kustomization.yaml`, PR, merge |
| Rotate the TLS certificate | `az keyvault certificate import --vault-name <kv> --name webplat-tls-cert --file <new.pfx>` — no redeploy, the CSI driver re-syncs automatically |
| Recover from a bad deploy | `az aks command invoke ... --command "kubectl -n demo-web rollout undo deploy/demo-web"` |
| Onboard/offboard an admin | Add/remove the person from the **AKS-WebPlat-Admins** Entra ID group |
| Check ACR pull activity | Query `ContainerRegistryLoginEvents` / `ContainerRegistryRepositoryEvents` in the shared Log Analytics Workspace |
| Bump the Kubernetes version | Update `kubernetesVersion` in `webplat-dev.bicepparam` first, verify, then `webplat-prod.bicepparam` (recommended cadence: quarterly) |

### Patching, backup/DR, cost

- **Node OS/patch**: kept current automatically via `autoUpgradeProfile`
  (`upgradeChannel: patch`, `nodeOSUpgradeChannel: NodeImage`) inside a
  weekly maintenance window (Sunday 02:00–06:00 UTC).
- **Backup/DR**: the app is stateless — no PersistentVolumes. DR is
  "redeploy from Git + redeploy the last-known-good image tag from ACR."
  RPO is effectively zero (no persistent data); RTO is the time to re-run
  the Bicep deploy + `kubectl apply` (well under an hour).
- **Cost**: every resource is tagged `environment`, `workload=webplat`,
  `managedBy=bicep`; dev starts at the smallest viable node counts and the
  `Free` AKS control-plane tier; prod uses the `Standard` tier for the
  uptime SLA. Budget alerts are a deferred follow-up (see below).
- **Secrets rotation**: minimal by design — no ACR admin user, no GitHub
  Actions client secret (OIDC). The TLS certificate is the only credential
  needing periodic rotation.

## Verification

1. `az bicep build --file bicep/webplat.bicep` compiles clean (also run by
   `webplat-bicep-lint.yml` in CI).
2. `az deployment group what-if --resource-group <rg> --template-file bicep/webplat.bicep --parameters bicep/params/webplat-dev.bicepparam`
   shows the expected resource set.
3. `az aks show -g <rg> -n <cluster> --query "{privateFQDN:privateFqdn, publicFQDN:fqdn}"`
   — only `privateFQDN` is populated.
4. `az aks command invoke -g <rg> -n <cluster> --command "kubectl get nodes -o wide"`
   returns `Ready` nodes.
5. Render the manifests locally first, then ship the single rendered file -
   `az aks command invoke` flattens every `--file` into one directory by
   basename (no subfolders preserved), which breaks a base+overlay
   kustomize layout outright (both `kustomization.yaml` files collide) and
   also rejects a bare directory in some CLI versions:
   ```bash
   kubectl kustomize k8s/overlays/dev > /tmp/rendered.yaml
   az aks command invoke ... --command "kubectl apply -f rendered.yaml" --file /tmp/rendered.yaml
   ```
   then `kubectl -n demo-web get pods` shows `Running` pods passing readiness.
6. `kubectl describe pod <pod>` shows no `ImagePullBackOff`; the ACR
   diagnostic logs in the shared Log Analytics Workspace show a `Pull`
   event tied to the AKS kubelet identity — proving `AcrPull` RBAC is
   doing the work, not an embedded credential.
7. `curl -k https://<app-gateway-public-ip-or-fqdn>/` returns the demo page
   (`-k` while using the initial self-signed certificate).
8. `az acr credential show -n <acr>` fails/shows disabled — admin user
   confirmed off.
9. Defender for Cloud → Inventory shows the new AKS cluster as monitored.

## Deferred (explicitly out of scope for the initial delivery)

Azure Firewall/Front Door in front of Application Gateway · WAF rule tuning
beyond the default OWASP managed ruleset · GitOps (Flux/Argo) replacing
direct `kubectl apply` in Actions · a real CA-issued certificate +
cert-manager automation · ACR geo-replication · Velero/AKS Backup (no
persistent volumes today) · Azure Bastion/jumpbox for interactive `kubectl`
· multi-region/multi-AZ resilience · a formal Azure Policy initiative
assignment (a layer-1 `azl-bicepdeploy` concern per this repo's existing
layering) · cost budgets/alerts · an AKS/ACR tile on the existing SOC
workbook (`workbooks/soc-dashboard.json`).
