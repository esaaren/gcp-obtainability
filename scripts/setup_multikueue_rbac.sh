#!/bin/bash

set -e

# Setup MultiKueue RBAC on workers and create secrets on manager
# Creates ServiceAccount, ClusterRoleBinding, creates token, and builds kubeconfig

MANAGER="manager"
WORKERS=$(kubectl config get-contexts -o name | grep "^worker-cluster-")

for WORKER in $WORKERS; do
  echo "Setting up MultiKueue RBAC for $WORKER..."
  
  # Create ServiceAccount on worker
  kubectl --context $WORKER apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: multikueue-sa
  namespace: kueue-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: multikueue-sa-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: multikueue-sa
  namespace: kueue-system
---
apiVersion: v1
kind: Secret
metadata:
  name: multikueue-sa-token
  namespace: kueue-system
  annotations:
    kubernetes.io/service-account.name: multikueue-sa
type: kubernetes.io/service-account-token
EOF

  echo "Waiting for secret to be populated..."
  sleep 5
  
  # Get token and ca.crt
  TOKEN=$(kubectl --context $WORKER -n kueue-system get secret multikueue-sa-token -o jsonpath='{.data.token}' | base64 -d)
  CA_CRT=$(kubectl --context $WORKER -n kueue-system get secret multikueue-sa-token -o jsonpath='{.data.ca\.crt}')
  SERVER=$(kubectl --context $WORKER config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  
  echo "Generating kubeconfig for $WORKER..."
  cat <<EOF > /tmp/${WORKER}-kubeconfig.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_CRT}
    server: ${SERVER}
  name: ${WORKER}
contexts:
- context:
    cluster: ${WORKER}
    user: multikueue-sa
  name: ${WORKER}
current-context: ${WORKER}
users:
- name: multikueue-sa
  user:
    token: ${TOKEN}
EOF

  echo "Creating secret on manager for $WORKER..."
  kubectl --context $MANAGER create secret generic ${WORKER}-kubeconfig \
    --namespace=kueue-system \
    --from-file=kubeconfig=/tmp/${WORKER}-kubeconfig.yaml \
    --dry-run=client -o yaml | kubectl --context $MANAGER apply -f -
    
done

echo "MultiKueue RBAC and Secrets setup complete!"
