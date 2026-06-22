#!/bin/bash

set -e

MANAGER="manager"
WORKERS=$(kubectl config get-contexts -o name | grep "^worker-cluster-")

echo "Installing Kueue Configs on Manager cluster using Helm..."
# Build the set arguments for workers
SET_ARGS=""
i=0
for WORKER in $WORKERS; do
  SET_ARGS="${SET_ARGS} --set manager.workers[$i]=${WORKER}"
  i=$((i+1))
done

helm upgrade --install kueue-config helm/kueue-config \
  --kube-context $MANAGER \
  --set clusterType=manager \
  $SET_ARGS

for WORKER in $WORKERS; do
  echo "Installing Kueue Configs on $WORKER using Helm..."
  helm upgrade --install kueue-config helm/kueue-config \
    --kube-context $WORKER \
    --set clusterType=worker
done

echo "Kueue configurations applied via Helm successfully!"
