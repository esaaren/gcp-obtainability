# GCP Infra Obtainability Demo

This project demonstrates how to build a highly resilient, globally distributed infrastructure on Google Cloud Platform (GCP) that intelligently hunts for scarce compute capacity (such as GPUs) across multiple regions.

In a world where obtaining specific hardware resources can be heavily constrained, this architecture ensures that your batch jobs can automatically fall back horizontally across multiple clusters globally until capacity is successfully obtained.

## Architecture

The environment relies on a hub-and-spoke multi-cluster architecture built with Google Kubernetes Engine (GKE) Autopilot and [Kueue/MultiKueue](https://kueue.sigs.k8s.io/).

- **Manager Cluster**: The central control plane. It hosts the Kueue and MultiKueue components. It intercepts incoming Jobs, checks global capacity logic, and dispatches workloads to available worker clusters.
- **Worker Clusters**: Geographically distributed GKE Autopilot clusters where the workloads actually execute. The number and locations of these clusters are dynamically configured via a Terraform list variable. By default, it provisions 4 clusters:
  - `worker-cluster-us-central1`
  - `worker-cluster-us-east1`
  - `worker-cluster-europe-west1`
  - `worker-cluster-us-west1`
  *(You can easily scale to 20+ clusters by just adding regions to the `worker_regions` list in `terraform/variables.tf`!)*

All clusters are registered to a central GCP Fleet, allowing seamless cross-cluster communication via Connect Gateway.

## Obtainability Mechanics (How it works)

When a Job is submitted to the manager cluster:

1. **Interception**: Kueue intercepts the Job and evaluates it against the global resource quotas (e.g., `cpu`, `memory`, `nvidia.com/gpu`).
2. **Admission**: The workload is queued and checked via an `AdmissionCheck` resource against a `MultiKueueCluster` pool (`worker1` through `worker4`).
3. **Dispatching & Execution**:
   - Kueue dispatches the Job to the first available cluster in the multi-cluster topology.
   - If the worker cluster faces a stockout or GCE resources are unavailable (e.g., `nvidia-rtx-pro-6000` is out of stock in a region), the local Autopilot control plane triggers a scale-up failure.
4. **Capacity Fallback ("Hunting")**:
   - **Intra-Cluster Hardware Fallback**: GKE Autopilot utilizes a custom `ComputeClass` to natively iterate through preferred hardware tiers. For example, if H100s are unavailable, it will immediately back off and attempt to provision RTX 6000s, and then L4s, without leaving the current cluster.
   - **Inter-Cluster Horizontal Fallback**: If a cluster cannot fulfill *any* of the defined hardware tiers within a configurable timeout (`waitForPodsReady.timeout`, currently set to `3m`), the manager cluster evicts the workload from that specific worker cluster.
   - The workload is re-queued and immediately dispatched to the next worker cluster in the topology.
   - This "hunting" loop continues indefinitely across the horizontal fallback tier until the workload lands on a worker cluster that successfully provisions the required capacity.

## Prerequisites

- GCP Project configured and authenticated via `gcloud`.
- `terraform` installed.
- `kubectl` installed.
- Pre-configured `kubeconfig` with contexts for `manager`, `worker1`, `worker2`, `worker3`, and `worker4`.

## Running the Demo

There are two pre-configured example jobs included in this repository:
- `manifests/jobs/cpu-job.yaml`: A simple standard CPU/Memory workload. Useful for verifying the pipeline logic quickly.
- `manifests/jobs/gpu-job.yaml`: A workload requesting scarce GPU capacity (`nvidia-rtx-pro-6000`). This is the primary driver for demonstrating the hunting fallback cycle.

### 1. Connect to the Manager Cluster

All jobs are submitted to the manager cluster.

```bash
kubectl config use-context manager
```

### 2. Submit a Workload

Choose either the CPU or GPU job to submit:

**Standard Capacity Test (CPU Job)**
Standard capacity refers to common, easily obtainable resources (like basic CPUs and Memory). Submitting this job verifies that the basic MultiKueue pipeline works, as it will likely be scheduled immediately on the first cluster it checks without needing to fall back.

```bash
kubectl create -f manifests/jobs/cpu-job.yaml
```

**Horizontal Capacity Hunting Test (GPU Job)**
Two-dimensional capacity hunting searches both across multiple hardware tiers and multiple clusters (regions) for scarce resources. Submitting this job requests highly constrained resources via a `ComputeClass` that defines a strict fallback order (e.g., Spot H100 -> Spot RTX 6000 -> Spot L4). Because the higher-tier GPUs are scarce, the job will natively attempt to provision them and fail over to the next hardware tier within Autopilot. If all hardware tiers are exhausted, it will hit the 3-minute timeout, triggering MultiKueue to evict the job and "hunt" horizontally across your other clusters until it finds one with availability.

```bash
kubectl create -f manifests/jobs/gpu-job.yaml
```

### 3. Observe the Fallback "Hunting" Process

You can watch Kueue actively hunting for available capacity in the logs and events.

**Watch the workloads overview:**
This shows which cluster the workload is currently reserved on. Note that all jobs and workloads are created in the `demo-jobs` namespace. If you are checking the UI, ensure you are filtering by the `demo-jobs` namespace.
```bash
kubectl get workloads -n demo-jobs -w
```

**See the event cycle and capacity re-evaluations:**
This shows the detailed admission check events as MultiKueue evaluates different clusters.
```bash
kubectl get events -n demo-jobs -w
```

For the GPU job, because RTX Pro 6000s are scarce, you will periodically see events iterating through clusters:
1. `The workload got reservation on "worker-cluster-us-central1"`
2. *(Wait 3 minutes for Autopilot scale-up timeout)*
3. `The workload got reservation on "worker-cluster-us-east1"`
4. *(Wait 3 minutes)*
5. `The workload got reservation on "worker-cluster-europe-west1"`

Once capacity is successfully obtained on a worker cluster, the Pods will reach the `Running` state and the job will execute to completion!

### 4. Clean Up Jobs

To clear the UI and stop workloads, simply delete the native Kubernetes `Job` objects from the manager cluster. Kueue will automatically cascade the deletion to clean up the associated `Workload` objects and stop any pods running on the worker clusters.

**Delete all jobs:**
```bash
kubectl --context manager delete jobs --all -n demo-jobs
```

**Delete a specific job:**
```bash
# List jobs to find the specific name
kubectl --context manager get jobs -n demo-jobs

# Delete by name
kubectl --context manager delete job <JOB_NAME> -n demo-jobs
```
