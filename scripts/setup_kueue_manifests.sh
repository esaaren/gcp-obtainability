#!/bin/bash

set -e

MANAGER="manager"
WORKERS=$(kubectl config get-contexts -o name | grep "^worker-cluster-")

echo "Applying common flavors and queues to manager..."
kubectl --context $MANAGER apply -f manifests/kueue-config/common-flavors.yaml
kubectl --context $MANAGER apply -f manifests/kueue-config/manager-queues.yaml

for WORKER in $WORKERS; do
  echo "Applying common flavors and queues to $WORKER..."
  kubectl --context $WORKER apply -f manifests/kueue-config/common-flavors.yaml
  kubectl --context $WORKER apply -f manifests/kueue-config/worker-queues.yaml
done

echo "Applying MultiKueue configuration to manager..."
YAML_FILE="/tmp/multikueue-config.yaml"
> $YAML_FILE

for WORKER in $WORKERS; do
  cat <<EOF >> $YAML_FILE
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueCluster
metadata:
  name: ${WORKER}
spec:
  kubeConfig:
    location: ${WORKER}-kubeconfig
    locationType: Secret
---
EOF
done

cat <<EOF >> $YAML_FILE
apiVersion: kueue.x-k8s.io/v1alpha1
kind: MultiKueueConfig
metadata:
  name: multikueue-config
spec:
  clusters:
EOF

for WORKER in $WORKERS; do
  echo "  - ${WORKER}" >> $YAML_FILE
done

cat <<EOF >> $YAML_FILE
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

kubectl --context $MANAGER apply -f $YAML_FILE

echo "MultiKueue components applied successfully!"
