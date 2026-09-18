#!/usr/bin/env bash
# Captures the remaining webplat evidence items listed as "Still outstanding"
# in docs/screenshots/webplat/README.md, straight from the live environment.
#
# Usage:
#   ./scripts/capture-webplat-evidence.sh dev
#   ./scripts/capture-webplat-evidence.sh prod
#
# Requires: az CLI logged in with access to the webplat subscription, and
# membership in the AKS-WebPlat-Admins Entra ID group (for the
# `az aks command invoke` steps).
#
# Each check prints to the terminal (screenshot it, or just commit the raw
# .txt files this script also writes to docs/screenshots/webplat/ - plain
# terminal text has no browser chrome to redact, unlike a screenshot).

set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Usage: $0 [dev|prod]" >&2
  exit 1
fi

RG="rg-itsolutions-webplat-${ENV}-uks-001"
CLUSTER="aks-itsolutions-webplat-${ENV}-uks-001"
APPGW="agw-itsolutions-webplat-${ENV}-uks-001"
LAW_NAME="law-ictlabs-central-dev-uksouth"
LAW_RG="rg-ictlabs-connectivity-dev-uksouth"

if [[ "$ENV" == "dev" ]]; then
  HOSTNAME="dev-webplat.ict-cloud.solutions"
else
  # NOTE: k8s/overlays/prod/kustomization.yaml still patches the Ingress to
  # the placeholder "www.itsolutions.example.com" - it was never repointed
  # at a real domain. --resolve below forces this hostname to the App
  # Gateway's real public IP so the SNI/Host-based listener still matches,
  # without needing a real DNS record.
  HOSTNAME="www.itsolutions.example.com"
fi

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/screenshots/webplat"
mkdir -p "$OUT_DIR"

echo "=============================================="
echo " Webplat evidence capture - environment: $ENV"
echo " Resource group: $RG"
echo "=============================================="
echo

echo "== [$ENV] 07 - demo-web pods =="
az aks command invoke -g "$RG" -n "$CLUSTER" \
  --command "kubectl -n demo-web get pods -o wide" \
  -o json | jq -r '.logs' | tee "$OUT_DIR/07-pods-running-$ENV.txt"
echo

echo "== [$ENV] 08 - Application Gateway backend health =="
# -o table can't flatten the nested backendAddressPools[].backendHttpSettingsCollection[].servers[]
# structure (renders blank), so --query flattens it to one row per backend server first.
az network application-gateway show-backend-health \
  -g "$RG" -n "$APPGW" \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address, health:health}" \
  -o table | tee "$OUT_DIR/08-appgw-backend-healthy-$ENV.txt"
echo

echo "== [$ENV] 09 - curl through public ingress ($HOSTNAME) =="
PUBLIC_IP=$(az network public-ip list -g "$RG" --query "[0].ipAddress" -o tsv)
{
  echo "App Gateway public IP: $PUBLIC_IP"
  echo
  echo "\$ curl -kI --resolve $HOSTNAME:443:$PUBLIC_IP https://$HOSTNAME/"
  curl -kI --resolve "$HOSTNAME:443:$PUBLIC_IP" "https://$HOSTNAME/" || true
  echo
  echo "\$ curl -k --resolve $HOSTNAME:443:$PUBLIC_IP https://$HOSTNAME/healthz"
  curl -k --resolve "$HOSTNAME:443:$PUBLIC_IP" "https://$HOSTNAME/healthz" || true
  echo
} | tee "$OUT_DIR/09-curl-https-200-$ENV.txt"
echo

echo "== [$ENV] 10 - ACR pull events (last 7d) =="
# Pods pull on creation, not continuously - a 24h window misses the pull
# entirely once a pod's been running longer than that (confirmed live: both
# dev and prod pods were >24h old and returned zero rows at 24h). 7 days
# comfortably covers the original pull without going back further than needed.
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  -g "$LAW_RG" -n "$LAW_NAME" --query customerId -o tsv)
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "ContainerRegistryLoginEvents | where Identity has \"$CLUSTER\" | where TimeGenerated > ago(7d) | project TimeGenerated, LoginServer, Identity, OperationName, ResultType | order by TimeGenerated desc | take 20" \
  -o table | tee "$OUT_DIR/10-acr-pull-event-$ENV.txt"
echo

echo "== [$ENV] 11 - AKS cluster overview =="
az aks show -g "$RG" -n "$CLUSTER" \
  --query "{name:name, provisioningState:provisioningState, kubernetesVersion:currentKubernetesVersion, privateFqdn:privateFqdn, publicFqdn:fqdn, powerState:powerState.code}" \
  -o table | tee "$OUT_DIR/11-portal-aks-overview-$ENV.txt"
echo

echo "== [$ENV] 12 - Defender for Cloud inventory (best-effort via Resource Graph) =="
CLUSTER_ID=$(az aks show -g "$RG" -n "$CLUSTER" --query id -o tsv)
if ! az extension show --name resource-graph >/dev/null 2>&1; then
  az extension add --name resource-graph --only-show-errors
fi
az graph query -q "Resources | where id =~ '$CLUSTER_ID' | project name, type, resourceGroup, location, tags" \
  -o table | tee "$OUT_DIR/12-defender-inventory-$ENV.txt"
echo "NOTE: this confirms the resource exists and is tagged; for the actual"
echo "Defender for Cloud recommendations/compliance view, check the portal:"
echo "Defender for Cloud -> Inventory -> filter by resource group $RG"
echo

echo "Done. Raw text output written to: $OUT_DIR/*-$ENV.txt"
echo "Review before committing (should be clean - no browser chrome - but"
echo "double check for anything unexpectedly sensitive)."
