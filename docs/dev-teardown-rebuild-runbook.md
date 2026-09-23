# Dev teardown & rebuild runbook

What deleting `rg-itsolutions-webplat-dev-uks-001` actually destroys, and the
exact, battle-tested sequence to bring the dev AKS environment back up
afterward. This is the real order of steps a full dev rebuild needed the
last time it was done from scratch — see
[`webplat-architecture.md` §"Incident: prod SecretProviderClass never
patched"](webplat-architecture.md#incident-prod-secretproviderclass-never-patched)
for the narrative version of why several of these steps exist. For the raw
`az group delete` commands and what to clean up outside the resource group,
see [`webplat-architecture.md` §"Tearing down an
environment"](webplat-architecture.md#tearing-down-an-environment) — this
doc assumes that's already been run and focuses on getting back to a
verified, serving environment.

## What teardown destroys

Deleting `rg-itsolutions-webplat-dev-uks-001` (plus its AKS-managed node
resource group) is a permanent, irreversible delete of:

- **AKS cluster** — the private control plane, both node pools, and
  everything running on it (`demo-web`, the ArgoCD `podinfo` demo,
  cert-manager, AGIC)
- **ACR** — including the pushed image history
- **Application Gateway** + its **public IP** — the IP
  `dev-webplat.ict-cloud.solutions` currently resolves to; that DNS record
  goes stale the moment the RG is gone
- **VNet**, subnets, private endpoints, private DNS zone links

One exception:

- **Key Vault** — *soft-deleted, not gone*. Purge protection holds it for
  its retention window, so a future redeploy under the same vault name
  needs an explicit `az keyvault recover` before Bicep can create a vault
  with that name again.

Nothing in GitHub (code, workflows, repo history) is touched by an Azure
resource group delete.

## Rebuild sequence

This is the order that actually worked, not just the theoretical one —
several of these steps only became necessary because of specific failures
hit along the way (noted inline).

1. **Deploy the Bicep.** `az deployment group create` (or the `Webplat
   Deploy` GitHub Actions workflow) against `bicep/webplat.bicep` with
   `bicep/params/webplat-dev.bicepparam`. Creates the RG, VNet, AKS, ACR,
   Key Vault (or recovers the soft-deleted one — run `az keyvault recover
   --name <kv>` first if it still exists in soft-delete state), App
   Gateway, public IP.

2. **Azure Policy exemption**, if the subscription's policies block the AKS
   VMSS node resource group. Create a policy exemption (category
   `Mitigated`) scoped to the new node RG before the deployment can finish
   provisioning nodes.

3. **ARM-level RBAC.** The deploying service principal needs `Contributor`
   + `User Access Administrator` on the RG. These are resource-scoped, so
   tearing down the RG deletes this grant along with everything else — it
   has to be redone against the newly created RG, not just left over from
   before.

4. **OIDC federated credential.** Confirm the GitHub Actions App
   registration's federated credential still targets the correct branch
   ref (`repo:sufideen/az-ent-sec-dashboard:ref:refs/heads/main`). If the
   trigger branch ever changes, this breaks silently — `azure/login@v2`
   fails with no obvious link back to the credential's `subject` claim.

5. **Kubernetes-level Azure RBAC** — separate from #3. Grant `Azure
   Kubernetes Service RBAC Cluster Admin`, scoped to the new AKS resource,
   to both the deploying SP and any human admin identity. Without this,
   `kubectl` / `az aks command invoke` returns `Forbidden` even with valid
   ARM-level access — ARM RBAC and Kubernetes RBAC are two independent
   grants on two different planes.

6. **Update the Key Vault CSI managed identity reference** (prod overlay
   only — dev now uses cert-manager/Let's Encrypt instead, specifically to
   avoid this coupling). The Key Vault Secrets Provider CSI add-on gets a
   brand-new managed identity every cluster rebuild; a stale client ID left
   in the manifest silently breaks certificate delivery. Look up the
   current one with `az aks show` and patch the overlay if it's changed.

7. **Build & push the demo image** — `Webplat Build & Push Demo App`
   workflow, dev leg. Tags the image with the current commit SHA.

8. **Install cert-manager, apply the ClusterIssuers, deploy the app** —
   `Webplat App Deploy` workflow. The dev leg installs cert-manager
   idempotently, applies the Let's Encrypt `ClusterIssuer`s
   (`letsencrypt-staging`/`letsencrypt-prod`), then runs
   `kubectl apply -k k8s/overlays/dev`.

   **Known gap:** this workflow's `workflow_run` trigger only fires once
   the *entire* Build & Push run completes — including its prod leg, which
   sits behind a manual environment approval. In practice this means
   dispatching App Deploy manually (`workflow_dispatch`, `environment:
   dev`) right after Build & Push's dev leg finishes, rather than relying
   on the auto-chain. Splitting dev/prod into independent workflows would
   fix this properly; not done yet.

9. **Point DNS at the new public IP** (GoDaddy, manual — no API access).
   The Application Gateway gets a new public IP on every rebuild.

10. **Wait for Let's Encrypt.** First issuance goes through ACME HTTP-01
    against `letsencrypt-prod`. Confirm with `kubectl describe certificate`
    and a `curl` once the Application Gateway's *data-plane* config has
    propagated — this lags a few minutes behind the ARM `provisioningState`
    already showing "succeeded," so a `curl` failing right after the ARM
    deployment reports done is often just propagation, not a real fault.

11. **Redeploy the ArgoCD demo bootstrap**, if wanted. `k8s/argocd-demo/`
    is a separate GitOps bootstrap (`bootstrap/application.yaml`) — it's
    not part of the main app-deploy workflow and needs to be applied to the
    new cluster on its own.

## Rough shape

Steps 1–6 are infra/access plumbing — mostly one-time-per-rebuild pain from
resource-scoped RBAC and fresh managed identities, and the part most likely
to surface a new failure. Steps 7–10 are the actual app deploy and are
already automated by the two GitHub Actions workflows. On a clean run with
no new incidents, the whole sequence takes roughly 30–45 minutes.

## Verification checklist

- [ ] `az aks show -g <rg> -n <cluster> --query "{privateFQDN:privateFqdn, publicFQDN:fqdn}"` — only `privateFQDN` populated
- [ ] `az aks command invoke ... --command "kubectl get nodes -o wide"` — nodes `Ready`
- [ ] `kubectl -n demo-web get pods` — `Running`, passing readiness
- [ ] `kubectl describe certificate -n demo-web` — `READY: True` on the Let's Encrypt cert
- [ ] `curl -I https://dev-webplat.ict-cloud.solutions` — `200`, valid (non-self-signed) TLS chain
- [ ] `az acr credential show -n <acr>` fails/shows disabled — admin user confirmed off
- [ ] `kubectl -n podinfo-demo get pods` — `Running`, if the ArgoCD demo was redeployed
