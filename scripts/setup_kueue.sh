#!/bin/bash

set -e

PROJECT="YOUR_PROJECT_ID"
MANAGER_REGION="us-central1"
MANAGER_CLUSTER="manager-cluster"

echo "Fetching credentials for manager..."
gcloud container clusters get-credentials $MANAGER_CLUSTER --region $MANAGER_REGION --project $PROJECT

# Rename manager context
kubectl config rename-context gke_${PROJECT}_${MANAGER_REGION}_${MANAGER_CLUSTER} manager || true

echo "Fetching credentials for workers..."
# List all worker clusters and parse dynamically
WORKER_CLUSTERS=$(gcloud container clusters list --project $PROJECT --filter="name:worker-cluster-*" --format="value(name,location)")

while read -r name location; do
  if [ -n "$name" ]; then
    gcloud container clusters get-credentials $name --region $location --project $PROJECT
    # Rename context to the worker name
    kubectl config rename-context gke_${PROJECT}_${location}_${name} $name || true
  fi
done <<< "$WORKER_CLUSTERS"

KUEUE_VERSION="v0.8.0"

echo "Installing Kueue on manager..."
kubectl --context manager apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_VERSION/manifests.yaml

WORKERS=$(kubectl config get-contexts -o name | grep "^worker-cluster-")

for ctx in $WORKERS; do
  echo "Installing Kueue on $ctx..."
  kubectl --context $ctx apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_VERSION/manifests.yaml
done

echo "Waiting for Kueue to be ready..."
kubectl --context manager wait --for=condition=ready pod -n kueue-system -l control-plane=controller-manager --timeout=300s
for ctx in $WORKERS; do
  kubectl --context $ctx wait --for=condition=ready pod -n kueue-system -l control-plane=controller-manager --timeout=300s
done

echo "Kueue installation complete!"
