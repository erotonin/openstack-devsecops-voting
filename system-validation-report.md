# System Validation Report

## Scope

Controlled validation of the OpenStack DevSecOps Voting App.

## Tested Features & Results

### 1. Ingress & Service Reachability
- Staging ingress endpoint is not exposed publicly to the builder host (expected security restriction).
- Tested internally inside the cluster namespace `voting-staging` using a curl helper pod:
  - `vote` service: **`HTTP 200`**
  - `result` service: **`HTTP 200`**

### 2. Harbor Image Pull Verification
- Created a temporary check pod referencing the exact staging vote digest `harbor.openstack.local/voting/vote@sha256:2ea1e97111c82679a29837e09a692f988c81e5d8e51f2923bffb353b48740259`.
- Status: **`Success`** (Pod pulled successfully, logged `harbor pull ok`, and exited cleanly).

### 3. Pod Self-Healing (Stateless Services)
- **`vote`**: Deleted `vote-6bfc9d8984-7b7wl` -> self-healed to `vote-6bfc9d8984-c4pvq` (Running).
- **`result`**: Deleted `result-76489bf6df-fjp7p` -> self-healed to `result-76489bf6df-kdkrb` (Running).
- **`worker`**: Deleted `worker-7fc69f9d9f-hl55p` -> self-healed to `worker-7fc69f9d9f-b2427` (Running).

### 4. Redis Ephemeral Recovery
- Ephemeral redis pod `redis-747c6cd967-9flz7` deleted -> self-healed to `redis-747c6cd967-s5pm9` (Running).

### 5. PostgreSQL PVC Durability
- Created durability table and inserted probe row: `probe-1783196752`.
- Deleted database pod `db-74c854dc77-8m6bl`.
- Deployment controller successfully attached and mounted Cinder CSI PV `pvc-81bec80f-691f-48fa-a25e-61fc86af0538`.
- Durability check: **`Success`** (Probe ID successfully read after DB container restart, count = 1).

### 6. GitOps Drift Correction
- Scaled `vote` deployment manually to 2 replicas.
- Triggered ArgoCD hard refresh.
- ArgoCD self-heal automatically scaled the deployment back to **`1`** replica in Attempt 1.
- Manual scale test of `result` to 2 replicas was similarly auto-reconciliation scaled back to 1.

### 7. Observability Readiness
- **Status: Not Installed** (Observability namespace, Prometheus CRDs, and ServiceMonitors are not installed, which is expected for this resource-aware core DevOps baseline lab).

---

## Resilience & Architecture Assessment

### Not tested destructively
- Control-plane failure
- Worker node drain/failure
- OpenStack VM shutdown
- PVC deletion
- Production pod deletion

### Failover Impact Analysis
- **Worker Failure**: With only 1 worker node, if the worker node fails, application pods cannot reschedule. The application will be offline until the worker recovers or a new worker is added.
- **Control-plane Failure**: With only 1 control-plane node, if the master node fails, cluster management (kube-apiserver, etcd, schedule control loops, GitOps syncs) becomes completely unavailable. Running workloads on the worker node will continue to execute but cannot be updated, scaled, or rescheduled.
- **HA Spec Alignment**: The current 1 master + 1 worker design is correct for the non-HA, resource-constrained spec. High Availability is not required, and pod-level self-healing on healthy nodes behaves perfectly.

---

## Final Health Check Summary

### Staging Namespace
- All pods (`db`, `redis`, `result`, `vote`, `worker`) are **`1/1 Running`**.
- PVC `postgres-data` is **`Bound`**.

### Production Namespace
- All pods (`db`, `redis`, `result`, `vote`, `worker`) are **`1/1 Running`**.
- PVC `postgres-data` is **`Bound`**.

### ArgoCD Applications
- `voting-staging` and `voting-prod` are **`Synced`**.
