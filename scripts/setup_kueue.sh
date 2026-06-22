#!/bin/bash

set -e

PROJECT="erik-island-streams"
MANAGER_REGION="us-central1"
MANAGER_CLUSTER="manager-cluster"

echo "Fetching credentials for manager..."
gcloud container clusters get-credentials $MANAGER_CLUSTER --region $MANAGER_REGION --project $PROJECT

# Rename manager context
kubectl config delete-context manager 2>/dev/null || true
kubectl config rename-context gke_${PROJECT}_${MANAGER_REGION}_${MANAGER_CLUSTER} manager || true

echo "Fetching credentials for workers..."
# List all worker clusters and parse dynamically
WORKER_CLUSTERS=$(gcloud container clusters list --project $PROJECT --filter="name:worker-cluster-*" --format="value(name,location)")

while read -r name location; do
  if [ -n "$name" ]; then
    gcloud container clusters get-credentials $name --region $location --project $PROJECT
    # Rename context to the worker name
    kubectl config delete-context $name 2>/dev/null || true
    kubectl config rename-context gke_${PROJECT}_${location}_${name} $name || true
  fi
done <<< "$WORKER_CLUSTERS"

KUEUE_VERSION="v0.8.0"

  # Download manifests
  wget -q https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_VERSION/manifests.yaml -O /tmp/kueue-manifests.yaml
  
  # Patch broken kube-rbac-proxy image
  sed -i '' 's/gcr.io\/kubebuilder\/kube-rbac-proxy:v0.8.0/quay.io\/brancz\/kube-rbac-proxy:v0.16.0/g' /tmp/kueue-manifests.yaml
  
  # Enable MultiKueue feature gate via command line argument on the manager container
  awk '{print} /- --zap-log-level=2/ {print "        - --feature-gates=MultiKueue=true"}' /tmp/kueue-manifests.yaml > /tmp/kueue-manifests-patched.yaml
  mv /tmp/kueue-manifests-patched.yaml /tmp/kueue-manifests.yaml

  kubectl --context manager apply --server-side -f /tmp/kueue-manifests.yaml
  
  # Apply dummy CRDs to satisfy MultiKueue watch requirements
  kubectl --context manager apply -f manifests/kueue/dummy-crds.yaml

  echo "Waiting for Kueue to be ready on manager..."
  sleep 5
  kubectl --context manager wait deployment/kueue-controller-manager --for=condition=Available=true -n kueue-system --timeout=300s
  
WORKERS=$(kubectl config get-contexts -o name | grep "^worker-cluster-")

for WORKER in $WORKERS; do
  echo "Installing Kueue on $WORKER..."
  kubectl --context $WORKER apply --server-side -f /tmp/kueue-manifests.yaml
  
  # Apply dummy CRDs on worker to satisfy MultiKueue watch requirements
  kubectl --context $WORKER apply -f manifests/kueue/dummy-crds.yaml
done

echo "Waiting for Kueue to be ready..."
sleep 5
kubectl --context manager wait deployment/kueue-controller-manager --for=condition=Available=true -n kueue-system --timeout=300s
for ctx in $WORKERS; do
  kubectl --context $ctx wait deployment/kueue-controller-manager --for=condition=Available=true -n kueue-system --timeout=300s
done

echo "Kueue installation complete!"
