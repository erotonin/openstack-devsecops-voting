# DevSecOps Voting App on Kubernetes running on OpenStack

This repository deploys the Voting App as a cloud-native workload on Kubernetes running on OpenStack private cloud infrastructure. The project is intentionally scoped to a small lab: one control-plane node, one worker node, one Harbor VM, one Kubernetes cluster, two application namespaces, and one shared observability stack.

## Architecture

```text
Developer
  -> GitHub/GitLab repository
  -> CI/CD pipeline
  -> Harbor private registry on a Nova VM
  -> GitOps desired state in Git
  -> ArgoCD
  -> Kubernetes cluster created on OpenStack
  -> Voting App
  -> Observability stack
```

OpenStack provides the infrastructure layer:

- Keystone: identity, projects, users, roles, and RBAC.
- Glance: base VM images for Harbor and Kubernetes nodes.
- Nova: VMs for Harbor and the Kubernetes cluster nodes.
- Neutron: tenant network, subnet, router, security groups, and floating IPs.
- Cinder: block volumes for persistent storage.
- Ceph: storage backend for Cinder and Glance.
- Magnum: preferred Kubernetes cluster lifecycle path.

Kubernetes provides the application layer:

- Deployments and Pods run `vote`, `result`, `worker`, Redis, and PostgreSQL.
- Services expose stable in-cluster endpoints.
- NGINX Ingress routes staging and production hostnames.
- PostgreSQL uses a PVC backed by the `cinder-csi` StorageClass.
- Redis remains ephemeral because it is only the demo queue/cache.

## Resource Profile

The target host is a constrained laptop with 32 GB RAM and roughly 400 GB SSD/NVMe storage. The default design is not HA and does not include a second site. The Kubernetes target is:

- 1 master node: 2 vCPU, 4 GB RAM.
- 1 worker node: 4 vCPU, 8 GB RAM.
- Calico CNI.
- Cinder CSI for persistent volumes when available.
- NGINX Ingress Controller.

## CI/CD

The branch model is:

```text
feature/* -> staging -> main
```

- `feature/*` branches run light validation only.
- `staging` represents the staging environment in namespace `voting-staging`.
- `main` represents production in namespace `voting-prod`.
- Production promotes the exact image digests verified in staging; it does not rebuild images.

The workflows are split by lifecycle stage:

- `feature-scan.yml`: light scan on `feature/**`.
- `pr-feature-to-staging.yml`: full safe PR gate before merge into `staging`.
- `staging-deploy-dast.yml`: build, sign, scan, push to Harbor, update `values-staging.yaml`, let ArgoCD deploy staging, then run DAST.
- `pr-staging-to-main.yml`: verify staging digests and signatures, then copy those digests to `values-prod.yaml`.
- `production-gitops.yml`: validate production desired state and wait for ArgoCD production sync.

The gates include:

- Gitleaks secret scan.
- Semgrep SAST.
- Trivy filesystem and image scans.
- Python compile check for `vote`.
- npm install/audit for `result`.
- .NET restore/build for `worker`.
- Checkov and tfsec for IaC and deployment manifests.
- Helm lint and render with `k8s/values-openstack.yaml`.
- Conftest policy scan.
- Docker build matrix for `vote`, `result`, and `worker`.
- Syft SBOM generation.
- Cosign keyless image signing.
- Push to Harbor.

Expected repository secrets:

- `HARBOR_REGISTRY`
- `HARBOR_USERNAME`
- `HARBOR_PASSWORD`

Harbor and Kubernetes jobs run on a self-hosted runner inside the OpenStack lab network with labels `self-hosted`, `linux`, and `openstack`. GitHub-hosted runners are used only for safe checks that do not need access to the private lab network.

DAST runs as a temporary Kubernetes Job in `voting-staging`. It is not part of the normal production Helm release.

## Harbor

Harbor runs on a separate Nova VM instead of inside Kubernetes. This keeps the registry available before app deployment, avoids a circular dependency, and is simpler for the lab.

Default Harbor VM shape:

- 2 vCPU.
- 3-4 GB RAM.
- 20 GB root volume.
- 50-100 GB Cinder volume mounted at `/data`.
- Docker and Docker Compose installed by cloud-init.

HTTP registry access is acceptable only for this lab. Configure each Kubernetes node runtime with an insecure registry entry if TLS is not enabled.

## Terraform

Terraform manages OpenStack resources inside an already-running cloud. It does not deploy Kolla-Ansible.

```bash
terraform -chdir=terraform/openstack init
terraform -chdir=terraform/openstack fmt
terraform -chdir=terraform/openstack validate
terraform -chdir=terraform/openstack plan
terraform -chdir=terraform/openstack apply
```

Main resources:

- Neutron tenant network, subnet, router, router interface, and external gateway.
- Security groups for SSH, Harbor HTTP/HTTPS, Kubernetes API access, NodePort/Ingress lab access, and ICMP troubleshooting.
- OpenStack keypair.
- Harbor Nova VM.
- Cinder volume for Harbor `/data`.
- Floating IP for Harbor.

Do not commit `clouds.yaml`, OpenStack RC files, kubeconfigs, private keys, Terraform state, or password files.

## Kubernetes Cluster

Use Magnum first. It is OpenStack-native, uses the Magnum API and Heat, and integrates Nova, Neutron, and Cinder for cluster lifecycle. It can be harder to debug when the image, template, or service configuration is wrong.

Kubespray is only the fallback path. It installs Kubernetes on existing VMs with Ansible and gives more direct control over the Kubernetes version, but it requires manual OpenStack cloud provider and Cinder CSI integration.

The exact Magnum CLI flow is in [DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md).

## GitOps Deployment

Create the namespaces and Harbor pull secrets:

```bash
kubectl create namespace voting-staging
kubectl create namespace voting-prod

kubectl -n voting-staging create secret docker-registry harbor-pull \
  --docker-server="$HARBOR_REGISTRY" \
  --docker-username="$HARBOR_USERNAME" \
  --docker-password="$HARBOR_PASSWORD"

kubectl -n voting-prod create secret docker-registry harbor-pull \
  --docker-server="$HARBOR_REGISTRY" \
  --docker-username="$HARBOR_USERNAME" \
  --docker-password="$HARBOR_PASSWORD"
```

Render locally:

```bash
helm lint k8s
helm template voting-staging k8s -f k8s/values-openstack.yaml -f k8s/values-staging.yaml
helm template voting-prod k8s -f k8s/values-openstack.yaml -f k8s/values-prod.yaml
```

ArgoCD application manifests:

```bash
kubectl apply -f k8s/argocd-app-staging.yaml
kubectl apply -f k8s/argocd-app-prod.yaml
```

## Storage Path

PostgreSQL persistence path:

```text
Pod -> PVC -> StorageClass cinder-csi -> Cinder Volume -> Ceph backend
```

Redis uses `emptyDir` because it is a demo queue/cache and can be recreated.

## Observability

The observability layer is split by signal:

- Metrics: Prometheus and Grafana.
- Logs: Loki and Promtail.
- Traces: OpenTelemetry Collector and Jaeger.

The vote service supports OpenTelemetry through environment variables:

- `OTEL_SERVICE_NAME=vote`
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`

Operational flow: a Prometheus alert points to latency or errors, traces show the slow service path, and logs provide the request-level error context when available.

## Policy

Generic Kubernetes security policies are kept:

- No mutable `latest` image tags.
- No privileged containers.
- Resource requests and limits are required.
- Pods must run as non-root where possible.
- Containers must set `allowPrivilegeEscalation=false`.
