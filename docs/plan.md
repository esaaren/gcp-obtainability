# GCP Infra Obtainability Demo Plan

## Architecture
1. **GCP Project**: `YOUR_PROJECT_ID`
2. **Clusters**:
   - `manager-cluster` (us-central1)
   - `worker-cluster-us` (us-east1)
   - `worker-cluster-eu` (europe-west1)
   All clusters will be GKE Autopilot clusters to easily utilize Custom Compute Classes.
3. **MultiKueue**:
   - Install Kueue on all clusters.
   - Configure `manager-cluster` as the MultiKueue manager.
   - Add `worker-cluster-us` and `worker-cluster-eu` as MultiKueue workers.
4. **Hardware Fallback (Custom Compute Classes)**:
   - Configure Kueue `ResourceFlavors` mapping to different GKE Compute Classes (e.g., standard, spot, specific GPU tiers).
   - Configure `ClusterQueues` to use these flavors in a fallback sequence.
5. **Job Submission**:
   - A batch job is submitted to `manager-cluster`.
   - Kueue evaluates capacity. If local capacity (manager) or primary compute class isn't available, MultiKueue dispatches it to a worker cluster that has capacity.

## Steps
- [ ] 1. Define Terraform configuration for VPC, GKE Autopilot clusters, and Fleet registration.
- [ ] 2. Apply Terraform to create infrastructure.
- [ ] 3. Get cluster credentials.
- [ ] 4. Install Kueue on all 3 clusters.
- [ ] 5. Configure MultiKueue (RBAC, kubeconfig secrets on manager).
- [ ] 6. Create Kueue CRDs (ResourceFlavors, ClusterQueues, LocalQueues, MultiKueueClusters, MultiKueueConfigs).
- [ ] 7. Test with a sample Job.
