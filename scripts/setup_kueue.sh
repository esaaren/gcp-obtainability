#!/bin/bash

set -e

PROJECT="YOUR_PROJECT_ID"
MANAGER="manager-cluster"
WORKER1="worker-cluster-us"
WORKER2="worker-cluster-eu"

REGION_MANAGER="us-central1"
REGION_WORKER1="us-east1"
REGION_WORKER2="europe-west1"

echo "Fetching credentials..."
gcloud container clusters get-credentials $MANAGER --region $REGION_MANAGER --project $PROJECT
gcloud container clusters get-credentials $WORKER1 --region $REGION_WORKER1 --project $PROJECT
gcloud container clusters get-credentials $WORKER2 --region $REGION_WORKER2 --project $PROJECT

# Rename contexts for easier access
kubectl config rename-context gke_${PROJECT}_${REGION_MANAGER}_${MANAGER} manager || true
kubectl config rename-context gke_${PROJECT}_${REGION_WORKER1}_${WORKER1} worker1 || true
kubectl config rename-context gke_${PROJECT}_${REGION_WORKER2}_${WORKER2} worker2 || true

KUEUE_VERSION="v0.8.0"

for ctx in manager worker1 worker2; do
  echo "Installing Kueue on $ctx..."
  kubectl --context $ctx apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_VERSION/manifests.yaml
done

echo "Waiting for Kueue to be ready..."
for ctx in manager worker1 worker2; do
  kubectl --context $ctx wait --for=condition=ready pod -n kueue-system -l control-plane=controller-manager --timeout=300s
done

echo "Kueue installation complete!"
