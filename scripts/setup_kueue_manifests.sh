#!/bin/bash

set -e

MANAGER="manager"
WORKERS=("worker1" "worker2" "worker3" "worker4")

echo "Applying common flavors and queues to manager..."
kubectl --context $MANAGER apply -f manifests/kueue-config/common-flavors.yaml
kubectl --context $MANAGER apply -f manifests/kueue-config/manager-queues.yaml

for WORKER in "${WORKERS[@]}"; do
  echo "Applying common flavors and queues to $WORKER..."
  kubectl --context $WORKER apply -f manifests/kueue-config/common-flavors.yaml
  kubectl --context $WORKER apply -f manifests/kueue-config/worker-queues.yaml
done

echo "Applying MultiKueue configuration to manager..."
kubectl --context manager apply -f - <<EOF
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueCluster
metadata:
  name: worker1
spec:
  kubeConfig:
    location: worker1-kubeconfig
    locationType: Secret
---
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueCluster
metadata:
  name: worker2
spec:
  kubeConfig:
    location: worker2-kubeconfig
    locationType: Secret
---
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueCluster
metadata:
  name: worker3
spec:
  kubeConfig:
    location: worker3-kubeconfig
    locationType: Secret
---
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueCluster
metadata:
  name: worker4
spec:
  kubeConfig:
    location: worker4-kubeconfig
    locationType: Secret
---
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueConfig
metadata:
  name: multikueue-config
spec:
  clusters:
  - worker1
  - worker2
  - worker3
  - worker4
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: AdmissionCheck
metadata:
  name: multikueue-check
spec:
  controllerName: kueue.x-k8s.io/multikueue
  retryDelayMinutes: 15
  parameters:
    apiGroup: kueue.x-k8s.io
    kind: MultiKueueConfig
    name: multikueue-config
EOF

echo "MultiKueue components applied successfully!"
