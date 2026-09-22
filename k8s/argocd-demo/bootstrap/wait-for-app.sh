#!/bin/sh
# Polls the Application until Argo CD reports Synced/Healthy (up to ~5 min).
# Used instead of `kubectl wait --for=jsonpath`, which can error out before
# Argo CD has written .status for the first time.
kubectl apply -f application.yaml || exit 1
state=""
for i in $(seq 1 60); do
  state=$(kubectl -n argocd get application podinfo-demo \
    -o jsonpath='{.status.sync.status}/{.status.health.status}')
  echo "[$i] podinfo-demo: ${state:-pending}"
  [ "$state" = "Synced/Healthy" ] && break
  sleep 5
done
kubectl -n argocd get applications
kubectl -n podinfo-demo get deploy,pods
kubectl -n argocd get ingress,certificate
[ "$state" = "Synced/Healthy" ]
