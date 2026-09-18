# Kubernetes on Azure — Project Showcase

A private, production-shaped AKS platform built, deployed, broken, diagnosed,
and fixed end-to-end on real Azure infrastructure — not a tutorial fork.
This document is written for a technical reviewer (client, employer,
interviewer) who wants to see what was actually built and verify it's real.

Live, currently-running evidence lives in
[`docs/screenshots/webplat/`](screenshots/webplat/) — every claim below
links back to a real screenshot or command output, not a diagram alone.

- **Repo**: this repository, `bicep/webplat.bicep` + `modules/{network,acr,aks,appgw-ingress}.bicep` + `k8s/`
- **Full technical runbook**: [`webplat-architecture.md`](webplat-architecture.md)
- **Live incident write-up**: [Incident: prod SecretProviderClass never patched](webplat-architecture.md#incident-prod-secretproviderclass-never-patched)

---

## 1. Executive summary

| | |
|---|---|
| **What** | A private AKS cluster hosting a containerized web app, fronted by a WAF-enabled Application Gateway, with a private container registry, GitHub Actions CI/CD, and zero long-lived credentials anywhere in the pipeline |
| **Environments** | Two fully independent, fully deployed environments — dev and prod — each with its own VNet, cluster, registry, and Key Vault |
| **Status** | Both environments verified end-to-end as of 2026-09-18: real pods, real TLS, real public IP, real HTTP 200 |
| **What makes this a showcase, not a tutorial** | A real defect shipped to prod, sat undetected for 24+ hours, and was root-caused and fixed live through five layered failures — see [§6](#6-a-real-incident-not-a-demo) |

---

## 2. Architecture

```
                                   Internet
                                       |
                         Application Gateway (WAF_v2)
                         public IP · TLS termination · OWASP ruleset
                         dedicated subnet, NSG-restricted
                                       |
                    AGIC (in-cluster controller) watches Ingress
                    objects and reconfigures the Gateway automatically
                                       |
                    +------------------------------------------+
                    |   AKS cluster — private API server        |
                    |   (no public control-plane IP, at all)    |
                    |                                           |
                    |   system node pool  (mode=System)          |
                    |     - CriticalAddonsOnly taint             |
                    |     - runs cluster add-ons only            |
                    |                                            |
                    |   user node pool  (mode=User, autoscaling) |
                    |     - namespace: demo-web                  |
                    |     - Deployment, 2-5 replicas via HPA     |
                    +------------------------------------------+
                        |                              |
                 AcrPull via                  Key Vault Secrets User /
                 kubelet managed identity      Certificate User via
                        |                       CSI add-on managed identity
                        v                              v
                Azure Container Registry         Azure Key Vault
                (private endpoint,               (RBAC-authorized,
                 no admin user,                   private endpoint,
                 RBAC-gated push/pull)             TLS cert storage)

   Diagnostics (AKS, ACR, Key Vault) --> shared Log Analytics Workspace
   (same workspace an existing Sentinel/SOC platform already queries)
```

**Two identical, independent environments**, same design, different blast radius:

| | Dev | Prod |
|---|---|---|
| VNet | `10.30.0.0/16` | `10.31.0.0/16` |
| Control-plane tier | Free | Standard (uptime SLA) |
| System pool | 2 nodes | 3 nodes |
| User pool (HPA) | 1–3, `minReplicas: 2` | 2–5, `minReplicas: 2` |
| Hostname | `dev-webplat.ict-cloud.solutions` (real DNS) | `www.itsolutions.example.com` (placeholder — infra is real, domain isn't registered yet) |

Full design rationale, every Bicep module, and the CI/CD pipeline shape are
in [`webplat-architecture.md`](webplat-architecture.md).

---

## 3. Kubernetes cluster breakdown

What's actually running, mapped to the manifests that define it
(`k8s/base/*.yaml`, patched per-environment by `k8s/overlays/{dev,prod}/`):

| Kubernetes object | What it does here | File |
|---|---|---|
| **Namespace** `demo-web` | Isolates the app's objects; labeled `app.kubernetes.io/part-of: webplat` | `namespace.yaml` |
| **Deployment** `demo-web` | Declarative desired state for the app — 2 replicas, rolling updates, non-root pod (`runAsUser: 101`), read-only root filesystem, all Linux capabilities dropped, seccomp `RuntimeDefault` | `deployment.yaml` |
| **Service** `demo-web` | Stable internal `ClusterIP`, routes port 80 → container port 8080 — this is what the Ingress and Application Gateway backend pool actually target | `service.yaml` |
| **Ingress** `demo-web` | Declares the HTTP routing + TLS intent (`ingressClassName: azure-application-gateway`); AGIC watches this object and reconfigures the real Application Gateway to match — no manual Gateway config | `ingress.yaml` |
| **HorizontalPodAutoscaler** `demo-web` | Watches CPU utilization (target 70%), scales the Deployment between `minReplicas: 2` and `maxReplicas` (5 in prod) with zero manual intervention | `hpa.yaml` |
| **NetworkPolicy** (×3) | Default-deny for the namespace, then explicit allow: ingress only from the Application Gateway's subnet CIDR on port 8080, egress only to DNS (UDP/TCP 53) — the app can't initiate any other outbound connection | `networkpolicy.yaml` |
| **SecretProviderClass** `webplat-tls` | Not a Kubernetes-native secret — a bridge object for the Secrets Store CSI driver, telling it which Key Vault, which certificate object, and which managed identity to use to sync the real TLS certificate into a Kubernetes `Secret` at pod-mount time. No certificate material is ever committed to Git | `secretproviderclass.yaml` |

**Node pools** (both environments split system vs. workload traffic — a
production pattern, not a toy setup):

- **System pool**: `mode: System`, tainted `CriticalAddonsOnly=true:NoSchedule` — cluster-critical pods only, application workloads are physically prevented from landing here
- **User pool**: `mode: User`, autoscaling, `AzureLinux` OS, `Standard_D2s_v4` — this is where `demo-web` actually runs

**Cluster-level configuration** (`modules/aks.bicep`):

- **Private API server** — `enablePrivateCluster: true`, AKS-managed private DNS zone, no public FQDN at all (verified: [`11-portal-aks-overview-{dev,prod}.txt`](screenshots/webplat/11-portal-aks-overview-dev.txt) shows only a `privatelink.uksouth.azmk8s.io` FQDN)
- **Entra ID + Azure RBAC for Kubernetes authorization** — cluster access is an Entra ID group membership, not a static kubeconfig or client certificate; `disableLocalAccounts: true`
- **Workload Identity + OIDC issuer** enabled at the cluster level
- **Defender for Containers** + **Azure Policy add-on**, both wired to the same governed Log Analytics Workspace an existing Sentinel/SOC platform already reports on
- **Two separate auto-upgrade maintenance windows** — one for Kubernetes control-plane version, one for node OS image — both weekly, both explicit `Microsoft.ContainerService/managedClusters/maintenanceConfigurations` resources

---

## 4. Step-by-step: how this gets from `git push` to a running pod

1. **Infra changes** (`bicep/webplat.bicep`, `modules/*.bicep`) go through
   `webplat-bicep-lint.yml` (compile check) and `webplat-what-if.yml`
   (shows the exact resource diff as a PR comment) before merge; merge to
   the default branch deploys dev automatically, prod behind an
   environment approval gate.
2. **App changes** (`app/`) trigger `webplat-build-push.yml`: builds the
   Docker image, tags it with the Git SHA, pushes to ACR via OIDC
   (`az acr login` with a federated token — no stored registry credential).
3. **Deployment** (`webplat-app-deploy.yml`) renders the environment's
   Kustomize overlay (`kubectl kustomize k8s/overlays/<env>`), substitutes
   the real image reference via `sed`, and applies it through
   `az aks command invoke` — because the cluster's API server has no public
   IP, this is the *only* path in from a GitHub-hosted runner, and it
   works with zero VPN, self-hosted runner, or Bastion host.
4. **AGIC** (running inside the cluster) notices the `Ingress` object,
   reconfigures the real Azure Application Gateway's listener/backend
   pool/health probe to match — this is the step that turns a `Running`
   pod into something the public internet can actually reach.
5. **The Secrets Store CSI driver** mounts the TLS secret from Key Vault
   into the pod at start-up, using the driver add-on's own managed
   identity — the application container never sees a Key Vault credential.

Every one of these steps was exercised for real, including the failure
modes — see [§6](#6-a-real-incident-not-a-demo).

---

## 5. Key terms, explained in the context of this project

| Term | In plain terms | Where it shows up here |
|---|---|---|
| **Pod** | The smallest deployable unit — one or more containers that share network/storage | Each `demo-web` pod runs one Nginx container |
| **Node** | A VM that runs pods — here, an Azure VM Scale Set instance | `aks-system-*-vmss` / `aks-user-*-vmss` |
| **Deployment** | Declares "I want N copies of this pod running, always" and reconciles reality toward that | `demo-web` Deployment, `replicas: 2` |
| **ReplicaSet** | The Deployment's actual mechanism — a set of identical pods it manages; a new one is created on every pod-template change | Surfaced directly during the incident — a manual apply created a second, broken ReplicaSet alongside the working one |
| **Service** | A stable network identity for a set of pods, even as individual pod IPs come and go | `demo-web` `ClusterIP` Service |
| **Ingress** | A declarative routing rule for HTTP(S) traffic into the cluster — requires a controller to actually act on it | Backed here by AGIC, which drives a real Azure Application Gateway |
| **Namespace** | A logical partition inside one cluster — scopes names, RBAC, and network policy | `demo-web` namespace |
| **HPA (Horizontal Pod Autoscaler)** | Automatically changes replica count based on a live metric | Scales `demo-web` on CPU utilization |
| **NetworkPolicy** | A firewall for pod-to-pod and pod-to-external traffic, enforced by the CNI | Default-deny + explicit allow from the Application Gateway only |
| **CSI driver (Container Storage Interface)** | A plugin standard for mounting external storage/secrets into pods | The Secrets Store CSI driver syncs Key Vault secrets, not a disk |
| **Managed Identity** | An Azure AD identity Azure manages the credential lifecycle for — no password/key to leak | Three separate ones here: kubelet (ACR pulls), CSI driver (Key Vault), AGIC (Application Gateway) |
| **RBAC (Role-Based Access Control)** | Authorization by role, not by identity — applies both to Azure resources and, separately, to the Kubernetes API itself | Azure RBAC gates cluster access; a *different* RBAC layer gates Key Vault |
| **Private cluster** | The Kubernetes API server has no public IP at all | Only reachable via `az aks command invoke` — see §4 |
| **Kustomize** | Patches a base set of YAML per environment without duplicating it | `k8s/base/` + `k8s/overlays/{dev,prod}/` |
| **OIDC federation (workload identity federation)** | A GitHub Actions workflow trades a short-lived token for Azure access — no stored client secret | Every CI/CD workflow in this repo authenticates this way |

---

## 6. A real incident, not a demo

Anyone can deploy a cluster that works the first time. Prod's demo app sat
in `ContainerCreating` for over 24 hours undetected — this is what actually
diagnosing and fixing it live looks like, five independent failures deep:

1. **`Invalid vault name: "REPLACE_WITH_KEY_VAULT_NAME"`** — prod's
   overlay was missing a patch dev had; the pod was trying to mount TLS
   secrets from a literal placeholder string.
2. **`ForbiddenByRbac`** — fixing #1 required creating a certificate in
   prod's Key Vault; the admin's own identity had never been granted
   `Key Vault Certificates Officer` on that specific vault.
3. **`ForbiddenByConnection`** — prod's Key Vault is private by design
   (no VPN/Bastion in this environment); even an authorized identity
   couldn't reach it over the network.
4. **`SecretNotFound` (404)** — once the network and RBAC were sorted,
   the TLS certificate simply didn't exist in prod's vault yet. Dev's did;
   prod's never had.
5. **`InvalidImageName`** — recovering from #1–4 involved a manual,
   locally-rendered `kubectl apply` that (correctly, by design) bypasses
   the CI pipeline's image-substitution step, which shipped a literal
   placeholder image reference and created a second, broken ReplicaSet
   mid-recovery.

Each failure only became visible once the one before it was fixed. The
full timeline, root causes, and exact commands used are documented in
[`webplat-architecture.md` → Incident: prod SecretProviderClass never patched](webplat-architecture.md#incident-prod-secretproviderclass-never-patched).

This is the difference between "I followed a tutorial" and "I can operate
this in production."

---

## 7. Use cases this pattern fits

- **Company marketing / product website** with a real SLA requirement,
  where "the site is down" is a business incident, not an inconvenience
- **Internal line-of-business web apps** that need private network
  isolation (no public API server, no public registry admin access) but
  still need a public-facing front door
- **A reference architecture for a client engagement** — every piece
  (private cluster, WAF, RBAC-gated registry, OIDC CI/CD, TLS via managed
  identity, autoscaling, default-deny network policy) is a checkbox a
  security-conscious client's procurement team will ask about
- **A multi-environment platform** (dev/prod today, easily extended to
  test/staging) where each environment is fully isolated at the network
  level, not just namespaced within one cluster
- **A teaching/reference example** for teams adopting AKS who want to see
  *why* each piece exists, not just a working `kubectl apply`

---

## 8. Evidence index

All captured directly from the live environments, redacted only where
browser chrome exposed unrelated content. See
[`docs/screenshots/webplat/README.md`](screenshots/webplat/README.md) for
the full index and the exact command behind each file.

| Evidence | File |
|---|---|
| Both environments' resource groups exist in Azure | [`00-resource-groups-dev-and-prod.png`](screenshots/webplat/00-resource-groups-dev-and-prod.png) |
| Node pool VMSS instances healthy (prod / dev) | [`01`](screenshots/webplat/01-prod-nodepool-vmss-status.png) / [`02`](screenshots/webplat/02-dev-nodepool-vmss-status.png) |
| Node resource group contents (managed identities, NSG, VMSS, private DNS) | [`03-dev-node-rg-contents.png`](screenshots/webplat/03-dev-node-rg-contents.png) |
| Private AKS API server DNS zone | [`04-prod-private-dns-zone.png`](screenshots/webplat/04-prod-private-dns-zone.png) |
| `kubectl get nodes` — real kubelet-level `Ready` status | [`06-prod-nodes-ready.png`](screenshots/webplat/06-prod-nodes-ready.png) |
| `demo-web` pods `Running` (dev / prod) | [`07-pods-running-dev.txt`](screenshots/webplat/07-pods-running-dev.txt) / [`-prod.txt`](screenshots/webplat/07-pods-running-prod.txt) |
| Application Gateway backend pool `Healthy` (dev / prod) | [`08-appgw-backend-healthy-dev.txt`](screenshots/webplat/08-appgw-backend-healthy-dev.txt) / [`-prod.txt`](screenshots/webplat/08-appgw-backend-healthy-prod.txt) |
| End-to-end `curl` — real `HTTP/1.1 200 OK` (dev / prod) | [`09-curl-https-200-dev.txt`](screenshots/webplat/09-curl-https-200-dev.txt) / [`-prod.txt`](screenshots/webplat/09-curl-https-200-prod.txt) |
| Cluster provisioning state, Kubernetes version, private FQDN | [`11-portal-aks-overview-dev.txt`](screenshots/webplat/11-portal-aks-overview-dev.txt) / [`-prod.txt`](screenshots/webplat/11-portal-aks-overview-prod.txt) |

---

## 9. Slide deck

A condensed, presentation-format version of this document — for a
portfolio review, an interview, or a client pitch — is at
[`webplat-kubernetes-showcase.pptx`](webplat-kubernetes-showcase.pptx).
