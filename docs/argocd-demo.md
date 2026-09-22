# Argo CD demo (temporary, dev cluster only)

This is a short-lived demo of **pull-based GitOps** with Argo CD on the private
dev AKS cluster. It runs alongside the existing push-based pipeline
(`webplat-app-deploy.yml`) and doesn't touch `demo-web`. Remove it with one
workflow run afterwards.

| Piece | File |
|---|---|
| Install / uninstall workflow | `.github/workflows/argocd-demo.yml` |
| Argo CD `Application` (what to sync, from where) | `k8s/argocd-demo/bootstrap/application.yaml` |
| Argo CD UI ingress (App Gateway + Let's Encrypt) | `k8s/argocd-demo/bootstrap/ingress.yaml` |
| Sample app Argo CD manages (podinfo) | `k8s/argocd-demo/app/` |

## Push vs pull: the one-sentence version

- **Today (push):** GitHub Actions logs in to Azure and pushes manifests into
  the cluster (`az aks command invoke`). The pipeline needs cluster rights.
- **GitOps (pull):** an agent *inside* the cluster (Argo CD) watches Git and
  makes the cluster match it. The pipeline only needs to change Git.

```
Developer ──PR──▶ GitHub (k8s/argocd-demo/app)
                        ▲
                        │ outbound HTTPS only (polls every ~3 min)
               ┌────────┴─────────── private AKS ─────────────┐
               │ Argo CD ──compare desired vs live──▶ apply    │
               │                                  podinfo-demo │
               └───────────────────────────────────────────────┘
```

This suits a **private cluster**: nothing has to reach *in* to the API server.

## Setup (evening before, about 10 min)

1. **DNS:** add an A record `argocd-dev.ict-cloud.solutions` pointing at the
   App Gateway public IP (the same IP `dev-webplat` resolves to). Do this
   first so Let's Encrypt can issue the certificate.
2. **Merge** this branch to `main`. The Application tracks `main` by default.
3. **Actions → "Argo CD Demo (dev only)" → Run workflow → `install`.** It
   installs Argo CD v3.5.3, publishes the UI, creates the Application and
   waits for `Synced/Healthy`.
4. **Admin password.** It is deliberately *not* printed in the Actions logs,
   because this repo's logs are public. Open Portal → AKS → **Run command**
   and run:
   ```sh
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```
5. Open `https://argocd-dev.ict-cloud.solutions` and log in as `admin`.

**Fallback if the UI or DNS isn't ready:** Portal → Run command →
`kubectl -n argocd get applications` still shows `Synced / Healthy`.

## Live demo script (about 5 min)

1. **Show the app tree.** In the UI, click `podinfo-demo`. Walk through
   Application → Deployment → ReplicaSet → 2 Pods and Service, all green.
   Point out the **Synced to `main` @ \<commit\>** badge.
2. **Deploy by committing to Git.** In GitHub, edit
   `k8s/argocd-demo/app/deployment.yaml` and change `replicas: 2` to `3`,
   then commit to `main`. In Argo CD, press **Refresh** (or wait up to about
   3 min). It shows *OutOfSync*, auto-syncs, and a third pod appears.
   *"No pipeline touched the cluster. Git is the deployment."*
3. **Self-heal (drift correction).** Portal → Run command:
   `kubectl -n podinfo-demo scale deploy/podinfo --replicas=1`.
   Argo CD sets it back to 3 within seconds, because `selfHeal: true`.
   *"Manual hotfixes can't silently drift production."*
4. **Rollback = `git revert`.** Revert the replicas commit and watch it return
   to 2. Also show **History and Rollback** in the UI.
5. **Diff view.** Before a sync, open **App Diff** to show exactly what will
   change.

## Talking points

- **Why GitOps here:** the cluster is private (`enablePrivateCluster: true`,
  no public FQDN). The pull model needs only outbound access to GitHub, so the
  CI identity no longer needs cluster-admin or command-invoke rights. That's a
  smaller blast radius.
- **Audit and compliance:** every change is a reviewed PR, and Git history is
  the change log. Branch protection on `main` is the deployment approval gate.
- **Drift and self-heal:** `selfHeal` reverts out-of-band `kubectl` changes,
  and `prune` removes resources deleted from Git.
- **Argo CD vs Flux:** both are CNCF-graduated. Argo CD has the rich UI,
  multi-cluster ApplicationSets, SSO/RBAC and sync waves/hooks. Flux is
  lighter and has no UI. On AKS, Flux is the GA managed extension and Argo CD
  is a preview extension ("Enable Argo CD (Preview)" in the GitOps blade).
  This demo uses the upstream install for a pinned, well-known version.
- **Secrets:** never in Git. Use the Key Vault CSI driver (already used by
  prod here), External Secrets Operator or Sealed Secrets.
- **CI/CD split:** CI builds, scans and pushes the image, then opens a PR that
  bumps the image tag in the overlay. CD is Argo CD syncing that commit.
  Promotion is a PR from the dev overlay to the prod overlay. Argo CD Image
  Updater can automate the tag bump.
- **Production hardening I'd add:** SSO via Entra ID instead of the `admin`
  user (then disable it), Argo CD RBAC per `AppProject`, the UI behind a
  private ingress or App Gateway WAF with IP restrictions, HA manifests,
  notifications to Teams or Slack, and the whole bootstrap managed as an
  "app of apps".
- **Cost:** no licence fee. It uses about 0.5–1 vCPU and about 1 GB RAM for
  the controllers on existing nodes.

## Teardown (after the demo)

1. **Actions → "Argo CD Demo (dev only)" → Run workflow → `uninstall`.** This
   deletes the Application first (its finalizer removes podinfo), then
   Argo CD, its CRDs and both namespaces.
2. Delete the `argocd-dev` DNS record.
3. Optionally delete `k8s/argocd-demo/`, this doc and the workflow, or keep
   them as portfolio evidence. They do nothing unless run.
